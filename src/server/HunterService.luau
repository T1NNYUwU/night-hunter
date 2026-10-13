--!nonstrict
-- The blind hunter in the real game. It never sees players: every 0.5 s it listens (using
-- the shared Acoustics model), feeds what it heard to the brain, and acts:
--   charge  a sound in its room or next door → rush to where the sound came from (fast)
--   search  otherwise walk to the node the brain picks (slower), stop to listen in each room,
--           open closets the brain suspects
-- It catches a player by touching them, or by opening the closet they hide in.
--
-- start(house, hooks) returns a handle the NightCycle drives:
--   setActive(bool)  newNight()  setLair(room)  setSpeeds(patrol, charge)  setHearing(scale)
--   emitSound(room, position?, kind)  playerRevived(player, node)
--   setBrain(kind, useModel)  setModel(opponentModel)  stats()
-- hooks.isDowned(player) -> bool   downed players make no sound and cannot be caught again
-- hooks.onCaught(player)
-- hooks.onTick(sample)  every 0.5 s: { hunterRoom, nodes = { [Player] = node or 0 } } (telemetry)
-- hooks.isHidden(player) -> bool   hidden players cannot be caught by touch, only by searching
-- hooks.searchSpot(node) -> { Player }   open a hiding spot; returns who was inside (HideService)
--
-- Searching hiding spots: the hunter opens a spot when (a) it heard someone get into THAT
-- spot from the same room (it charges, then opens it), or (b) its belief that a player is in
-- a spot of the room it stands in reaches HunterBrain.SEARCH_THRESHOLD ("suspicious enough"), or (c) the
-- brain sends it there.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("NightHunter")
local Acoustics = require(Shared:WaitForChild("Acoustics"))
local HouseGraph = require(Shared:WaitForChild("HouseGraph"))
local HunterBrain = require(Shared:WaitForChild("HunterBrain"))
local Sounds = require(Shared:WaitForChild("Sounds"))

local TICK = 0.5
local LISTEN_SECONDS = 1.0 -- pause in each room it reaches while searching
local SEARCH_SECONDS = 1.2 -- opening a closet
local CHARGE_MEMORY = 2.5 -- keeps rushing at the last precise sound this long
local CATCH_RADIUS = 3.5
local PLAN_BUDGET_MS = 4
local CLOSET_RADIUS = 2.6
local DECOY_COOLDOWN = 4
local SPAWN_ROOM, HUNTER_START = HouseGraph.SPAWN_ROOM, HouseGraph.DEFAULT_LAIR

local HunterService = {}

local function makeRemote(parent, name)
	local remote = Instance.new("RemoteEvent")
	remote.Name = name
	remote.Parent = parent
	return remote
end

local function getRoot(player: Player): BasePart?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return nil
	end
	return character:FindFirstChild("HumanoidRootPart")
end

-- The hunter's body: the audited "HunterRig" from ServerStorage.AssetLibrary (an eyeless,
-- hunched creature, see docs/assets.md). Its root is anchored and moved with PivotTo; the
-- limbs hang on Motor6D joints so clients can animate them. If the library is missing, a
-- blocky stand-in is built instead. Either way the model's pivot is at its feet.
local function buildHunterModel(parent)
	local library = game:GetService("ServerStorage"):FindFirstChild("AssetLibrary")
	local template = library and library:FindFirstChild("HunterRig")
	local model
	if template then
		model = template:Clone()
		model.Name = "Hunter"
	else
		model = HunterService._blockyModel()
	end
	local root = model.PrimaryPart

	-- 3D sounds on the body: players hear it coming before they see it.
	local steps = Instance.new("Sound")
	steps.Name = "Steps"
	steps.SoundId = Sounds.hunterSteps
	steps.Looped = true
	steps.Volume = 1.2
	steps.RollOffMinDistance = 8
	steps.RollOffMaxDistance = 70
	steps.Parent = root
	local growl = Instance.new("Sound")
	growl.Name = "Growl"
	growl.SoundId = Sounds.hunterGrowl
	growl.Volume = 1.5
	growl.RollOffMinDistance = 10
	growl.RollOffMaxDistance = 90
	growl.Parent = root

	model.Parent = parent
	return model
