--!nonstrict
-- How do players move? The hunter uses this to guess where a player goes next, both in the
-- particle filter's predict step and inside the POMCP planner's simulations.
--
-- Every 0.5 s tick, a player's step falls into one CATEGORY relative to the hunter:
--   stay     did not change node
--   toward   room → room, closer to the hunter's room
--   away     room → room, farther from it
--   side     room → room, same distance
--   hide     room → closet
--   unhide   closet → room
-- and depends on a CONTEXT: where the player is (room / closet) × how many rooms away the
-- hunter is (0, 1, 2, 3+). That is 8 contexts × 6 categories: small enough to learn from a few
-- nights of real play, and it does not depend on the house layout.
--
-- Two kinds of model:
--   uniform  the hand-made guess the hunter started with: in a room, move to a random
--            neighbour with probability 0.35 per tick; in a closet, leave with 0.08.
--   learned  per context, a weight per category = how often players took that step when it was
--            possible ("rate when available"), smoothed toward the uniform prior.
-- Learned models are fitted from recorded trajectories (simulator bots, or real players via
-- telemetry and the backend) and stored as plain tables, so they can travel as JSON.

local OpponentModel = {}

OpponentModel.CATEGORIES = { "stay", "toward", "away", "side", "hide", "unhide" }
OpponentModel.BANDS = 4 -- hunter distance 0, 1, 2, 3+ rooms
OpponentModel.PRIOR_STRENGTH = 20 -- pseudo-observations of the uniform prior per context

local MOVE_PROB_ROOM = 0.35
local MOVE_PROB_HIDE = 0.08

local function band(d: number): number
	return math.min(d, OpponentModel.BANDS - 1)
end

function OpponentModel.contextKey(kind: string, hunterDist: number): string
	return kind .. band(hunterDist)
end

-- Which category is the step u → v when the hunter is in room `hunterRoom`?
function OpponentModel.category(graph, u: number, v: number, hunterRoom: number): string?
	if u == v then
		return "stay"
	end
	local nu, nv = graph.nodes[u], graph.nodes[v]
	if nu.kind == "room" and nv.kind == "hide" then
		return "hide"
	elseif nu.kind == "hide" and nv.kind == "room" then
		return "unhide"
	elseif nu.kind == "room" and nv.kind == "room" then
		local du, dv = graph.dist[hunterRoom][nu.room], graph.dist[hunterRoom][nv.room]
		return if dv < du then "toward" elseif dv > du then "away" else "side"
	end
	return nil
end

-- The prior weights: what the uniform model does, written as category weights.
local function priorWeights(kind: string): { [string]: number }
	if kind == "hide" then
		return { stay = 1 - MOVE_PROB_HIDE, unhide = MOVE_PROB_HIDE }
	end
	-- A room has ~2.5 move options on average; spread the move probability over them.
	local each = MOVE_PROB_ROOM / 2.5
	return { stay = 1 - MOVE_PROB_ROOM, toward = each, away = each, side = each, hide = each }
end

function OpponentModel.uniform()
	return { kind = "uniform", version = "uniform" }
end

-- trajectories: list of { { node = id, hunterRoom = room }, ... } (one entry per 0.5 s tick,
-- consecutive ticks of ONE player). node 0 / nil = not in play (downed, left): such steps are skipped.
function OpponentModel.fit(graph, trajectories, version: string?)
	local chosen, avail = {}, {}
	local samples = 0
	for _, kind in { "room", "hide" } do
		for b = 0, OpponentModel.BANDS - 1 do
			chosen[kind .. b], avail[kind .. b] = {}, {}
			for _, c in OpponentModel.CATEGORIES do
				chosen[kind .. b][c], avail[kind .. b][c] = 0, 0
			end
		end
	end

	for _, traj in trajectories do
		for t = 1, #traj - 1 do
			local a, b = traj[t], traj[t + 1]
			local u, v = a.node, b.node
			if u and v and u > 0 and v > 0 and a.hunterRoom and a.hunterRoom > 0 then
				local c = OpponentModel.category(graph, u, v, a.hunterRoom)
				if c then
					local nu = graph.nodes[u]
					local key = OpponentModel.contextKey(nu.kind, graph.dist[a.hunterRoom][nu.room])
					chosen[key][c] += 1
					avail[key].stay += 1
					local seen = { stay = true }
					for _, w in graph.neighbors[u] do
						local cw = OpponentModel.category(graph, u, w, a.hunterRoom)
						if cw and not seen[cw] then
							seen[cw] = true
							avail[key][cw] += 1
						end
					end
					samples += 1
				end
			end
		end
	end

	local weights = {}
	local alpha = OpponentModel.PRIOR_STRENGTH
	for key, counts in chosen do
		local prior = priorWeights(if key:sub(1, 4) == "hide" then "hide" else "room")
		weights[key] = {}
		for _, c in OpponentModel.CATEGORIES do
			local p = prior[c] or 0
			-- Rate when available, pulled toward the prior when there is little data.
			weights[key][c] = (counts[c] + alpha * p) / (avail[key][c] + alpha)
		end
	end
	return { kind = "learned", version = version or "local", samples = samples, weights = weights }
