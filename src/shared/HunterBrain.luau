--!nonstrict
-- BLIND hunter brains with exactly the same senses, so they can be compared fairly.
--   belief: one particle filter per player fed only by sound (and closets it opened);
--           walks to where (probability / distance) is highest, and when the belief is
--           spread thin it sweeps the rooms it has not listened to for the longest time.
--   pomcp:  the same particle filters, but PLANS: Monte Carlo tree search over the belief
--           (Pomcp.luau) picks the move expected to catch someone soonest, simulating how
--           players will react to it.
--   rule:   the classic baseline: go to the last noise, else patrol random rooms.
-- belief and pomcp can use an OpponentModel (how players move); without one they assume a
-- fixed random walk.
--
-- Each takes one Observation per tick (0.5 s) and returns the node it wants to walk to.
--   Observation = {
--     hunterNode: number,
--     players:  { key },                 -- players taking part (not downed)
--     noises:   { roomNodeId },          -- sounds heard this tick
--     quiet:    { [nodeId]: true },      -- listened here and heard nothing (soft evidence)
--     checked:  { [nodeId]: true },      -- opened / touched here and found nobody (hard evidence)
--     seen:     { [key]: nodeId }?,      -- exact positions learned another way (a catch)
--     idle:     boolean?,                -- false = the target will not be used this tick
--                                        --         (walking, listening): pomcp skips planning
--     patrolSpeed: number?,              -- studs/s, so the planner knows how long a room takes
--   }

local ParticleFilter = require(script.Parent.ParticleFilter)
local Pomcp = require(script.Parent.Pomcp)
local HouseGraph = require(script.Parent.HouseGraph)

local PARTICLES = 300
local NOISE_TRUST = 0.6 -- a heard sound might be another player or a decoy
local QUIET_LIKELIHOOD = 0.55 -- "heard nothing here" barely rules a quiet player out
local DISTANCE_PENALTY = 0.6
local SWEEP_WEIGHT = 0.03 -- how much "not listened to for a while" is worth
local SWEEP_HORIZON = 120 -- ticks (60 s) until a room counts as fully stale
local TICK = 0.5

local HunterBrain = {}

HunterBrain.KINDS = { "rule", "belief", "pomcp" }

