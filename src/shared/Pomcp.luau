--!nonstrict
-- POMCP (Silver & Veness, 2010): Monte Carlo tree search on the hunter's BELIEF.
--
-- The hunter cannot see, so it does not know the true state. Each simulation:
--   1. root sampling: draw one particle per player from the particle filters → one concrete
--      guess of where everyone is (likely places are drawn more often);
--   2. walk down the search tree, choosing macro-actions with UCB1 (try what looked good, but
--      keep trying the rest a little);
--   3. play the action out tick by tick: the hunter walks, stops to listen in each room it
--      reaches, opens closets; players move by the OpponentModel, which reacts to how close
--      the hunter is (so the plan expects people to run or hide, not stand still);
--   4. below the tree, a cheap random rollout until the horizon;
--   5. back up the discounted reward (a catch sooner is worth more) along the path.
-- After all simulations the hunter takes the root action visited most.
--
-- Actions:      "go to node X" (open it if it is a closet), with X = a neighbouring room, a
--               closet in this room, or one of the belief's peaks (root only); X = here means
--               "stay and listen".
-- Observations: abstracted to "caught someone" / "found nobody" — enough to branch the tree
--               on the one thing that changes the plan, and small enough to stay cheap.

local HouseGraph = require(script.Parent.HouseGraph)
local OpponentModel = require(script.Parent.OpponentModel)

local Pomcp = {}

Pomcp.DEFAULTS = {
	simulations = 200,
	budgetMs = nil, -- in the game: stop early after this many ms (MCTS is "anytime")
	minSimulations = 50, -- ...but never with fewer simulations than this
	horizon = 60, -- ticks (30 s) a simulation looks ahead
	gamma = 0.97, -- per-tick discount
	explore = 0.5, -- UCB1 constant (a return is at most the number of players)
	topK = 4, -- belief peaks added to the root's options
	maxDepth = 4, -- tree depth in macro-actions; deeper than that is rollout
	roomTicks = 4, -- ticks to cross one room at patrol speed
	closetTicks = 1,
	listenTicks = 2, -- the hunter stops to listen when it reaches a room
	searchTicks = 2, -- ...and takes a second to open a closet
	catchBump = 0.3, -- per tick, chance to bump into a player standing in its room
}

