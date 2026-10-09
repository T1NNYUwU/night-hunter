--!nonstrict
-- Headless nights: the BLIND hunter vs scripted player bots on the house graph. No Instances,
-- so hundreds of nights run in seconds. Uses the same HunterBrain and Acoustics modules as
-- the game, so the experiments describe the game players actually play.
--
--   print(require(game.ReplicatedStorage.NightHunter:Clone().Sim).report({ episodes = 100 }))

local Acoustics = require(script.Parent.Acoustics)
local HouseGraph = require(script.Parent.HouseGraph)
local HunterBrain = require(script.Parent.HunterBrain)

local DT = 0.5
local CLOSET_TICKS = 1
local LISTEN_TICKS = 2 -- the hunter stops to listen when it reaches a room
local SEARCH_TICKS = 2 -- ...and takes a second to open a closet
local CATCH_BUMP = 0.3 -- walked into a room with someone in it (blind, so it may miss)
local CATCH_CHARGE = 0.8 -- rushed at a sound made in this very room
local BREATH_TICKS = 12 -- a hidden bot holds its breath 6 s when the hunter is in its room
local SPAWN_ROOM, HUNTER_START = HouseGraph.SPAWN_ROOM, HouseGraph.DEFAULT_LAIR

local Sim = {}

local function roomTicks(speed: number): number
	return math.max(1, math.round(HouseGraph.ROOM_SIZE / speed / DT))
end

local function newMover(node: number)
	return { node = node, nextNode = nil, timer = 0 }
end

local function stepMover(m): boolean
	if m.nextNode then
		m.timer -= 1
		if m.timer <= 0 then
			m.node = m.nextNode
			m.nextNode = nil
			return true -- arrived this tick
		end
	end
	return false
end

local function moveToward(graph, m, goal: number, speed: number)
	if m.nextNode or m.node == goal then
		return
	end
	local nextNode = HouseGraph.nextStep(graph, m.node, goal)
	local closetHop = graph.nodes[m.node].kind == "hide" or graph.nodes[nextNode].kind == "hide"
	m.nextNode = nextNode
	m.timer = if closetHop then CLOSET_TICKS else roomTicks(speed)
end

local function roomsWithin(graph, room: number, maxDist: number, minDist: number?)
	local out = {}
	for r = 1, graph.roomCount do
		local d = graph.dist[room][r]
		if d <= maxDist and d >= (minDist or 0) then
			table.insert(out, r)
		end
	end
	return out
end

local function closetIn(graph, room: number): number?
	for _, id in graph.roomNodes[room] do
		if graph.nodes[id].kind == "hide" then
			return id
		end
	end
	return nil
end

local function closetNear(graph, rng: Random, room: number): number?
	local options = {}
	for _, r in roomsWithin(graph, room, 1) do
		for _, id in graph.roomNodes[r] do
			if graph.nodes[id].kind == "hide" then
				table.insert(options, id)
			end
		end
	end
	return if #options > 0 then options[rng:NextInteger(1, #options)] else nil
end

