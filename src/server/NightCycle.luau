--!nonstrict
-- The run: title screen → up to 7 nights → escape.
--   Waiting  nobody has pressed PLAY yet (title screen)
--   Day      prepare and shop; the hunter sleeps in its lair (visible); objectives appear
--   Night    the hunter hunts; complete tonight's objective; caught players go down until revived
--   Report   result of the night, then the next Day (or back to night 1, or the title after escaping)
-- Objectives by night: supplies (collect crates), power (fix fuse boxes), escape (night 7:
-- find the key, then leave through the front door).
-- Lose a night = time runs out or everyone is down → back to night 1.
-- Which hunter brain hunts each night comes from Config (story: smarter every night;
-- experiment: one random condition per run, for the playtest). Every night is recorded by
-- Telemetry and sent to the backend, which fits the OpponentModel from real players.
-- All state is published as Attributes on Workspace.NightHunterState for the HUD.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("NightHunter")
local HouseGraph = require(Shared:WaitForChild("HouseGraph"))
local Items = require(Shared:WaitForChild("Items"))
local OpponentModel = require(Shared:WaitForChild("OpponentModel"))
local DefaultModel = require(Shared:WaitForChild("DefaultModel"))
local Config = require(script.Parent.Config)
local Telemetry = require(script.Parent.Telemetry)
local HouseDecor = require(script.Parent.HouseDecor)
local HunterService = require(script.Parent.HunterService)
local PlayerKit = require(script.Parent.PlayerKit)
local Economy = require(script.Parent.Economy)
local Progress = require(script.Parent.Progress)

local DAY_SECONDS = 30
local NIGHT_SECONDS = 180
local REPORT_SECONDS = 8
local LAST_NIGHT = 7
local REVIVE_SECONDS = 3
local WAKE_SECONDS = 8 -- the hunter stays asleep for the first seconds of the night

local SCHEDULE = { "supplies", "supplies", "power", "supplies", "power", "supplies", "escape" }