function Pomcp.new(graph, rng: Random, config)
	local cfg = table.clone(Pomcp.DEFAULTS)
	for k, v in config or {} do
		cfg[k] = v
	end
	local planner = { cfg = cfg, lastStats = nil }

	local model = OpponentModel.uniform()
	local gammaPow = table.create(cfg.horizon + 64, 0)
	for t = 0, cfg.horizon + 63 do
		gammaPow[t + 1] = cfg.gamma ^ t
	end

	------------------------------------------------------------ simulation

	-- One simulated world: s = { hunter, t, players = {node}, alive = {bool}, left }
	local function tickPlayers(s, hunterRoom)
		local players, alive = s.players, s.alive
		for i = 1, #players do
			if alive[i] then
				players[i] = OpponentModel.step(model, graph, rng, players[i], hunterRoom)
			end
		end
		s.t += 1
	end

	local function catch(s, i): number
		s.alive[i] = false
		s.left -= 1
		return gammaPow[math.min(s.t, #gammaPow - 1) + 1]
	end

	-- Stand still for `ticks`, bumping into anyone in this room.
	local function dwell(s, ticks: number): (number, boolean)
		local reward, caught = 0, false
		local node = s.hunter
		local room = graph.nodes[node].room
		local inRoom = graph.nodes[node].kind == "room"
		for _ = 1, ticks do
			if s.t >= cfg.horizon or s.left == 0 then
				break
			end
			tickPlayers(s, room)
			if inRoom then
				for i, p in s.players do
					if s.alive[i] and p == node and rng:NextNumber() < cfg.catchBump then
						reward += catch(s, i)
						caught = true
					end
				end
			end
		end
		return reward, caught
	end

	-- Play out one macro-action. Returns the discounted reward and whether anyone was caught.
	local function act(s, target: number): (number, boolean)
		local reward, caught = 0, false
		if target == s.hunter then
			return dwell(s, cfg.listenTicks)
		end
		while s.hunter ~= target and s.t < cfg.horizon and s.left > 0 do
			local from = s.hunter
			local nextNode = HouseGraph.nextStep(graph, from, target)
			local closetHop = graph.nodes[from].kind == "hide" or graph.nodes[nextNode].kind == "hide"
			local room = graph.nodes[from].room
			for _ = 1, if closetHop then cfg.closetTicks else cfg.roomTicks do
				tickPlayers(s, room)
			end
			s.hunter = nextNode
			if graph.nodes[nextNode].kind == "hide" then
				-- Open the closet: whoever is inside is caught.
				local r, c = dwell(s, cfg.searchTicks)
				reward += r
				caught = caught or c
				for i, p in s.players do
					if s.alive[i] and p == nextNode then
						reward += catch(s, i)
						caught = true
					end
				end
			else
				local r, c = dwell(s, cfg.listenTicks)
				reward += r
				caught = caught or c
			end
		end
		return reward, caught
	end

	local function rollout(s): number
		local total = 0
		while s.t < cfg.horizon and s.left > 0 do
			local node = s.hunter
			local room = graph.nodes[node].room
			local options = graph.roomNodes[room]
			local target
			if #options > 1 and rng:NextNumber() < 0.3 then
				target = options[rng:NextInteger(2, #options)] -- a closet in this room
			else
				local rooms = {}
				for _, v in graph.neighbors[room] do
					if graph.nodes[v].kind == "room" then
						table.insert(rooms, v)
					end
				end
				target = rooms[rng:NextInteger(1, #rooms)]
			end
			total += (act(s, target))
		end
		return total
	end

	------------------------------------------------------------ tree

	local function actionsFor(hunterNode: number, peaks: { number }?)
		local list, seen = {}, {}
		local function add(v)
			if not seen[v] then
				seen[v] = true
				table.insert(list, v)
			end
		end
		local room = graph.nodes[hunterNode].room
		add(hunterNode) -- stay and listen
		for _, v in graph.neighbors[room] do
			if graph.nodes[v].kind == "room" then
				add(v)
			end
		end
		for _, v in graph.roomNodes[room] do
			add(v) -- this room (if standing in its closet) and its closets
		end
		if peaks then
			for _, v in peaks do
				add(v)
			end
		end
		return list
	end

	local function newNode(hunterNode: number, peaks)
		local actions = actionsFor(hunterNode, peaks)
		local stats = table.create(#actions)
		for i = 1, #actions do
			stats[i] = { n = 0, q = 0, children = {} }
		end
		return { n = 0, actions = actions, stats = stats }
	end

	local function simulate(node, s, depth: number): number
		if s.t >= cfg.horizon or s.left == 0 then
			return 0
		end
		-- UCB1; unvisited actions first.
		local best, bestScore = 1, -math.huge
		local logN = math.log(math.max(node.n, 1))
		for i, st in node.stats do
			local score
			if st.n == 0 then
				score = math.huge - i -- deterministic order among the unvisited
			else
				score = st.q + cfg.explore * math.sqrt(logN / st.n)
			end
			if score > bestScore then
				best, bestScore = i, score
			end
		end
		local st = node.stats[best]
		local reward, caught = act(s, node.actions[best])
		local future
		if depth + 1 >= cfg.maxDepth then
			future = rollout(s)
		else
			local o = if caught then "c" else "n"
			local child = st.children[o]
			if not child then
				child = newNode(s.hunter, nil)
				st.children[o] = child
				future = rollout(s) -- a new history: estimate it with a rollout
			else
				future = simulate(child, s, depth + 1)
			end
		end
		local total = reward + future
		node.n += 1
		st.n += 1
		st.q += (total - st.q) / st.n
		return total
	end

	------------------------------------------------------------ public

	-- filters: { [key]: Filter } (particles to sample from); belief: mass per node (for peaks).
	-- Returns the node to go to.
	function planner.plan(hunterNode: number, filters, belief, opponentModel, overrides)
		model = opponentModel or model
		if overrides then
			for k, v in overrides do
				cfg[k] = v
			end
		end

		local peaks = {}
		if belief then
			local order = {}
			for node, m in belief do
				if m > 0.01 and node ~= hunterNode then
					table.insert(order, node)
				end
			end
			table.sort(order, function(a, b)
				return belief[a] > belief[b]
			end)
			for i = 1, math.min(cfg.topK, #order) do
				peaks[i] = order[i]
			end
		end

		local keys = {}
		for key in filters do
			table.insert(keys, key)
		end
		local root = newNode(hunterNode, peaks)
		if #keys == 0 then
			return hunterNode
		end

		local players, alive = table.create(#keys, 0), table.create(#keys, true)
		local s = { hunter = hunterNode, t = 0, players = players, alive = alive, left = #keys }
		local t0 = os.clock()
		local done = 0
		for sim = 1, cfg.simulations do
			if cfg.budgetMs and sim > cfg.minSimulations and (os.clock() - t0) * 1000 >= cfg.budgetMs then
				break
			end
			done = sim
			for i, key in keys do
				local filter = filters[key]
				players[i] = filter.particles[rng:NextInteger(1, filter.n)]
				alive[i] = true
			end
			s.hunter, s.t, s.left = hunterNode, 0, #keys
			simulate(root, s, 0)
		end

		local best, bestN, bestQ = 1, -1, -math.huge
		for i, st in root.stats do
			if st.n > bestN or (st.n == bestN and st.q > bestQ) then
				best, bestN, bestQ = i, st.n, st.q
			end
		end
		planner.lastStats = { root = root, best = best, simulations = done }
		return root.actions[best], bestQ
	end

	return planner
end

return Pomcp
