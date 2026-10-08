--!nonstrict
-- One run = up to 7 nights. Each night:
--   Day    (prepare, hunter asleep in room 9, crates appear)
--   Night  (hunter hunts; collect the crate quota; caught players go down until a teammate revives them)
--   Report (result of the night, then the next Day)
-- Win the night = reach the crate quota. Lose = time runs out or everyone is down → back to night 1.
-- All state is published as Attributes on Workspace.NightHunterState for the HUD.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local HouseGraph = require(ReplicatedStorage:WaitForChild("NightHunter"):WaitForChild("HouseGraph"))
local HouseDecor = require(script.Parent.HouseDecor)
local HunterService = require(script.Parent.HunterService)
local PlayerKit = require(script.Parent.PlayerKit)

local DAY_SECONDS = 20
local NIGHT_SECONDS = 180
local REPORT_SECONDS = 8
local LAST_NIGHT = 7
local REVIVE_SECONDS = 3
local WAKE_SECONDS = 8 -- the hunter stays asleep for the first seconds of the night

-- Difficulty per night for the blind hunter in the 16-room house, tuned with Sim
-- (2 crate-collecting bots, 120 nights each): belief-hunter win rate ~97% on night 1 ->
-- ~63% on night 7. Players: crouch 6, walk 12, sprint 20 studs/s. See docs/playable-v1.md.
local PATROL_SPEED = { 10, 11, 12, 13, 14, 15, 16 }
local CHARGE_SPEED = { 15, 16, 17, 18, 19, 19, 20 }
local HEARING = { 0.75, 0.8, 0.85, 0.9, 0.95, 1.0, 1.0 }

local NightCycle = {}

function NightCycle.start(house)
	local graph = house.graph
	local rng = Random.new()
	local downed = {} -- [Player] = ProximityPrompt
	local endNight -- forward declaration

	local hunter = HunterService.start(house, {
		isDowned = function(player)
			return downed[player] ~= nil
		end,
		onCaught = function(player)
			NightCycle._down(player)
		end,
	})
	local state = hunter.state

	local kit = PlayerKit.start({
		onClick = function(player)
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			local room = root and HouseGraph.roomAt(root.Position - house.origin)
			if room then
				hunter.emitSound(room, root.Position, "click")
			end
		end,
	})

	local phase = "Waiting"
	local night = 1
	local phaseEndsAt = 0
	local crates, needed = 0, 0
	local result = ""
	local downsThisNight = 0
	local lair = HouseGraph.DEFAULT_LAIR
	local wakeAt = 0

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

	local crateFolder = Instance.new("Folder")
	crateFolder.Name = "Crates"
	crateFolder.Parent = house.root

	local function pushState()
		state:SetAttribute("Phase", phase)
		state:SetAttribute("Night", night)
		state:SetAttribute("LastNight", LAST_NIGHT)
		state:SetAttribute("PhaseEndsAt", phaseEndsAt)
		state:SetAttribute("Crates", crates)
		state:SetAttribute("CratesNeeded", needed)
		state:SetAttribute("Result", result)
		state:SetAttribute("DownsThisNight", downsThisNight)
		state:SetAttribute("LairRoom", HouseDecor.THEMES[lair].name)
		state:SetAttribute("WakeAt", wakeAt)
	end

	local function revive(player: Player)
		local prompt = downed[player]
		if not prompt then
			return
		end
		downed[player] = nil
		prompt:Destroy()
		player:SetAttribute("Downed", false) -- PlayerKit restores movement
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		local node = root and HouseGraph.nodeAt(graph, root.Position - house.origin, 2.6)
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
		player:SetAttribute("Downed", true) -- PlayerKit freezes movement and switches the light off
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Revive"
		prompt.ObjectText = player.DisplayName
		prompt.HoldDuration = REVIVE_SECONDS
		prompt.MaxActivationDistance = 8
		prompt.RequiresLineOfSight = false
		prompt.Triggered:Connect(function(by: Player)
			if by ~= player and not downed[by] then
				revive(player)
			end
		end)
		prompt.Parent = root
		downed[player] = prompt
		pushState()
	end

	local function spawnCrates(count: number)
		crateFolder:ClearAllChildren()
		for _ = 1, count do
			local room = rng:NextInteger(2, graph.roomCount) -- never in the spawn room
			local offset = Vector3.new(rng:NextNumber(-4, 4), 1, rng:NextNumber(-4, 4)) -- clear of the furniture along the walls
			local crate = Instance.new("Part")
			crate.Name = "Crate"
			crate.Anchored = true
			crate.Size = Vector3.new(2, 2, 2)
			crate.Position = house.origin + HouseGraph.roomCenter(room) + offset
			crate.Color = Color3.fromRGB(170, 125, 60)
			crate.Material = Enum.Material.WoodPlanks
			local prompt = Instance.new("ProximityPrompt")
			prompt.ActionText = "Collect"
			prompt.ObjectText = "Supply crate"
			prompt.HoldDuration = 0.6
			prompt.MaxActivationDistance = 8
			prompt.Triggered:Connect(function(by: Player)
				if phase ~= "Night" or downed[by] or not crate.Parent then
					return
				end
				crate:Destroy()
				crates += 1
				hunter.emitSound(room, crate.Position, "crate") -- prying a crate open is loud
				pushState()
				if crates >= needed then
					endNight("Win")
				end
			end)
			prompt.Parent = crate
			crate.Parent = crateFolder
		end
	end

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
		for player in downed do
			revive(player)
		end
		hunter.setActive(false)
		kit.recharge()
		lair = pickLair()
		hunter.setLair(lair) -- asleep in its nest all day: players can see where it will wake
		needed = math.min(2 + night, 9)
		crates = 0
		spawnCrates(needed + 2) -- a couple of spares, so one crate in a bad room is skippable
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
		hunter.newNight()
		pushState()
	end

	function endNight(outcome: string)
		if phase ~= "Night" then
			return
		end
		phase = "Report"
		phaseEndsAt = Workspace:GetServerTimeNow() + REPORT_SECONDS
		result = if outcome == "Win" and night >= LAST_NIGHT then "Complete" else outcome
		hunter.setActive(false)
		pushState()
	end

	RunService.Heartbeat:Connect(function()
		if #Players:GetPlayers() == 0 then
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
			night = if result == "Win" then night + 1 else 1
			beginDay()
		end
	end)

	local function onPlayer(player: Player)
		player:SetAttribute("Downed", false)
		player.CharacterAdded:Connect(function()
			if downed[player] then
				downed[player] = nil -- a fresh character is never down
				player:SetAttribute("Downed", false)
				pushState()
			end
		end)
		if phase == "Waiting" then
			night = 1
			beginDay()
		end
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		local prompt = downed[player]
		downed[player] = nil
		if prompt then
			prompt:Destroy()
		end
	end)

	pushState()
end

return NightCycle