end

-- Build a model from a decoded JSON table (from the backend). Returns nil if it looks wrong.
function OpponentModel.fromParams(params)
	if type(params) ~= "table" or params.kind ~= "learned" or type(params.weights) ~= "table" then
		return nil
	end
	for _, kind in { "room", "hide" } do
		for b = 0, OpponentModel.BANDS - 1 do
			local w = params.weights[kind .. b]
			if type(w) ~= "table" then
				return nil
			end
			for _, c in OpponentModel.CATEGORIES do
				if type(w[c]) ~= "number" or w[c] < 0 or w[c] ~= w[c] then
					return nil
				end
			end
		end
	end
	return { kind = "learned", version = tostring(params.version or "remote"), samples = params.samples or 0, weights = params.weights }
end

-- For node u with the hunter in room h: the possible next nodes and their probabilities,
-- cached per (graph, h, u) because the particle filter asks this thousands of times a tick.
local function choices(model, graph, u: number, h: number)
	local cache = model._cache
	if not cache or cache.graph ~= graph then
		cache = { graph = graph }
		model._cache = cache
	end
	local row = cache[h]
	if not row then
		row = {}
		cache[h] = row
	end
	local entry = row[u]
	if entry then
		return entry
	end

	local nodes, probs = { u }, {}
	if model.kind == "uniform" then
		local options = graph.neighbors[u]
		local move = if graph.nodes[u].kind == "hide" then MOVE_PROB_HIDE else MOVE_PROB_ROOM
		probs[1] = 1 - move
		for _, v in options do
			table.insert(nodes, v)
			table.insert(probs, move / #options)
		end
	else
		local nu = graph.nodes[u]
		local w = model.weights[OpponentModel.contextKey(nu.kind, graph.dist[h][nu.room])]
		local groups = {}
		for _, v in graph.neighbors[u] do
			local c = OpponentModel.category(graph, u, v, h)
			if c then
				groups[c] = groups[c] or {}
				table.insert(groups[c], v)
			end
		end
		local total = w.stay
		for c, list in groups do
			total += w[c]
		end
		probs[1] = w.stay / total
		for c, list in groups do
			for _, v in list do
				table.insert(nodes, v)
				table.insert(probs, w[c] / total / #list)
			end
		end
	end
	-- Cumulative, for one-draw sampling.
	local acc = 0
	local cum = table.create(#probs, 0)
	for i, p in probs do
		acc += p
		cum[i] = acc
	end
	entry = { nodes = nodes, probs = probs, cum = cum }
	row[u] = entry
	return entry
end

-- Sample where a player at node u will be one tick later, with the hunter in room h.
function OpponentModel.step(model, graph, rng: Random, u: number, h: number): number
	local e = choices(model, graph, u, h)
	local r = rng:NextNumber() * e.cum[#e.cum]
	for i, c in e.cum do
		if r <= c then
			return e.nodes[i]
		end
	end
	return e.nodes[#e.nodes]
end

-- Probability of the step u → v (for scoring a model on held-out trajectories).
function OpponentModel.prob(model, graph, u: number, v: number, h: number): number
	local e = choices(model, graph, u, h)
	local total = e.cum[#e.cum]
	for i, node in e.nodes do
		if node == v then
			return e.probs[i] / total
		end
	end
	return 0
end

-- How well does a model predict real steps? Average log-likelihood per step (higher = better)
-- and how often the most likely next node was right (accuracy) — over MOVES only, because
-- "stays where it is" is right most of the time and would hide the differences.
function OpponentModel.evaluate(model, graph, trajectories)
	local ll, steps, moves, hits = 0, 0, 0, 0
	for _, traj in trajectories do
		for t = 1, #traj - 1 do
			local a, b = traj[t], traj[t + 1]
			if a.node and b.node and a.node > 0 and b.node > 0 and a.hunterRoom and a.hunterRoom > 0 then
				local p = OpponentModel.prob(model, graph, a.node, b.node, a.hunterRoom)
				if OpponentModel.category(graph, a.node, b.node, a.hunterRoom) then
					ll += math.log(math.max(p, 1e-6))
					steps += 1
					if a.node ~= b.node then
						moves += 1
						-- Best guess among the moves (excluding "stay").
						local e = choices(model, graph, a.node, a.hunterRoom)
						local best, bestP = nil, -1
						for i = 2, #e.nodes do
							if e.probs[i] > bestP then
								best, bestP = e.nodes[i], e.probs[i]
							end
						end
						if best == b.node then
							hits += 1
						end
					end
				end
			end
		end
	end
	return {
		logLikelihood = if steps > 0 then ll / steps else 0,
		moveAccuracy = if moves > 0 then hits / moves else 0,
		steps = steps,
		moves = moves,
	}
end

return OpponentModel