-- Particle filters for every player + the summed belief. Shared by `belief` and `pomcp`.
local function newTracker(graph, rng: Random, startNode: number?, model)
	local brain = { filters = {}, belief = table.create(#graph.nodes, 0), lastMs = 0, model = model }

	-- The hunter learns a player's exact node (caught, revived): collapse onto it.
	function brain.reset(key, node: number)
		local filter = brain.filters[key]
		if filter then
			ParticleFilter.reset(filter, node)
		else
			brain.filters[key] = ParticleFilter.new(graph, PARTICLES, rng, node)
		end
	end

	function brain.observe(obs)
		local present = {}
		for _, key in obs.players do
			present[key] = true
			if not brain.filters[key] then
				brain.filters[key] = ParticleFilter.new(graph, PARTICLES, rng, startNode)
			end
		end
		for key in brain.filters do
			if not present[key] then
				brain.filters[key] = nil
			end
		end

		local belief = brain.belief
		for i = 1, #belief do
			belief[i] = 0
		end
		local seen = obs.seen or {}
		local hunterRoom = graph.nodes[obs.hunterNode].room
		for key, filter in brain.filters do
			ParticleFilter.predict(filter, brain.model, hunterRoom)
			if seen[key] then
				ParticleFilter.observeSeen(filter, seen[key])
			else
				for _, noise in obs.noises do
					ParticleFilter.observeNoise(filter, noise, NOISE_TRUST)
				end
				if obs.quiet then
					ParticleFilter.observeNotSeen(filter, obs.quiet, QUIET_LIKELIHOOD)
				end
				if obs.checked then
					ParticleFilter.observeNotSeen(filter, obs.checked)
				end
			end
			ParticleFilter.resample(filter)
			ParticleFilter.addBelief(filter, belief)
		end
	end

	return brain
end

function HunterBrain.newBelief(graph, rng: Random, startNode: number?, opts)
	local brain = newTracker(graph, rng, startNode, opts and opts.model)
	brain.kind = "belief"
	local tick = 0
	local lastVisit = table.create(#graph.nodes, -SWEEP_HORIZON)

	function brain.decide(obs)
		local t0 = os.clock()
		tick += 1
		lastVisit[obs.hunterNode] = tick
		brain.observe(obs)

		local belief = brain.belief
		local players = math.max(1, #obs.players)
		local here = graph.dist[obs.hunterNode]
		local best, bestScore = obs.hunterNode, -math.huge
		for node = 1, #belief do
			local staleness = math.min(tick - lastVisit[node], SWEEP_HORIZON) / SWEEP_HORIZON
			local sweep = if graph.nodes[node].kind == "room" then SWEEP_WEIGHT * staleness else 0
			local score = (belief[node] / players + sweep) / (1 + DISTANCE_PENALTY * here[node])
			if node ~= obs.hunterNode and score > bestScore then
				best, bestScore = node, score
			end
		end
		brain.lastMs = (os.clock() - t0) * 1000
		return best
	end

	return brain
end

function HunterBrain.newPomcp(graph, rng: Random, startNode: number?, opts)
	opts = opts or {}
	local brain = newTracker(graph, rng, startNode, opts.model)
	brain.kind = "pomcp"
	brain.planMs = 0 -- cost of the last actual planning step
	brain.plans = 0
	local planner = Pomcp.new(graph, rng, opts.planner)
	local target: number? = nil

	function brain.decide(obs)
		local t0 = os.clock()
		brain.observe(obs)
		if obs.idle ~= false or not target then
			local roomTicks = math.max(1, math.round(HouseGraph.ROOM_SIZE / (obs.patrolSpeed or 12) / TICK))
			target = planner.plan(obs.hunterNode, brain.filters, brain.belief, brain.model, { roomTicks = roomTicks })
			brain.plans += 1
			brain.planMs = (os.clock() - t0) * 1000
		end
		brain.lastMs = (os.clock() - t0) * 1000
		return target
	end

	-- What the planner thought of each option last time (for the debug view / the report).
	function brain.explain()
		local s = planner.lastStats
		if not s then
			return nil
		end
		local rows = {}
		for i, a in s.root.actions do
			table.insert(rows, { node = a, visits = s.root.stats[i].n, value = s.root.stats[i].q, chosen = i == s.best })
		end
		return rows
	end

	return brain
end

-- Search reflex shared by the game and the simulator: the hiding spot in `room` that the
-- hunter is most sure a player hides in, if that belief is at least `threshold`.
HunterBrain.SEARCH_THRESHOLD = 0.3
function HunterBrain.suspiciousSpot(brain, graph, room: number, threshold: number?): number?
	if not brain.filters then
		return nil -- the rule brain has no beliefs
	end
	local best, bestP = nil, threshold or HunterBrain.SEARCH_THRESHOLD
	for _, node in graph.roomNodes[room] do
		if graph.nodes[node].kind == "hide" then
			for _, filter in brain.filters do
				local hits = 0
				for _, p in filter.particles do
					if p == node then
						hits += 1
					end
				end
				if hits / filter.n >= bestP then
					best, bestP = node, hits / filter.n
				end
			end
		end
	end
	return best
end

function HunterBrain.newRule(graph, rng: Random)
	local brain = { kind = "rule", lastMs = 0 }
	local noiseTarget: number? = nil
	local patrolTarget: number? = nil

	function brain.reset() end

	function brain.decide(obs)
		local t0 = os.clock()
		local here = graph.dist[obs.hunterNode]
		local target

		for _, node in obs.noises do
			if not noiseTarget or here[node] < here[noiseTarget] then
				noiseTarget = node
			end
		end
		if noiseTarget and noiseTarget ~= obs.hunterNode then
			target = noiseTarget
		else
			if noiseTarget then
				-- Reached the noise: open one of this room's closets half the time.
				noiseTarget = nil
				local closets = {}
				for _, id in graph.roomNodes[graph.nodes[obs.hunterNode].room] do
					if graph.nodes[id].kind == "hide" then
						table.insert(closets, id)
					end
				end
				if #closets > 0 and rng:NextNumber() < 0.5 then
					patrolTarget = closets[rng:NextInteger(1, #closets)]
				end
			end
			if not patrolTarget or patrolTarget == obs.hunterNode then
				patrolTarget = rng:NextInteger(1, graph.roomCount)
			end
			target = patrolTarget
		end
		brain.lastMs = (os.clock() - t0) * 1000
		return target
	end

	return brain
end

-- kind: "rule" | "belief" | "pomcp"; opts: { model = OpponentModel?, planner = Pomcp config? }
function HunterBrain.new(kind: string, graph, rng: Random, startNode: number?, opts)
	if kind == "belief" then
		return HunterBrain.newBelief(graph, rng, startNode, opts)
	elseif kind == "pomcp" then
		return HunterBrain.newPomcp(graph, rng, startNode, opts)
	end
	return HunterBrain.newRule(graph, rng)
end

return HunterBrain