-- Difficulty per night for the blind hunter in the 16-room house, tuned with Sim
-- (2 crate-collecting bots, 120 nights each): belief-hunter win rate ~97% on night 1 ->
-- ~63% on night 7. Players: crouch 6, walk 12, sprint 20 studs/s. See docs/playable-v1.md.
local PATROL_SPEED = { 10, 11, 12, 13, 14, 15, 16 }
local CHARGE_SPEED = { 15, 16, 17, 18, 19, 19, 20 }
local HEARING = { 0.75, 0.8, 0.85, 0.9, 0.95, 1.0, 1.0 }

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
	local result = ""
	local downsThisNight = 0
	local lair = HouseGraph.DEFAULT_LAIR
	local wakeAt = 0

	local stateFolder = Workspace:FindFirstChild("NightHunterState") or Instance.new("Folder")
	stateFolder.Name = "NightHunterState"
	stateFolder.Parent = Workspace
	local telemetry = Telemetry.start(stateFolder)
	local hunter = HunterService.start(house, {
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
		if telemetry.isConfigured() then
			local remote = OpponentModel.fromParams(telemetry.fetchModelParams())
			if remote then
				hunter.setModel(remote)
				print(("[NightHunter] Opponent model %s loaded from the backend (%d steps)"):format(remote.version, remote.samples))
			end
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
	local frontDoor = house.root:FindFirstChild("FrontDoor", true)

	local function objectiveText(): string
		if objective == "supplies" then
			return ("Collect supply crates  %d / %d"):format(progress, goal)
		elseif objective == "power" then
			return ("Fix the fuse boxes  %d / %d"):format(progress, goal)
		elseif keyTaken then
			return "You have the key: escape through the FRONT DOOR (Foyer)"
		end
		return "Find the key somewhere in the house"
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

	local function spawnCrates(count: number)
		for _ = 1, count do
			local room = randomRoom(1)
			local offset = Vector3.new(rng:NextNumber(-4, 4), 1, rng:NextNumber(-4, 4)) -- clear of the furniture along the walls
			local crate = Instance.new("Part")
			crate.Name = "Crate"
			crate.Anchored = true
			crate.Size = Vector3.new(2, 2, 2)
			crate.Position = origin + HouseGraph.roomCenter(room) + offset
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

	-- A fuse box on a wall without a door, in `count` different rooms.
	local function freeWalls(room: number)
		local cols = HouseGraph.COLS
		local sides = {
			{ dir = Vector3.new(0, 0, -1), neighbour = room - cols, inside = (room - 1) // cols > 0 },
			{ dir = Vector3.new(0, 0, 1), neighbour = room + cols, inside = (room - 1) // cols < HouseGraph.ROWS - 1 },
			{ dir = Vector3.new(-1, 0, 0), neighbour = room - 1, inside = (room - 1) % cols > 0 },
			{ dir = Vector3.new(1, 0, 0), neighbour = room + 1, inside = (room - 1) % cols < cols - 1 },
		}
		local options = {}
		for _, side in sides do
			if not (side.inside and HouseGraph.hasDoor(graph, room, side.neighbour)) then
				table.insert(options, side) -- an outer wall, or an inner wall without a door
			end
		end
		return options
	end

	local function spawnFuses(count: number)
		-- Rooms with a door in every wall have nowhere to put a fuse box.
		local candidates = {}
		for room = 1, graph.roomCount do
			if room ~= HouseGraph.SPAWN_ROOM and #freeWalls(room) > 0 then
				table.insert(candidates, room)
			end
		end
		local rooms = {}
		while #rooms < count and #candidates > 0 do
			table.insert(rooms, table.remove(candidates, rng:NextInteger(1, #candidates)))
		end
		goal = #rooms
		for _, room in rooms do
			local options = freeWalls(room)
			local side = options[rng:NextInteger(1, #options)]
			local wallPoint = origin + HouseGraph.roomCenter(room) + side.dir * 11.15 + Vector3.new(0, 3.6, 0)
			local box = Instance.new("Part")
			box.Name = "FuseBox"
			box.Anchored = true
			box.Size = Vector3.new(1.8, 2.4, 0.6)
			box.CFrame = CFrame.lookAt(wallPoint, wallPoint - side.dir) -- face into the room
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
			glow.Range = 6
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

	local doorPrompt: ProximityPrompt? = nil

	local function spawnKey()
		local room = randomRoom(3)
		local key = Instance.new("Part")
		key.Name = "Key"
		key.Anchored = true
		key.CanCollide = false
		key.Size = Vector3.new(0.35, 0.15, 1.2)
		key.Position = origin + HouseGraph.roomCenter(room) + Vector3.new(rng:NextNumber(-3, 3), 0.2, rng:NextNumber(-3, 3))
		key.Color = Color3.fromRGB(255, 200, 80)
		key.Material = Enum.Material.Neon
		local glow = Instance.new("PointLight")
		glow.Color = key.Color
		glow.Range = 7
		glow.Brightness = 1.2
		glow.Parent = key
		local p = prompt(key, "Take key", "Old brass key", 1)
		p.Triggered:Connect(function(by: Player)
			if phase ~= "Night" or downed[by] or keyTaken then
				return
			end
			keyTaken = true
			key:Destroy()
			by:SetAttribute("HasKey", true)
			if doorPrompt then
				doorPrompt.Enabled = true
			end
			advance(by, Items.REWARD.key, room, key.Position)
		end)
		key.Parent = objectiveFolder

		if frontDoor and not doorPrompt then
			doorPrompt = prompt(frontDoor, "Escape", "Front door", 1.5)
			doorPrompt.MaxActivationDistance = 9
			doorPrompt.Enabled = false
			doorPrompt.Triggered:Connect(function(by: Player)
				if phase == "Night" and not downed[by] and by:GetAttribute("HasKey") then
					telemetry.event("escape", by)
					progress = goal
					pushState()
					endNight("Win")
				end
			end)
		end
	end

	local function clearObjectives()
		objectiveFolder:ClearAllChildren()
		if doorPrompt then
			doorPrompt:Destroy()
			doorPrompt = nil
		end
		keyTaken = false
		for _, player in Players:GetPlayers() do
			player:SetAttribute("HasKey", false)
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
			goal = 2 -- take the key, open the door
			spawnKey()
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
		phase = "Day"
		phaseEndsAt = Workspace:GetServerTimeNow() + DAY_SECONDS
		result = ""
		downsThisNight = 0
		wakeAt = 0
		for player in downed do
			revive(player)
		end
		hunter.setActive(false)
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
		phase = "Waiting"
		phaseEndsAt = 0
		for player in downed do
			revive(player)
		end
		hunter.setActive(false)
		clearObjectives()
		sendEveryoneToSpawn()
		pushState()
	end

	local function beginNight()
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
			if wakeAt > 0 and now >= wakeAt then
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

	-- Studio only (for testing): set DebugJumpToNight = n on NightHunterState to start that
	-- night's day, or change DebugSkipPhase to end the current Day / Report right away.
	if RunService:IsStudio() then
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
		if player:GetAttribute("HasKey") and phase == "Night" then
			-- The key leaves with them: put a new one in the house.
			keyTaken = false
			progress = 0
			spawnKey()
			pushState()
		end
	end)

	pushState()
end

return NightCycle
