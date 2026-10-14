--!nonstrict
-- The run: title screen → up to 7 nights → escape.
--   Waiting  nobody has pressed PLAY yet (title screen)
--   Day      prepare and shop; the hunter sleeps in its lair (visible); objectives appear
--   Night    the hunter hunts; complete tonight's objective; caught players go down until revived
--   Report   result of the night, then the next Day (or back to night 1, or the title after escaping)
-- Objectives by night: supplies (collect crates), power (fix fuse boxes), escape (night 7:
-- find the relics hidden in the mansion, place them on the altar by the hall pillar, take the key
-- the pillar gives up, and leave through the front door).
-- Lose a night = time runs out or everyone is down → back to night 1.
-- Which hunter brain hunts each night comes from Config (story: smarter every night;
-- experiment: one random condition per run, for the playtest). Every night is recorded by
-- Telemetry and sent to the backend, which fits the OpponentModel from real players.
-- All state is published as Attributes on Workspace.NightHunterState for the HUD.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("NightHunter")
local HouseGraph = require(Shared:WaitForChild("HouseGraph"))
local Items = require(Shared:WaitForChild("Items"))
local OpponentModel = require(Shared:WaitForChild("OpponentModel"))
local DefaultModel = require(Shared:WaitForChild("DefaultModel"))
local Config = require(script.Parent.Config)
local Telemetry = require(script.Parent.Telemetry)
local HouseDecor = require(script.Parent.HouseDecor)
local HouseGeometry = require(script.Parent.HouseGeometry)
local HunterService = require(script.Parent.HunterService)
local PlayerKit = require(script.Parent.PlayerKit)
local Economy = require(script.Parent.Economy)
local Progress = require(script.Parent.Progress)
local HideService = require(script.Parent.HideService)

local DAY_SECONDS = 30
local NIGHT_SECONDS = 180
local REPORT_SECONDS = 8
local LAST_NIGHT = 7
local REVIVE_SECONDS = 3
local WAKE_SECONDS = 8 -- the hunter stays asleep for the first seconds of the night

local SCHEDULE = { "supplies", "supplies", "power", "supplies", "power", "supplies", "escape" }
local RELICS = { "Music Box", "Silver Locket", "Porcelain Doll", "Old Photograph" } -- the relics of night 7

-- Difficulty per night for the blind hunter in the 16-room house, tuned with Sim
-- (2 crate-collecting bots, 120 nights each): belief-hunter win rate ~97% on night 1 ->
-- ~63% on night 7. Players: crouch 6, walk 12, sprint 20 studs/s. See docs/playable-v1.md.
local PATROL_SPEED = { 10, 11, 12, 13, 14, 15, 16 }
local CHARGE_SPEED = { 15, 16, 17, 18, 19, 19, 20 }
local HEARING = { 0.75, 0.8, 0.85, 0.9, 0.95, 1.0, 1.0 }

-- The house is lit a little by day (to plan and shop), and nearly dark at night.
local MOODS = {
	day = { Ambient = Color3.fromRGB(40, 42, 58), OutdoorAmbient = Color3.fromRGB(36, 39, 56), Brightness = 0.2 },
	night = { Ambient = Color3.fromRGB(8, 8, 13), OutdoorAmbient = Color3.fromRGB(7, 8, 13), Brightness = 0.03 },
}
local function setMood(name: string, seconds: number)
	if seconds <= 0 then
		for k, v in MOODS[name] do
			Lighting[k] = v
		end
	else
		TweenService:Create(Lighting, TweenInfo.new(seconds), MOODS[name]):Play()
	end
end

local NightCycle = {}

local function prompt(parent: Instance, action: string, object: string, hold: number): ProximityPrompt
	local p = Instance.new("ProximityPrompt")
	p.ActionText = action
	p.ObjectText = object
	p.HoldDuration = hold
	p.MaxActivationDistance = 8
	p.RequiresLineOfSight = false
	p.Parent = parent
	return p
end