-- The neighbouring room farthest from the hunter (never the hunter's own room).
local function escapeRoom(graph, rng: Random, node: number, hunterRoom: number): number?
	local best, bestScore = nil, -1
	for _, v in graph.neighbors[node] do
		if graph.nodes[v].kind == "room" and v ~= hunterRoom then
			local score = graph.dist[hunterRoom][v] + rng:NextNumber() * 0.1
			if score > bestScore then
				best, bestScore = v, score
			end
		end
	end
	return best
end

local function nearestCrateRoom(graph, world, room: number): number?
	local best, bestDist = nil, math.huge
	for _, r in world.crates do
		if graph.dist[room][r] < bestDist then
			best, bestDist = r, graph.dist[room][r]
		end
	end
	return best
end

local function takeCrate(world, room: number)
	for i, r in world.crates do
		if r == room then
			table.remove(world.crates, i)
			world.collected += 1
			return
		end
	end
end

-- Player bots. They hear the hunter's footsteps one room away. Policies:
--   wanderer  walks around, sprints away when the hunter is close (loud, careless)
--   hider     heads for closets and hides; crouches when the hunter is close
--   decoy     like hider, and throws decoy noises away from itself
--   collector plays the real game: fetch crates; crouch or hide when the hunter is close
local function actPlayer(graph, rng: Random, p, hunter, now: number, sounds, world)
	local myNode = graph.nodes[p.node]
	local hiding = myNode.kind == "hide"
	local hunterRoom = graph.nodes[hunter.node].room
	local near = graph.dist[hunterRoom][myNode.room] <= 1
	local sameRoom = hunterRoom == myNode.room

	if p.policy == "decoy" and now >= p.decoyReady and graph.dist[hunterRoom][myNode.room] <= 2 then
		local best, bestScore = nil, -1
		for _, r in roomsWithin(graph, myNode.room, 3, 2) do
			local score = graph.dist[myNode.room][r] * 2 - graph.dist[hunterRoom][r] + rng:NextNumber() * 0.1
			if score > bestScore then
				best, bestScore = r, score
			end
		end
		if best then
			table.insert(sounds, { room = best, loudness = Acoustics.LOUDNESS.decoy })
			p.decoyReady = now + 8
		end
	end

	if p.collecting then
		p.collecting -= 1
		if p.collecting <= 0 then
			p.collecting = nil
			takeCrate(world, myNode.room)
			table.insert(sounds, { room = myNode.room, loudness = Acoustics.LOUDNESS.crate })
		end
		return
	end

	-- Hidden with the hunter in the room: hold the breath; out of air = gasp, then breathe.
	if hiding then
		if sameRoom and p.breath > 0 then
			p.breath -= 1 / BREATH_TICKS
			if p.breath <= 0 then
				p.breath = 0
				table.insert(sounds, { room = myNode.room, node = p.node, loudness = Acoustics.LOUDNESS.gasp })
			end
		else
			if sameRoom then
				table.insert(sounds, { room = myNode.room, node = p.node, loudness = Acoustics.LOUDNESS.breath })
			end
			p.breath = math.min(1, p.breath + 1 / 8)
		end
	end

	if not p.nextNode then
		p.stance = "walk"
		if hiding then
			if p.hideUntil == 0 then
				p.hideUntil = now + (if p.policy == "collector" then rng:NextNumber(4, 8) else rng:NextNumber(10, 30))
			end
			if now >= p.hideUntil and not near then
				p.hideUntil = 0
				local rooms = roomsWithin(graph, myNode.room, 2)
				p.goal = rooms[rng:NextInteger(1, #rooms)]
				p.stance = "crouch"
			else
				p.goal = p.node
			end
		elseif sameRoom then
			p.stance = "sprint"
			p.goal = escapeRoom(graph, rng, p.node, hunterRoom) or p.node
		elseif near then
			if p.policy == "wanderer" then
				p.stance = "sprint"
				p.goal = escapeRoom(graph, rng, p.node, hunterRoom) or p.node
			else
				p.stance = "crouch"
				p.goal = closetIn(graph, myNode.room) or p.goal or p.node
			end
		elseif p.policy == "collector" then
			local crateRoom = nearestCrateRoom(graph, world, myNode.room)
			if crateRoom == p.node then
				p.collecting = 2 -- 1 s to pry it open
				return
			end
			p.goal = crateRoom or p.node
		elseif not p.goal or p.goal == p.node then
			local closet = if p.policy ~= "wanderer" and rng:NextNumber() < 0.6 then closetNear(graph, rng, myNode.room) else nil
			p.goal = closet or rng:NextInteger(1, graph.roomCount)
		end
		moveToward(graph, p, p.goal, Acoustics.SPEED[p.stance])
	end

	if p.nextNode and graph.nodes[p.nextNode].kind == "room" then
		local loud = if hiding then Acoustics.LOUDNESS.unhide else Acoustics.LOUDNESS[p.stance]
		table.insert(sounds, { room = myNode.room, node = if hiding then p.node else nil, loudness = loud })
	elseif p.nextNode and graph.nodes[p.nextNode].kind == "hide" and not p.entering then
		-- Getting into a spot: as loud as the stance it was entered at (and it gives the spot away).
		p.entering = true
		table.insert(sounds, { room = myNode.room, node = p.nextNode, loudness = Acoustics.LOUDNESS[Acoustics.hideEntry(p.stance)] })
	end
	if not p.nextNode then
		p.entering = false
	end
end

function Sim.runEpisode(opts)
	local graph = opts.graph or HouseGraph.build()
	local rng = Random.new(opts.seed)
	local brain = HunterBrain.new(opts.brain, graph, Random.new(opts.seed + 7919), SPAWN_ROOM, { model = opts.model, planner = opts.planner })
	local hearing = opts.hearing or 1
	local patrolSpeed = opts.patrolSpeed or 12
	local chargeSpeed = opts.chargeSpeed or 18
	local wakeTicks = opts.wakeTicks or 0

	-- Lair: a fixed room, or "random" = any room at least 2 rooms from the spawn (as in the game).
	local lair = opts.lair or HUNTER_START
	if lair == "random" then
		local options = {}
		for r = 1, graph.roomCount do
			if graph.dist[SPAWN_ROOM][r] >= 2 then
				table.insert(options, r)
			end
		end
		lair = options[rng:NextInteger(1, #options)]
	end
	local hunter = newMover(lair)
	hunter.dwell = 0
	hunter.charging = false

	local players = {}
	for i = 1, opts.players or 1 do
		local p = newMover(SPAWN_ROOM)
		p.key = "p" .. i
		p.policy = opts.policy or "hider"
		p.stance = "walk"
		p.hideUntil = 0
		p.decoyReady = 0
		p.breath = 1
		p.entering = false
		p.caught = false
		table.insert(players, p)
	end

	local result = { caught = 0, players = #players, firstCatch = nil, allCaught = nil, win = nil }
	local world = { crates = {}, collected = 0 }
	if opts.quota then
		for _ = 1, opts.quota + 2 do
			table.insert(world.crates, rng:NextInteger(2, graph.roomCount))
		end
		result.win = false
	end

	local truthSum, truthCount, msSum, ticks = 0, 0, 0, 0
	-- opts.record: keep every player's node per tick (and where the hunter was) for fitting
	-- an OpponentModel. node 0 = caught.
	local trajectories = nil
	if opts.record then
		trajectories = {}
		for i = 1, #players do
			trajectories[i] = {}
		end
	end
	local maxTicks = math.floor((opts.seconds or 180) / DT)

	for tick = 1, maxTicks do
		local now = tick * DT
		local sounds = {}
		for _, p in players do
			if not p.caught then
				actPlayer(graph, rng, p, hunter, now, sounds, world)
				stepMover(p)
			end
		end

		local awake = tick > wakeTicks
		local checked = {}
		if awake then
			if hunter.dwell > 0 then
				hunter.dwell -= 1
				if hunter.dwell == 0 and graph.nodes[hunter.node].kind == "hide" then
					checked[hunter.node] = true -- closet opened
				end
			elseif stepMover(hunter) then
				hunter.dwell = if graph.nodes[hunter.node].kind == "hide" then SEARCH_TICKS elseif hunter.charging then 1 else LISTEN_TICKS
			end
		end

		-- Catches: an opened closet always; bumping into someone in the room sometimes.
		for _, p in players do
			if not p.caught then
				local chance = 0
				if checked[p.node] then
					chance = 1
				elseif p.node == hunter.node and graph.nodes[p.node].kind == "room" and not hunter.nextNode then
					chance = if hunter.charging then CATCH_CHARGE else CATCH_BUMP
				end
				if chance > 0 and rng:NextNumber() < chance then
					p.caught = true
					result.caught += 1
					result.firstCatch = result.firstCatch or now
				end
			end
		end
		if opts.quota and world.collected >= opts.quota then
			result.win = true
			result.winTime = now
			break
		end
		if result.caught == #players then
			result.allCaught = now
			break
		end

		-- Hearing.
		local hunterRoom = graph.nodes[hunter.node].room
		local obs = {
			hunterNode = hunter.node,
			players = {},
			noises = {},
			quiet = {},
			checked = checked,
			idle = awake and hunter.dwell <= 0 and not hunter.nextNode,
			patrolSpeed = patrolSpeed,
		}
		for _, p in players do
			if not p.caught then
				table.insert(obs.players, p.key)
			end
		end
		local closest, closestHops = nil, math.huge
		local heardHere = false
		for _, sound in sounds do
			local hops = graph.dist[hunterRoom][sound.room]
			if rng:NextNumber() < Acoustics.hearChance(sound.loudness, hops, hearing) then
				-- From the same room, a hiding sound gives away the exact spot (as in the game).
				local where = if hops == 0 and sound.node then sound.node else sound.room
				table.insert(obs.noises, where)
				heardHere = heardHere or hops == 0
				if hops < closestHops then
					closest, closestHops = where, hops
				end
			end
		end
		if not heardHere and not hunter.nextNode then
			obs.quiet[hunterRoom] = true
		end

		local target = brain.decide(obs) -- it keeps listening while asleep
		if awake and hunter.dwell <= 0 then
			if closest and closestHops <= 1 then
				-- Reflex: a sound right here or next door → rush at it.
				hunter.charging = true
				hunter.dwell = 0
				moveToward(graph, hunter, closest, chargeSpeed)
			elseif not hunter.nextNode then
				hunter.charging = false
				-- Search reflex (as in the game): open a spot here it is sure enough about.
				local spot = HunterBrain.suspiciousSpot(brain, graph, hunterRoom)
				moveToward(graph, hunter, spot or target, patrolSpeed)
			end
		end
		msSum += brain.lastMs
		ticks += 1
		if trajectories then
			for i, p in players do
				table.insert(trajectories[i], { node = if p.caught then 0 else p.node, hunterRoom = graph.nodes[hunter.node].room })
			end
		end

		if brain.filters then
			for _, p in players do
				local filter = not p.caught and brain.filters[p.key]
				if filter then
					local hits = 0
					for _, node in filter.particles do
						if node == p.node then
							hits += 1
						end
					end
					truthSum += hits / filter.n
					truthCount += 1
				end
			end
		end
	end

	result.beliefTruth = if truthCount > 0 then truthSum / truthCount else nil
	result.brainMs = if ticks > 0 then msSum / ticks else 0
	result.planMs = brain.planMs
	result.trajectories = trajectories
	return result
end

local function mean(list)
	if #list == 0 then
		return nil
	end
	local s = 0
	for _, v in list do
		s += v
	end
	return s / #list
end

local function ci95(list)
	local m = mean(list)
	if not m or #list < 2 then
		return 0
	end
	local s = 0
	for _, v in list do
		s += (v - m) ^ 2
	end
	return 1.96 * math.sqrt(s / (#list - 1)) / math.sqrt(#list)
end

-- Same seeds for every brain, so differences come from the brain, not luck.
function Sim.compare(opts)
	local graph = HouseGraph.build()
	local rows = {}
	local episodes = opts.episodes or 100
	for _, policy in opts.policies or { "wanderer", "hider", "decoy", "collector" } do
		for _, spec in opts.brains or { "rule", "belief" } do
			if type(spec) == "string" then
				spec = { label = spec, kind = spec }
			end
			local caught, total, survived, wins, firsts, truths, ms = 0, 0, 0, 0, {}, {}, {}
			for seed = (opts.firstSeed or 1), (opts.firstSeed or 1) + episodes - 1 do
				if opts.yield and seed % 10 == 0 then
					task.wait() -- long runs: let Studio breathe
				end
				local r = Sim.runEpisode({
					graph = graph,
					seed = seed,
					brain = spec.kind,
					model = spec.model,
					planner = spec.planner,
					policy = policy,
					players = opts.players or 2,
					seconds = opts.seconds or 180,
					lair = opts.lair,
					hearing = opts.hearing,
					patrolSpeed = opts.patrolSpeed,
					chargeSpeed = opts.chargeSpeed,
					wakeTicks = opts.wakeTicks,
					quota = opts.quota or (if policy == "collector" then 3 else nil),
				})
				caught += r.caught
				total += r.players
				if r.caught == 0 then
					survived += 1
				end
				if r.win then
					wins += 1
				end
				table.insert(firsts, r.firstCatch or (opts.seconds or 180))
				if r.beliefTruth then
					table.insert(truths, r.beliefTruth)
				end
				table.insert(ms, r.brainMs)
			end
			table.insert(rows, {
				policy = policy,
				brain = spec.label,
				caught = caught,
				total = total,
				wins = wins,
				episodes = episodes,
				catchRate = caught / total,
				survival = survived / episodes,
				winRate = wins / episodes,
				firstCatch = mean(firsts),
				firstCatchCi = ci95(firsts),
				beliefTruth = mean(truths),
				brainMs = mean(ms),
			})
		end
	end
	return rows
end

function Sim.report(opts)
	opts = opts or {}
	local rows = Sim.compare(opts)
	local lines = {
		("players=%d  seconds=%d  episodes=%d per row (a night with no catch counts as the full night)"):format(
			opts.players or 2,
			opts.seconds or 180,
			opts.episodes or 100
		),
		"policy     brain          catch%   team-survived   win%    first-catch(s)    belief-on-truth   ms/decision",
	}
	for _, r in rows do
		table.insert(
			lines,
			("%-10s %-14s %5.1f%%   %5.1f%%          %5.1f%%  %6.1f ± %-5.1f      %-15s   %.3f"):format(
				r.policy,
				r.brain,
				r.catchRate * 100,
				r.survival * 100,
				r.winRate * 100,
				r.firstCatch,
				r.firstCatchCi,
				if r.beliefTruth then ("%.1f%%"):format(r.beliefTruth * 100) else "-",
				r.brainMs
			)
		)
	end
	return table.concat(lines, "\n")
end

return Sim