end

function HunterService._blockyModel()
	local model = Instance.new("Model")
	model.Name = "Hunter"
	local skin = Color3.fromRGB(205, 200, 190)
	local cloth = Color3.fromRGB(18, 16, 18)
	local function piece(name, size, offset, color, material, shape)
		local p = Instance.new("Part")
		p.Name = name
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Size = size
		p.CFrame = CFrame.new(offset)
		p.Color = color
		p.Material = material
		if shape then
			p.Shape = shape
		end
		p.Parent = model
		return p
	end
	local body = piece("Body", Vector3.new(1.8, 4.6, 1.1), Vector3.new(0, 5.2, 0), cloth, Enum.Material.Fabric)
	piece("Legs", Vector3.new(1.4, 3.2, 0.9), Vector3.new(0, 1.6, 0), cloth, Enum.Material.Fabric)
	piece("ArmL", Vector3.new(0.45, 5.2, 0.45), Vector3.new(-1.25, 4.6, 0), skin, Enum.Material.SmoothPlastic)
	piece("ArmR", Vector3.new(0.45, 5.2, 0.45), Vector3.new(1.25, 4.6, 0), skin, Enum.Material.SmoothPlastic)
	piece("Head", Vector3.new(1.5, 1.9, 1.4), Vector3.new(0, 8.5, 0), skin, Enum.Material.SmoothPlastic)
	piece("Mouth", Vector3.new(0.9, 0.12, 0.1), Vector3.new(0, 8.1, -0.72), Color3.fromRGB(40, 0, 0), Enum.Material.SmoothPlastic)
	model.PrimaryPart = body
	body.PivotOffset = CFrame.new(0, -5.2, 0) -- pivot at the feet
	return model
end

