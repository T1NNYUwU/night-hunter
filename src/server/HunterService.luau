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
-- hooks.isDowned(player) -> bool   downed players make no sound and cannot be caught again
-- hooks.onCaught(player)

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

	local brain = HunterBrain.new("belief", graph, Random.new(), SPAWN_ROOM)
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
		hunter.waypoint = nil
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
		state:SetAttribute("Mode", brain.kind)
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

	local function listen()
		local room = currentRoom()
		local obs = { hunterNode = hunter.node, players = {}, noises = {}, quiet = {}, checked = hunter.checked }
		hunter.checked = {}

		local sounds = {}
		for _, player in Players:GetPlayers() do
			local root = getRoot(player)
			local node = root and not isDowned(player) and HouseGraph.nodeAt(graph, root.Position - origin, CLOSET_RADIUS)
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
				table.insert(obs.noises, s.room)
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

		local target = brain.decide(obs)

		if best and bestHops <= 1 then
			-- Reflex: rush at a sound in this room or the next one. A sound in this room is
			-- pinpointed; from next door it only knows the room.
			local pos = if bestHops == 0 and best.pos then best.pos else origin + HouseGraph.roomCenter(best.room)
			if not hunter.charge or hunter.charge.room ~= best.room then
				hunter.waypoint = nil -- the old waypoint led toward a different room
			end
			hunter.charge = { room = best.room, pos = Vector3.new(pos.X, origin.Y, pos.Z), untilTime = os.clock() + CHARGE_MEMORY }
			hunter.dwell = 0
			hunter.path = nil
		elseif not hunter.charge and not hunter.path and hunter.dwell <= 0 then
			hunter.path = target
			hunter.waypoint = nil
		end

		drawBelief()
		pushState()
	end

	local function flat(target: Vector3): Vector3
		return Vector3.new(target.X - hunter.pos.X, 0, target.Z - hunter.pos.Z)
	end

	-- Walk toward a world point, always through room centres so it never cuts through walls.
	-- A waypoint (own room centre, then the next room's centre) is kept until it is reached;
	-- re-deciding every frame made it jitter at the edge of the "near the centre" radius.
	local function stepToward(goalRoom: number, goalPos: Vector3, speed: number, dt: number): boolean
		local room = currentRoom()
		local target
		if room == goalRoom then
			hunter.waypoint = nil
			target = goalPos
		else
			if hunter.waypoint and flat(hunter.waypoint).Magnitude < 0.6 then
				hunter.waypoint = nil
			end
			if not hunter.waypoint then
				local centre = origin + HouseGraph.roomCenter(room)
				hunter.waypoint = if flat(centre).Magnitude > 1.5
					then centre
					else origin + HouseGraph.roomCenter(HouseGraph.nextStep(graph, room, goalRoom))
			end
			target = hunter.waypoint
		end
		local delta = flat(target)
		if room == goalRoom and delta.Magnitude < 0.6 then
			return true
		end
		if delta.Magnitude > 1e-3 then
			hunter.facing = delta.Unit
			hunter.pos += delta.Unit * math.min(speed * dt, delta.Magnitude)
		end
		hunter.node = currentRoom()
		return false
	end

	local function touchCheck()
		for _, player in Players:GetPlayers() do
			local root = getRoot(player)
			if root and not isDowned(player) then
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
				-- Closet opened: whoever hides inside is caught; otherwise the brain learns it is empty.
				hunter.checked[hunter.node] = true
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
				hunter.charge = nil
				hunter.dwell = LISTEN_SECONDS
				hunter.dwellIsSearch = false
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

	modeRemote.OnServerEvent:Connect(function()
		local kind = if brain.kind == "belief" then "rule" else "belief"
		brain = HunterBrain.new(kind, graph, Random.new(), nil) -- switched mid-game: no prior knowledge
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
		brain = HunterBrain.new(brain.kind, graph, Random.new(), SPAWN_ROOM)
		placeAtStart()
		pushState()
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
	function handle.emitSound(room: number, position: Vector3?, kind: string)
		table.insert(pendingSounds, { room = room, pos = position, loudness = Acoustics.LOUDNESS[kind] or 0.5 })
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