function NightCycle.start(house)
	local graph = house.graph
	local origin = house.origin
	local rng = Random.new()
	local downed = {} -- [Player] = ProximityPrompt
	local endNight -- forward declaration

	local phase = "Waiting"
	local night = 1
	local phaseEndsAt = 0
	local objective = "supplies"
	local progress, goal = 0, 0
	local keyTaken = false
	local stage = "relics" -- night 7: "relics" (find them, place them) -> "key" (take it) -> "door" (escape)
	local relicsPlaced = 0
	local result = ""
	local downsThisNight = 0
	local lair = HouseGraph.DEFAULT_LAIR
	local wakeAt = 0

	local stateFolder = Workspace:FindFirstChild("NightHunterState") or Instance.new("Folder")
	stateFolder.Name = "NightHunterState"
	stateFolder.Parent = Workspace
	local telemetry = Telemetry.start(stateFolder)
	local hide = nil -- HideService, started below (the hunter needs it to search spots)
	local hunter = HunterService.start(house, {
		isHidden = function(player)
			return hide ~= nil and hide.isHidden(player)
		end,
		searchSpot = function(node)
			return if hide then hide.search(node) else {}
		end,
		isDowned = function(player)
			return downed[player] ~= nil
		end,
		onCaught = function(player)
			NightCycle._down(player)
		end,
		onTick = function(sample)
			telemetry.onTick(sample)
		end,
	})
	local state = hunter.state

	-- The opponent model: the one shipped with the game, replaced by the backend's latest fit
	-- from real players when a backend is configured.
	hunter.setModel(OpponentModel.fromParams(DefaultModel))
	task.spawn(function()
		-- A free Render server sleeps when idle and needs up to a minute to wake: retry a few times.
		for _ = 1, 3 do
			if not telemetry.isConfigured() then
				return
			end
			local remote = OpponentModel.fromParams(telemetry.fetchModelParams())
			if remote then
				hunter.setModel(remote)
				print(("[NightHunter] Opponent model %s loaded from the backend (%d steps)"):format(remote.version, remote.samples))
				return
			end
			task.wait(40)
		end
	end)

	local function hunterMode(): string
		local mode = ServerStorage:GetAttribute("HunterMode")
		return if mode == "experiment" or mode == "story" then mode else Config.hunterMode
	end
	local runCondition = nil -- experiment mode: { label, brain, model } for the whole run
	local condition = "" -- label of tonight's hunter, e.g. "pomcp+model"

	local kit = PlayerKit.start({
		onClick = function(player)
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			local room = root and HouseGraph.roomAt(root.Position - origin)
			if room then
				hunter.emitSound(room, root.Position, "click")
			end
		end,
	})

	local econ = Economy.start({
		house = house,
		hunter = hunter,
		onItemUsed = function(player, itemId)
			telemetry.event("item", player, { item = itemId })
		end,
		phase = function()
			return phase
		end,
		isDowned = function(player)
			return downed[player] ~= nil
		end,
	})
	Progress.start()
	hide = HideService.start({
		house = house,
		hunter = hunter,
		kit = kit,
		telemetry = telemetry,
		phase = function()
			return phase
		end,
		isDowned = function(player)
			return downed[player] ~= nil
		end,
	})

	local readyRemote = Instance.new("RemoteEvent")
	readyRemote.Name = "Ready"
	readyRemote.Parent = ReplicatedStorage:WaitForChild("NightHunterRemotes")

	-- Tonight's lair: any room at least 2 rooms from the spawn, never the same room twice in a row.
	local lairOptions = {}
	for room = 1, graph.roomCount do
		if graph.dist[HouseGraph.SPAWN_ROOM][room] >= 2 then
			table.insert(lairOptions, room)
		end
	end
	local function pickLair()
		local choice
		repeat
			choice = lairOptions[rng:NextInteger(1, #lairOptions)]
		until choice ~= lair or #lairOptions == 1
		return choice
	end

	local objectiveFolder = Instance.new("Folder")
	objectiveFolder.Name = "Objectives"
	objectiveFolder.Parent = house.root
	local frontDoor = house.root:FindFirstChild("FrontDoor", true) -- a Model; its PrimaryPart is the slab
	local frontDoorHome = if frontDoor then frontDoor:GetPivot() else nil
	local pillar = house.root:FindFirstChild("Pillar", true)

	local function objectiveText(): string
		if objective == "supplies" then
			return ("Collect supply crates  %d / %d"):format(progress, goal)
		elseif objective == "power" then
			return ("Fix the fuse boxes  %d / %d"):format(progress, goal)
		elseif stage == "door" then
			return "You have the key: open the FRONT DOOR in the hall and escape"
		elseif stage == "key" then
			return "The pillar is open: take the key from the altar in the hall"
		end
		return ("Find the relics in the mansion and place them on the altar in the hall  %d / %d"):format(relicsPlaced, #RELICS)
	end

	local function pushState()
		state:SetAttribute("Phase", phase)
		state:SetAttribute("Night", night)
		state:SetAttribute("LastNight", LAST_NIGHT)
		state:SetAttribute("PhaseEndsAt", phaseEndsAt)
		state:SetAttribute("Objective", objective)
		state:SetAttribute("Progress", progress)
		state:SetAttribute("Goal", goal)
		state:SetAttribute("ObjectiveText", objectiveText())
		state:SetAttribute("Result", result)
		state:SetAttribute("DownsThisNight", downsThisNight)
		state:SetAttribute("LairRoom", HouseDecor.THEMES[lair].name)
		state:SetAttribute("WakeAt", wakeAt)
	end

	---------------------------------------------------------------- downs and revives

	local function revive(player: Player)
		local p = downed[player]
		if not p then
			return
		end
		downed[player] = nil
		p:Destroy()
			player:SetAttribute("Downed", false) -- PlayerKit restores movement
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		local node = root and HouseGraph.nodeAt(graph, root.Position - origin, 2.6)
		telemetry.event("revive", player, { node = node or 0 })
		if node then
			hunter.playerRevived(player, node) -- it knows where its victim fell
			hunter.emitSound(graph.nodes[node].room, root.Position, "revive")
		end
		pushState()
	end

	function NightCycle._down(player: Player)
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if downed[player] or phase ~= "Night" or not root then
			return
		end
		if hide then
			hide.release(player) -- normally already pulled out by the search that found them
		end
		downsThisNight += 1
		telemetry.event("down", player, { node = HouseGraph.nodeAt(graph, root.Position - origin, 2.6) or 0 })
		player:SetAttribute("Downed", true) -- PlayerKit freezes movement and switches the light off
		local p = prompt(root, "Revive", player.DisplayName, REVIVE_SECONDS)
		p.Triggered:Connect(function(by: Player)
			if by ~= player and not downed[by] then
				revive(player)
			end
		end)
		downed[player] = p
		pushState()
	end

	---------------------------------------------------------------- objectives

	local function advance(player: Player, coins: number, room: number, position: Vector3)
		progress += 1
		econ.addCoins(player, coins)
		hunter.emitSound(room, position, "crate") -- every objective is loud work
		telemetry.event("objective", player, { progress = progress, room = room })
		pushState()
		if progress >= goal then
			endNight("Win")
		end
	end

	local function randomRoom(minDistFromSpawn: number): number
		local options = {}
		for room = 1, graph.roomCount do
			if graph.dist[HouseGraph.SPAWN_ROOM][room] >= minDistFromSpawn then
				table.insert(options, room)
			end
		end
		return options[rng:NextInteger(1, #options)]
	end

	-- A spot on the floor of `room` clear of its stairwell: a world position at floor height + lift.
	local function floorPoint(room: number, lift: number): Vector3
		local r = graph.rooms[room]
		local spread = if #r.holes > 0 then 4 else 12
		return origin + Vector3.new(r.center.X + rng:NextNumber(-spread, spread), r.floorY + lift, r.center.Z + rng:NextNumber(-spread, spread))
	end

	local function spawnCrates(count: number)
		for _ = 1, count do
			local room = randomRoom(1)
			local crate = Instance.new("Part")
			crate.Name = "Crate"
			crate.Anchored = true
			crate.Size = Vector3.new(2, 2, 2)
			crate.Position = floorPoint(room, 1)
			crate.Color = Color3.fromRGB(170, 125, 60)
			crate.Material = Enum.Material.WoodPlanks
			local p = prompt(crate, "Collect", "Supply crate", 0.6)
			p.Triggered:Connect(function(by: Player)
				if phase ~= "Night" or downed[by] or not crate.Parent then
					return
				end
				crate:Destroy()
				advance(by, Items.REWARD.crate, room, crate.Position)
			end)
			crate.Parent = objectiveFolder
		end
	end

	-- Somewhere on a doorless wall of `room` that a player can actually stand in front of: off the middle
	-- of the wall (outer walls have a window there) and not above a stairwell. Returns the wall and the
	-- house-local position, or nil if the room has no such place.
	local function fuseSpot(room: number)
		local r = graph.rooms[room]
		local options = HouseGeometry.freeWalls(house.segments, room)
		for _ = 1, 20 do
			local wall = options[rng:NextInteger(1, math.max(1, #options))]
			if not wall then
				return nil
			end
			local mid = (wall.lo + wall.hi) / 2
			local along = if rng:NextNumber() < 0.5 then rng:NextNumber(wall.lo + 3, mid - 4) else rng:NextNumber(mid + 4, wall.hi - 3)
			local face = wall.line + (if wall.axisX then wall.normal.Z else wall.normal.X) * 0.8
			local localPos = if wall.axisX then Vector3.new(along, wall.floorY + 3.6, face) else Vector3.new(face, wall.floorY + 3.6, along)
			local standX = localPos.X + wall.normal.X * 2
			local standZ = localPos.Z + wall.normal.Z * 2
			local reachable = true
			for _, hole in r.holes do
				if standX > hole.x0 - 1 and standX < hole.x1 + 1 and standZ > hole.z0 - 1 and standZ < hole.z1 + 1 then
					reachable = false
				end
			end
			if reachable then
				return wall, localPos
			end
		end
		return nil
	end

	-- A fuse box on a wall without a door, in `count` different rooms.
	local function spawnFuses(count: number)
		local candidates = {}
		for room = 1, graph.roomCount do
			if room ~= HouseGraph.SPAWN_ROOM then
				local wall, localPos = fuseSpot(room)
				if wall then
					table.insert(candidates, { room = room, wall = wall, localPos = localPos })
				end
			end
		end
		local chosen = {}
		while #chosen < count and #candidates > 0 do
			table.insert(chosen, table.remove(candidates, rng:NextInteger(1, #candidates)))
		end
		goal = #chosen
		for _, spot in chosen do
			local room, wall, localPos = spot.room, spot.wall, spot.localPos
			local wallPoint = origin + localPos
			local box = Instance.new("Part")
			box.Name = "FuseBox"
			box.Anchored = true
			box.Size = Vector3.new(1.8, 2.4, 0.6)
			box.CFrame = CFrame.lookAt(wallPoint, wallPoint + wall.normal) -- face into the room
			box.Color = Color3.fromRGB(70, 74, 80)
			box.Material = Enum.Material.DiamondPlate
			local lamp = Instance.new("Part")
			lamp.Name = "Lamp"
			lamp.Anchored = true
			lamp.CanCollide = false
			lamp.Size = Vector3.new(0.3, 0.3, 0.2)
			lamp.CFrame = box.CFrame * CFrame.new(0, 0.8, -0.35)
			lamp.Color = Color3.fromRGB(255, 40, 40)
			lamp.Material = Enum.Material.Neon
			lamp.Parent = box
			local glow = Instance.new("PointLight")
			glow.Color = lamp.Color
			glow.Range = 8
			glow.Brightness = 1
			glow.Parent = lamp
			local fixed = false
			local p = prompt(box, "Fix fuse", "Fuse box", 2.5)
			p.Triggered:Connect(function(by: Player)
				if phase ~= "Night" or downed[by] or fixed then
					return
				end
				fixed = true
				p.Enabled = false
				lamp.Color = Color3.fromRGB(60, 255, 120)
				glow.Color = lamp.Color
				advance(by, Items.REWARD.fuse, room, box.Position)
			end)
			box.Parent = objectiveFolder
		end
	end

	---------------------------------------------------------------- the finale (night 7)
	-- Relics are hidden around the mansion; carried to the altar by the hall pillar they fill its four
	-- sockets, the pillar gives up the key, and the key opens the front door.

	local doorPrompt: ProximityPrompt? = nil
	local altarPrompt: ProximityPrompt? = nil

	local function setSocket(index: number, filled: boolean)
		local socket = pillar and pillar:FindFirstChild("Socket" .. index)
		if socket then
			socket.Color = if filled then Color3.fromRGB(90, 255, 210) else Color3.fromRGB(32, 34, 40)
			socket.Material = if filled then Enum.Material.Neon else Enum.Material.Metal
		end
	end

	local function altarLight(brightness: number)
		local l = pillar and pillar:FindFirstChild("AltarLight", true)
		if l then
			l.Brightness = brightness
		end
	end

	-- The door swings outward on its left hinge (seen from inside).
	local function openFrontDoor()
		if not frontDoor then
			return
		end
		local hinge = frontDoorHome * CFrame.new(-frontDoor.PrimaryPart.Size.X / 2, 0, 0)
		local fromHinge = hinge:ToObjectSpace(frontDoorHome)
		local swing = Instance.new("NumberValue")
		swing.Changed:Connect(function(angle)
			frontDoor:PivotTo(hinge * CFrame.Angles(0, math.rad(-angle), 0) * fromHinge)
		end)
		local tween = TweenService:Create(swing, TweenInfo.new(1.6, Enum.EasingStyle.Quad), { Value = 100 })
		tween.Completed:Once(function()
			swing:Destroy()
		end)
		tween:Play()
	end

	-- The door only offers "Escape" once someone holds the key (created then, not just enabled).
	local function showDoorPrompt()
		local anchor = frontDoor and frontDoor:FindFirstChild("DoorPrompt")
		if not anchor or doorPrompt then
			return
		end
		doorPrompt = prompt(anchor, "Escape", "Front door", 1.5)
		doorPrompt.MaxActivationDistance = 12
		doorPrompt.Triggered:Connect(function(by: Player)
			if phase == "Night" and not downed[by] and by:GetAttribute("HasKey") then
				telemetry.event("escape", by)
				progress = goal
				pushState()
				openFrontDoor()
				task.delay(1.8, function()
					endNight("Win")
				end)
			end
		end)
	end

	local function hideDoorPrompt()
		if doorPrompt then
			doorPrompt:Destroy()
			doorPrompt = nil
		end
	end

	local function spawnKeyOnAltar()
		local pos = origin + HouseDecor.ALTAR_POS + Vector3.new(0, 3.2, 0)
		local key = Instance.new("Part")
		key.Name = "Key"
		key.Anchored = true
		key.CanCollide = false
		key.Size = Vector3.new(0.35, 0.15, 1.2)
		key.CFrame = CFrame.new(pos) * CFrame.Angles(0, math.rad(35), 0)
		key.Color = Color3.fromRGB(255, 200, 80)
		key.Material = Enum.Material.Neon
		local glow = Instance.new("PointLight")
		glow.Color = key.Color
		glow.Range = 10
		glow.Brightness = 1.2
		glow.Parent = key
		local p = prompt(key, "Take key", "Old brass key", 1)
		p.Triggered:Connect(function(by: Player)
			if phase ~= "Night" or downed[by] or keyTaken then
				return
			end
			keyTaken = true
			stage = "door"
			key:Destroy()
			by:SetAttribute("HasKey", true)
			showDoorPrompt()
			advance(by, Items.REWARD.key, HouseGraph.SPAWN_ROOM, key.Position)
		end)
		key.Parent = objectiveFolder
	end

	local function spawnRelics(count: number)
		-- distinct rooms, away from the hall
		local candidates = {}
		for room = 1, graph.roomCount do
			if graph.dist[HouseGraph.SPAWN_ROOM][room] >= 2 then
				table.insert(candidates, room)
			end
		end
		local colors = { Color3.fromRGB(255, 170, 90), Color3.fromRGB(190, 210, 255), Color3.fromRGB(255, 200, 220), Color3.fromRGB(210, 190, 140) }
		for _ = 1, count do
			if #candidates == 0 then
				break
			end
			local room = table.remove(candidates, rng:NextInteger(1, #candidates))
			local index = rng:NextInteger(1, #RELICS)
			local relic = Instance.new("Part")
			relic.Name = "Relic"
			relic.Anchored = true
			relic.CanCollide = false
			relic.Size = Vector3.new(1.1, 1.1, 1.1)
			relic.Position = floorPoint(room, 1.4)
			relic.Color = colors[index]
			relic.Material = Enum.Material.Neon
			local glow = Instance.new("PointLight")
			glow.Color = relic.Color
			glow.Range = 9
			glow.Brightness = 0.8
			glow.Parent = relic
			local p = prompt(relic, "Take", RELICS[index], 0.8)
			p.Triggered:Connect(function(by: Player)
				if phase ~= "Night" or downed[by] or not relic.Parent then
					return
				end
				relic:Destroy()
				by:SetAttribute("Relics", (by:GetAttribute("Relics") or 0) + 1)
			end)
			relic.Parent = objectiveFolder
		end
	end

	local function setupFinale()
		stage, relicsPlaced = "relics", 0
		for i = 1, HouseDecor.SOCKETS do
			setSocket(i, false)
		end
		altarLight(0.35)
		spawnRelics(#RELICS)

		local anchor = pillar and pillar:FindFirstChild("AltarPrompt")
		if anchor and not altarPrompt then
			altarPrompt = prompt(anchor, "Place relics", "Altar", 1)
			altarPrompt.MaxActivationDistance = 10
			altarPrompt.Triggered:Connect(function(by: Player)
				local carried = by:GetAttribute("Relics") or 0
				if phase ~= "Night" or downed[by] or stage ~= "relics" or carried <= 0 then
					return
				end
				local count = math.min(carried, #RELICS - relicsPlaced)
				by:SetAttribute("Relics", carried - count)
				for _ = 1, count do
					relicsPlaced += 1
					setSocket(relicsPlaced, true)
					advance(by, Items.REWARD.relic, HouseGraph.SPAWN_ROOM, anchor.Position)
				end
				altarLight(0.35 + relicsPlaced * 0.35)
				if relicsPlaced >= #RELICS then
					stage = "key"
					altarPrompt.Enabled = false -- the key sits in the same spot: do not show two prompts
					spawnKeyOnAltar()
					pushState()
				end
			end)
		end
	end

	local function clearObjectives()
		objectiveFolder:ClearAllChildren()
		hideDoorPrompt()
		if altarPrompt then
			altarPrompt:Destroy()
			altarPrompt = nil
		end
		if frontDoor and frontDoorHome then
			frontDoor:PivotTo(frontDoorHome) -- shut again
		end
		for i = 1, HouseDecor.SOCKETS do
			setSocket(i, false)
		end
		altarLight(0.35)
		keyTaken = false
		stage, relicsPlaced = "relics", 0
		for _, player in Players:GetPlayers() do
			player:SetAttribute("HasKey", false)
			player:SetAttribute("Relics", 0)
		end
	end

	local function prepareObjective()
		clearObjectives()
		objective = SCHEDULE[math.min(night, #SCHEDULE)]
		progress = 0
		if objective == "supplies" then
			goal = math.min(2 + night, 9)
			spawnCrates(goal + 2) -- a couple of spares, so one crate in a bad room is skippable
		elseif objective == "power" then
			goal = if night <= 3 then 3 else 4
			spawnFuses(goal)
		else
			goal = #RELICS + 2 -- every relic on the altar, the key, the door
			setupFinale()
		end
	end

	---------------------------------------------------------------- phases

	local function sendEveryoneToSpawn()
		for index, player in Players:GetPlayers() do
			local character = player.Character
			if character then
				local offset = Vector3.new(((index - 1) % 3 - 1) * 2.5, 4, 0)
				character:PivotTo(CFrame.new(house.spawn.Position + offset))
			end
		end
	end

	local function beginDay()
		setMood("day", 2)
		phase = "Day"
		phaseEndsAt = Workspace:GetServerTimeNow() + DAY_SECONDS
		result = ""
		downsThisNight = 0
		wakeAt = 0
		for player in downed do
			revive(player)
		end
		hunter.setActive(false)
		if hide then
			hide.releaseAll()
		end
		kit.recharge()
		lair = pickLair()
		hunter.setLair(lair) -- asleep in its nest all day: players can see where it will wake
		prepareObjective()
		sendEveryoneToSpawn()
		pushState()
	end

	local function startRun()
		night = 1
		econ.resetRun()
		telemetry.beginRun()
		runCondition = nil
		if hunterMode() == "experiment" then
			runCondition = Config.CONDITIONS[rng:NextInteger(1, #Config.CONDITIONS)]
		end
		beginDay()
	end

	-- Tonight's brain: from the story schedule, or the run's experiment condition.
	local function chooseBrain()
		local kind, withModel
		if runCondition then
			kind, withModel = runCondition.brain, runCondition.model
		else
			local entry = Config.BRAIN_BY_NIGHT[math.min(night, #Config.BRAIN_BY_NIGHT)]
			kind, withModel = entry[1], entry[2]
		end
		hunter.setBrain(kind, withModel)
		condition = kind .. (if withModel and kind ~= "rule" then "+model" else "")
		state:SetAttribute("Condition", condition)
	end

	local function toTitle()
		setMood("day", 2)
		phase = "Waiting"
		phaseEndsAt = 0
		for player in downed do
			revive(player)
		end
		hunter.setActive(false)
		if hide then
			hide.releaseAll()
		end
		clearObjectives()
		sendEveryoneToSpawn()
		pushState()
	end

	local function beginNight()
		setMood("night", 4)
		phase = "Night"
		phaseEndsAt = Workspace:GetServerTimeNow() + NIGHT_SECONDS
		wakeAt = Workspace:GetServerTimeNow() + WAKE_SECONDS
		local n = math.min(night, #PATROL_SPEED)
		hunter.setSpeeds(PATROL_SPEED[n], CHARGE_SPEED[n])
		hunter.setHearing(HEARING[n])
		chooseBrain()
		hunter.newNight()
		telemetry.beginNight({
			night = night,
			objective = objective,
			goal = goal,
			condition = condition,
			hunterMode = if runCondition then "experiment" else "story",
		})
		pushState()
	end

	function endNight(outcome: string)
		if phase ~= "Night" then
			return
		end
		phase = "Report"
		phaseEndsAt = Workspace:GetServerTimeNow() + REPORT_SECONDS
		wakeAt = 0
		result = if outcome == "Win" and night >= LAST_NIGHT then "Complete" else outcome
		hunter.setActive(false)
		if outcome == "Win" then
			for _, player in Players:GetPlayers() do
				econ.addCoins(player, Items.REWARD.nightSurvived)
			end
		end
		if result ~= "Win" then
			Progress.recordRun(night, result == "Complete") -- the run is over
		end
		telemetry.endNight({
			outcome = result,
			progress = progress,
			downs = downsThisNight,
			hunter = hunter.stats(),
		})
		pushState()
	end

	RunService.Heartbeat:Connect(function()
		if #Players:GetPlayers() == 0 then
			if phase ~= "Waiting" then
				toTitle()
			end
			return
		end
		local now = Workspace:GetServerTimeNow()
		if phase == "Day" and now >= phaseEndsAt then
			beginNight()
		elseif phase == "Night" then
			if state:GetAttribute("Peace") == true then
				-- Peace mode (editing / testing): the hunter stays asleep and the night never runs out.
				wakeAt = 0
				phaseEndsAt = math.max(phaseEndsAt, now + 30)
			elseif wakeAt > 0 and now >= wakeAt then
				wakeAt = 0
				hunter.setActive(true)
				pushState()
			end
			if now >= phaseEndsAt then
				endNight("Fail")
				return
			end
			local standing, present = 0, 0
			for _, player in Players:GetPlayers() do
				if player.Character then
					present += 1
					if not downed[player] then
						standing += 1
					end
				end
			end
			if present > 0 and standing == 0 then
				endNight("Fail")
			end
		elseif phase == "Report" and now >= phaseEndsAt then
			if result == "Win" then
				night += 1
				beginDay()
			elseif result == "Complete" then
				toTitle()
			else
				startRun() -- the hunter won: straight back to night 1
			end
		end
	end)

	readyRemote.OnServerEvent:Connect(function()
		if phase == "Waiting" then
			startRun()
		end
	end)

	-- PEACE MODE: no hunter, no scary music, the night never ends. For building and testing the map.
	-- On for a whole session: set the ServerStorage attribute PeaceMode = true (in Edit mode, it is saved
	-- in the place; remember to turn it off before publishing). Toggle while playing in Studio: press P.
	-- (Only honoured in Studio: a live server can never start in peace mode by accident.)
	state:SetAttribute("Peace", RunService:IsStudio() and ServerStorage:GetAttribute("PeaceMode") == true)
	state:GetAttributeChangedSignal("Peace"):Connect(function()
		if state:GetAttribute("Peace") == true then
			hunter.setActive(false)
		elseif phase == "Night" then
			wakeAt = Workspace:GetServerTimeNow() + 4 -- it wakes up again, with a short warning
		end
		pushState()
	end)
	if RunService:IsStudio() then
		local peaceRemote = Instance.new("RemoteEvent")
		peaceRemote.Name = "TogglePeace"
		peaceRemote.Parent = ReplicatedStorage:WaitForChild("NightHunterRemotes")
		peaceRemote.OnServerEvent:Connect(function()
			state:SetAttribute("Peace", state:GetAttribute("Peace") ~= true)
		end)
	end

	-- Studio only (for testing): set DebugJumpToNight = n on NightHunterState to start that
	-- night's day, or change DebugSkipPhase to end the current Day / Report right away.
	if RunService:IsStudio() then
		-- DebugHideSlam = node: the hunter hears someone slam into that hiding spot.
		state:GetAttributeChangedSignal("DebugHideSlam"):Connect(function()
			local node = state:GetAttribute("DebugHideSlam")
			if type(node) == "number" and graph.nodes[node] and graph.nodes[node].kind == "hide" then
				hunter.emitSound(graph.nodes[node].room, origin + graph.nodes[node].pos, "hideSlam", node)
			end
		end)
		-- DebugDumpTelemetry: copy the newest queued night record (JSON) to DebugTelemetryJson.
		state:GetAttributeChangedSignal("DebugDumpTelemetry"):Connect(function()
			local last = telemetry.queue[#telemetry.queue]
			state:SetAttribute("DebugTelemetryJson", if last then game:GetService("HttpService"):JSONEncode(last) else "")
		end)
		state:GetAttributeChangedSignal("DebugSkipPhase"):Connect(function()
			if phase == "Day" or phase == "Report" then
				phaseEndsAt = Workspace:GetServerTimeNow()
			end
		end)
		state:GetAttributeChangedSignal("DebugJumpToNight"):Connect(function()
			local n = state:GetAttribute("DebugJumpToNight")
			if type(n) == "number" and n >= 1 and n <= LAST_NIGHT then
				night = n
				hunter.setActive(false)
				beginDay()
			end
		end)
	end

	local function onPlayer(player: Player)
		player:SetAttribute("Downed", false)
		player:SetAttribute("HasKey", false)
		player:SetAttribute("Relics", 0)
		player.CharacterAdded:Connect(function()
			if downed[player] then
				downed[player] = nil -- a fresh character is never down
				player:SetAttribute("Downed", false)
				pushState()
			end
		end)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		local p = downed[player]
		downed[player] = nil
		if p then
			p:Destroy()
		end
		if objective == "escape" and phase == "Night" then
			local carried = player:GetAttribute("Relics") or 0
			if carried > 0 then
				spawnRelics(carried) -- the relics they carried go back into the house
			end
			if player:GetAttribute("HasKey") and stage == "door" then
				-- The key leaves with them: it is back on the altar.
				keyTaken = false
				stage = "key"
				progress = #RELICS
				hideDoorPrompt()
				spawnKeyOnAltar()
			end
			pushState()
		end
	end)

	setMood("day", 0)
	pushState()
end

return NightCycle