function HunterService.start(house, hooks)
	local graph = house.graph
	local origin = house.origin
	local rng = Random.new()

	local remotes = ReplicatedStorage:FindFirstChild("NightHunterRemotes") or Instance.new("Folder")
	remotes.Name = "NightHunterRemotes"
	local decoyRemote = makeRemote(remotes, "Decoy")
	local modeRemote = makeRemote(remotes, "ToggleMode")
	local beliefRemote = makeRemote(remotes, "ToggleBelief")
	remotes.Parent = ReplicatedStorage

	local state = Workspace:FindFirstChild("NightHunterState") or Instance.new("Folder")
	state.Name = "NightHunterState"
	state.Parent = Workspace

	-- Which brain hunts (rule / belief / pomcp), and whether it uses the learned OpponentModel.
	local brainKind, useModel = "pomcp", false
	local opponentModel = nil
	local function makeBrain(startNode: number?)
		local model = if useModel then opponentModel else nil
		-- Planning gets at most PLAN_BUDGET_MS per decision so a full server never hitches.
		return HunterBrain.new(brainKind, graph, Random.new(), startNode, { model = model, planner = { budgetMs = PLAN_BUDGET_MS } })
	end
	local function brainLabel(): string
		return brainKind .. (if useModel and opponentModel and brainKind ~= "rule" then "+model" else "")
	end
	local brain = makeBrain(SPAWN_ROOM)
	local perf = { decisions = 0, msSum = 0, plans = 0, planMsSum = 0, planMsMax = 0 }
	local active = false
	local patrolSpeed, chargeSpeed = 10, 15
	local hearScale = 1
	local lair = HUNTER_START
	local showBelief = true
	local caught = 0
	local pendingSounds = {} -- { room, pos?, loudness, decoy }
	local lastDecoy = {}

	local model = buildHunterModel(house.root)
	local stepsSound = model.PrimaryPart.Steps
	local growlSound = model.PrimaryPart.Growl
	local lastGrowl = 0
	local hunter = {
		node = HUNTER_START,
		pos = Vector3.zero,
		path = nil, -- next graph node while searching
		charge = nil, -- { room, pos, untilTime }
		dwell = 0,
		dwellIsSearch = false,
		facing = Vector3.new(0, 0, -1),
		checked = {}, -- closets opened since the last tick
		mode = "asleep",
	}

	local function worldPos(node)
		return origin + graph.nodes[node].pos
	end

	local function currentRoom()
		return HouseGraph.roomAt(hunter.pos - origin) or graph.nodes[hunter.node].room
	end

	local function placeAtStart()
		hunter.node = lair
		hunter.pos = worldPos(lair)
		hunter.path = nil
		hunter.charge = nil
		hunter.dwell = 0
		hunter.mode = "asleep"
		hunter.route = nil
		if model and model.PrimaryPart and model.PrimaryPart:FindFirstChild("Steps") then
			model.PrimaryPart.Steps:Stop()
		end
		model:PivotTo(CFrame.lookAt(hunter.pos, hunter.pos + hunter.facing))
	end
	placeAtStart()

	local function isDowned(player)
		return hooks and hooks.isDowned and hooks.isDowned(player)
	end

	local function pushState()
		state:SetAttribute("Mode", brainLabel())
		state:SetAttribute("ModelVersion", if opponentModel then opponentModel.version else "none")
		state:SetAttribute("Caught", caught)
		state:SetAttribute("BrainMs", math.round(brain.lastMs * 1000) / 1000)
		state:SetAttribute("ShowBelief", showBelief)
		state:SetAttribute("HunterNode", hunter.node)
		state:SetAttribute("HunterMode", hunter.mode)
	end

	local function catchPlayer(player: Player)
		if isDowned(player) then
			return
		end
		caught += 1
		hunter.charge = nil
		if hooks and hooks.onCaught then
			hooks.onCaught(player)
		end
		local root = getRoot(player)
		local node = root and HouseGraph.nodeAt(graph, root.Position - origin, CLOSET_RADIUS)
		if node then
			brain.reset(tostring(player.UserId), node) -- it knows exactly where its victim lies
		end
	end

	local function drawBelief()
		local mass = brain.belief
		local players = math.max(1, #Players:GetPlayers())
		for id, marker in house.markers do
			local m = if active and showBelief and mass then mass[id] / players else 0
			if m and m > 0.01 then
				local size = 0.6 + 5 * math.sqrt(m)
				marker.Size = Vector3.new(size, size, size)
				marker.Transparency = 0.15
			else
				marker.Transparency = 1
			end
		end
	end

	local suspiciousSpot -- defined below (search reflex)

	local function listen()
		local room = currentRoom()
		local obs = { hunterNode = hunter.node, players = {}, noises = {}, quiet = {}, checked = hunter.checked }
		hunter.checked = {}

		local sounds = {}
		local sample = { hunterRoom = room, nodes = {} }
		for _, player in Players:GetPlayers() do
			local root = getRoot(player)
			local node = root and not isDowned(player) and HouseGraph.nodeAt(graph, root.Position - origin, CLOSET_RADIUS)
			sample.nodes[player] = node or 0
			if node then
				table.insert(obs.players, tostring(player.UserId))
				local v = root.AssemblyLinearVelocity
				local stance = Acoustics.stanceFromSpeed(Vector3.new(v.X, 0, v.Z).Magnitude)
				if stance and graph.nodes[node].kind == "room" then
					table.insert(sounds, { room = graph.nodes[node].room, pos = root.Position, loudness = Acoustics.LOUDNESS[stance] })
				end
			end
		end
		for _, s in pendingSounds do
			table.insert(sounds, s)
			if s.decoy then
				house.ping(s.room, Color3.fromRGB(170, 90, 255))
			end
		end
		table.clear(pendingSounds)

		local best, bestHops = nil, math.huge
		local heardHere = false
		for _, s in sounds do
			local hops = graph.dist[room][s.room]
			if rng:NextNumber() < Acoustics.hearChance(s.loudness, hops, hearScale) then
				-- From the same room, a hiding sound gives away the exact spot.
				table.insert(obs.noises, if hops == 0 and s.node then s.node else s.room)
				heardHere = heardHere or hops == 0
				if hops < bestHops or (hops == bestHops and best and s.loudness > best.loudness) then
					best, bestHops = s, hops
				end
				if showBelief and not s.decoy then
					house.ping(s.room, Color3.fromRGB(255, 210, 60))
				end
			end
		end
		if not heardHere and hunter.dwell > 0 then
			obs.quiet[room] = true -- stood here listening and heard nothing
		end

		obs.idle = not hunter.charge and not hunter.path and hunter.dwell <= 0
		obs.patrolSpeed = patrolSpeed
		local plansBefore = brain.plans or 0
		local target = brain.decide(obs)
		perf.decisions += 1
		perf.msSum += brain.lastMs
		if (brain.plans or 0) > plansBefore then
			perf.plans += 1
			perf.planMsSum += brain.planMs
			perf.planMsMax = math.max(perf.planMsMax, brain.planMs)
		end
		if hooks and hooks.onTick then
			hooks.onTick(sample)
		end

		if best and bestHops <= 1 then
			-- Reflex: rush at a sound in this room or the next one. A sound in this room is
			-- pinpointed; from next door it only knows the room.
			local pos = if bestHops == 0 and best.pos then best.pos else origin + HouseGraph.roomCenter(best.room)
			if (not hunter.charge or hunter.charge.room ~= best.room) and hunter.route and hunter.route.kind == "door" then
				hunter.route = nil -- the old route led toward a different room (a flight of stairs is finished first)
			end
			hunter.charge = {
				room = best.room,
				pos = Vector3.new(pos.X, origin.Y + HouseGraph.floorY(best.room), pos.Z),
				untilTime = os.clock() + CHARGE_MEMORY,
				hideNode = if bestHops == 0 then best.node else nil, -- heard WHICH spot: open it next
			}
			hunter.dwell = 0
			hunter.path = nil
		elseif not hunter.charge and not hunter.path and hunter.dwell <= 0 then
			hunter.path = suspiciousSpot(room) or target
		end

		drawBelief()
		pushState()
	end

	-- Search reflex: the hiding spot in this room it is most sure someone hides in, if it is sure
	-- enough. Uses the per-player beliefs (the rule brain has none, so it never does this).
	suspiciousSpot = function(room: number): number?
		return HunterBrain.suspiciousSpot(brain, graph, room)
	end

	local function flat(target: Vector3): Vector3
		return Vector3.new(target.X - hunter.pos.X, 0, target.Z - hunter.pos.Z)
	end

	-- Walk toward a world point. Between rooms the hunter follows a route: its own room's centre, then the
	-- doorway (or up/down the staircase) into the next room. A route is kept until it is finished, so the
	-- hunter never cuts through a wall, and the flight of stairs it is on is never abandoned halfway.
	local function stepToward(goalRoom: number, goalPos: Vector3, speed: number, dt: number): boolean
		local room = currentRoom()
		if not hunter.route and room ~= goalRoom then
			local hop = HouseGraph.nextStep(graph, room, goalRoom)
			local pts = {}
			local centre = origin + HouseGraph.roomCenter(room)
			if flat(centre).Magnitude > 1.5 then
				table.insert(pts, centre)
			end
			local kind = "door"
			for _, p in HouseGraph.route(graph, room, hop, hunter.pos - origin) do
				table.insert(pts, origin + p)
				if math.abs(p.Y - graph.rooms[room].floorY) > 0.5 then
					kind = "stairs"
				end
			end
			hunter.route = { pts = pts, i = 1, kind = kind }
		end

		local target = goalPos
		local route = hunter.route
		if route then
			while route.i <= #route.pts and (route.pts[route.i] - hunter.pos).Magnitude < 0.6 do
				route.i += 1
			end
			if route.i > #route.pts then
				hunter.route = nil
				route = nil
			else
				target = route.pts[route.i]
			end
		end
		if not route and room == goalRoom and flat(goalPos).Magnitude < 0.6 then
			return true
		end
		local delta = target - hunter.pos
		local ground = flat(target)
		if ground.Magnitude > 1e-3 then
			hunter.facing = ground.Unit
		end
		if delta.Magnitude > 1e-3 then
			hunter.pos += delta.Unit * math.min(speed * dt, delta.Magnitude)
		end
		hunter.node = currentRoom()
		return false
	end

	local function touchCheck()
		for _, player in Players:GetPlayers() do
			local root = getRoot(player)
			if root and not isDowned(player) and not (hooks and hooks.isHidden and hooks.isHidden(player)) then
				local d = root.Position - hunter.pos
				if Vector3.new(d.X, 0, d.Z).Magnitude <= CATCH_RADIUS and math.abs(d.Y) < 8 then
					catchPlayer(player)
				end
			end
		end
	end

	local function move(dt: number)
		if hunter.dwell > 0 then
			hunter.dwell -= dt
			if hunter.dwell <= 0 and hunter.dwellIsSearch then
				-- Spot opened: whoever hides inside is caught; otherwise the brain learns it is empty.
				hunter.checked[hunter.node] = true
				if hooks and hooks.searchSpot then
					for _, player in hooks.searchSpot(hunter.node) do
						catchPlayer(player)
					end
				end
				for _, player in Players:GetPlayers() do
					local root = getRoot(player)
					if root and HouseGraph.nodeAt(graph, root.Position - origin, CLOSET_RADIUS) == hunter.node then
						catchPlayer(player)
					end
				end
			end
		elseif hunter.charge then
			hunter.mode = "charge"
			local arrived = stepToward(hunter.charge.room, hunter.charge.pos, chargeSpeed, dt)
			if arrived or os.clock() > hunter.charge.untilTime then
				local spot = hunter.charge.hideNode
				hunter.charge = nil
				if spot then
					hunter.path = spot -- it heard which spot: rip it open
				else
					hunter.dwell = LISTEN_SECONDS
					hunter.dwellIsSearch = false
				end
			end
		elseif hunter.path then
			hunter.mode = "search"
			local node = graph.nodes[hunter.path]
			local arrived = stepToward(node.room, origin + node.pos, patrolSpeed, dt)
			if arrived then
				hunter.node = hunter.path
				hunter.path = nil
				hunter.dwellIsSearch = node.kind == "hide"
				hunter.dwell = if hunter.dwellIsSearch then SEARCH_SECONDS else LISTEN_SECONDS
			end
		end
		if hunter.dwell > 0 then
			hunter.mode = if hunter.dwellIsSearch then "search-closet" else "listen"
		end
		touchCheck()

		local moving = hunter.dwell <= 0 and (hunter.charge ~= nil or hunter.path ~= nil)
		if moving and not stepsSound.IsPlaying then
			stepsSound:Play()
		elseif not moving and stepsSound.IsPlaying then
			stepsSound:Stop()
		end
		stepsSound.PlaybackSpeed = if hunter.charge then 1.35 else 0.9
		if hunter.charge and not hunter.growled and os.clock() - lastGrowl > 6 then
			hunter.growled = true
			lastGrowl = os.clock()
			growlSound:Play()
		elseif not hunter.charge then
			hunter.growled = false
		end

		model:PivotTo(CFrame.lookAt(hunter.pos, hunter.pos + hunter.facing))
	end

	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		if not active then
			return
		end
		move(dt)
		acc += dt
		if acc >= TICK then
			acc -= TICK
			listen()
		end
	end)

	-- Debug decoy (G). The real decoy becomes a shop item in M3.
	decoyRemote.OnServerEvent:Connect(function(player)
		local now = os.clock()
		if not active or isDowned(player) or now - (lastDecoy[player] or -math.huge) < DECOY_COOLDOWN then
			return
		end
		local root = getRoot(player)
		local room = root and HouseGraph.roomAt(root.Position - origin)
		if not room then
			return
		end
		lastDecoy[player] = now
		local options = {}
		for _, v in graph.neighbors[room] do
			if graph.nodes[v].kind == "room" then
				table.insert(options, v)
			end
		end
		table.insert(pendingSounds, { room = options[rng:NextInteger(1, #options)], loudness = Acoustics.LOUDNESS.decoy, decoy = true })
	end)

	-- Studio debug (M): rule → belief → pomcp → pomcp+model (if a model is loaded) → rule
	modeRemote.OnServerEvent:Connect(function()
		if not RunService:IsStudio() then
			return
		end
		if brainKind == "rule" then
			brainKind, useModel = "belief", false
		elseif brainKind == "belief" then
			brainKind, useModel = "pomcp", false
		elseif brainKind == "pomcp" and not useModel and opponentModel then
			useModel = true
		else
			brainKind, useModel = "rule", false
		end
		brain = makeBrain(nil) -- switched mid-game: no prior knowledge
		pushState()
	end)

	beliefRemote.OnServerEvent:Connect(function()
		showBelief = not showBelief
		drawBelief()
		pushState()
	end)

	Players.PlayerRemoving:Connect(function(player)
		lastDecoy[player] = nil
	end)

	local handle = { state = state }

	function handle.setActive(on: boolean)
		active = on
		if not on then
			placeAtStart()
		end
		drawBelief()
		pushState()
	end

	-- Fresh night: everyone starts in the spawn room and the hunter knows it.
	function handle.newNight()
		brain = makeBrain(SPAWN_ROOM)
		perf = { decisions = 0, msSum = 0, plans = 0, planMsSum = 0, planMsMax = 0 }
		placeAtStart()
		pushState()
	end

	-- kind: "rule" | "belief" | "pomcp". Takes effect at the next newNight().
	function handle.setBrain(kind: string, withModel: boolean?)
		brainKind = kind
		useModel = withModel == true
		pushState()
	end

	function handle.setModel(model)
		opponentModel = model
		pushState()
	end

	function handle.stats()
		return {
			brain = brainLabel(),
			modelVersion = if useModel and opponentModel then opponentModel.version else nil,
			decisions = perf.decisions,
			avgDecisionMs = if perf.decisions > 0 then perf.msSum / perf.decisions else 0,
			plans = perf.plans,
			avgPlanMs = if perf.plans > 0 then perf.planMsSum / perf.plans else 0,
			maxPlanMs = perf.planMsMax,
		}
	end

	function handle.setSpeeds(patrol: number, charge: number)
		patrolSpeed, chargeSpeed = patrol, charge
	end

	-- 1 = hears exactly as the Acoustics model says; lower on early nights.
	function handle.setHearing(scale: number)
		hearScale = scale
	end

	function handle.setLair(room: number)
		lair = room
		house.setLair(room)
		placeAtStart()
		pushState()
	end

	-- A sound made by the game (crate, revive, flashlight click...). kind = key in Acoustics.LOUDNESS.
	-- `node` (optional): the hiding spot the sound came from (heard from the same room, the
	-- hunter knows exactly which spot).
	function handle.emitSound(room: number, position: Vector3?, kind: string, node: number?)
		table.insert(pendingSounds, { room = room, pos = position, loudness = Acoustics.LOUDNESS[kind] or 0.5, node = node })
	end

	function handle.hunterRoom(): number
		return currentRoom()
	end

	function handle.isActive(): boolean
		return active
	end

	-- How sure the hunter is that `player` is in spot `node` (0..1): its real belief. 1 while it
	-- is opening that very spot.
	function handle.suspicionAt(player: Player, node: number): number
		if hunter.dwell > 0 and hunter.dwellIsSearch and hunter.node == node then
			return 1
		end
		if hunter.path == node or (hunter.charge and hunter.charge.hideNode == node) then
			return 0.9
		end
		local filter = brain.filters and brain.filters[tostring(player.UserId)]
		if not filter then
			return 0
		end
		local hits = 0
		for _, p in filter.particles do
			if p == node then
				hits += 1
			end
		end
		return hits / filter.n
	end

	function handle.playerRevived(player: Player, node: number)
		brain.reset(tostring(player.UserId), node)
	end

	function handle.hunterPosition(): Vector3
		return hunter.pos
	end

	pushState()
	return handle
end

return HunterService
