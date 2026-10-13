--!nonstrict
-- Everything a survivor carries and how they move, decided on the server:
--   stance   walk / sprint (stamina) / crouch → WalkSpeed. The client only asks for a stance.
--   flashlight  a Tool with a SpotLight; toggled by clicking it or pressing F; drains a battery.
--               It is StarterPack.Flashlight (made in Studio: a Handle with a SpotLight, no scripts), so the
--               team can change how it looks; the engine hands one to every spawn. A place without one
--               gets a plain built one (buildFlashlight).
-- How LOUD a player is is not decided here: HunterService measures real movement speed.
--
-- Attributes on each Player (read by the HUD):
--   Stance ("walk"|"sprint"|"crouch"), Stamina (0..1), Flashlight (bool), Battery (0..1), Downed (bool)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Workspace = game:GetService("Workspace")

local Acoustics = require(ReplicatedStorage:WaitForChild("NightHunter"):WaitForChild("Acoustics"))
local Items = require(ReplicatedStorage:WaitForChild("NightHunter"):WaitForChild("Items"))

local SPRINT_SECONDS = 5 -- full stamina bar
local STAMINA_REGEN = 0.15 -- bars per second while not sprinting (~7 s to refill)
local BATTERY_SECONDS = 150 -- a full battery lasts this long switched on
local JUMP_HEIGHT = 4
local STANCES = { walk = true, sprint = true, crouch = true }

local PlayerKit = {}

local function humanoidOf(player: Player): Humanoid?
	return player.Character and player.Character:FindFirstChildOfClass("Humanoid")
end

local function buildFlashlight(): Tool
	local tool = Instance.new("Tool")
	tool.Name = "Flashlight"
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool.ToolTip = "Click or F: on / off"
	-- Hold it pointing forward, a little to the side, like a torch.
	tool.Grip = CFrame.new(0, -0.1, 0.5) * CFrame.Angles(0, 0, 0)

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.35, 0.35, 1.4)
	handle.Color = Color3.fromRGB(30, 30, 34)
	handle.Material = Enum.Material.Metal
	handle.CanCollide = false
	handle.Massless = true
	handle.Parent = tool

	local lens = Instance.new("Part")
	lens.Name = "Lens"
	lens.Shape = Enum.PartType.Cylinder
	lens.Size = Vector3.new(0.1, 0.42, 0.42)
	lens.Color = Color3.fromRGB(255, 240, 200)
	lens.Material = Enum.Material.Neon
	lens.CanCollide = false
	lens.Massless = true
	lens.CFrame = handle.CFrame * CFrame.new(0, 0, -0.72) * CFrame.Angles(0, math.pi / 2, 0)
	lens.Parent = tool
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = handle
	weld.Part1 = lens
	weld.Parent = lens

	local beam = Instance.new("SpotLight")
	beam.Name = "Beam"
	beam.Face = Enum.NormalId.Front
	beam.Angle = 50
	beam.Range = 40
	beam.Brightness = 3
	beam.Color = Color3.fromRGB(255, 244, 220)
	beam.Shadows = true
	beam.Enabled = false
	beam.Parent = handle
	return tool
end

function PlayerKit.start(hooks)
	local remotes = ReplicatedStorage:FindFirstChild("NightHunterRemotes") or Instance.new("Folder")
	remotes.Name = "NightHunterRemotes"
	local stanceRemote = Instance.new("RemoteEvent")
	stanceRemote.Name = "SetStance"
	stanceRemote.Parent = remotes
	local lightRemote = Instance.new("RemoteEvent")
	lightRemote.Name = "ToggleFlashlight"
	lightRemote.Parent = remotes
	remotes.Parent = ReplicatedStorage

	local wanted = {} -- [Player] = stance the client asked for
	local lastToggle = {}

	local function flashlightOf(player: Player): Tool?
		local character = player.Character
		return (character and character:FindFirstChild("Flashlight")) or player.Backpack:FindFirstChild("Flashlight")
	end

	local function setLight(player: Player, on: boolean)
		local tool = flashlightOf(player)
		if on and (player:GetAttribute("Battery") or 0) <= 0 then
			on = false
		end
		player:SetAttribute("Flashlight", on)
		if tool then
			local handle = tool:FindFirstChild("Handle")
			if handle then
				for _, light in handle:GetChildren() do
					if light:IsA("SpotLight") then
						light.Enabled = on -- the narrow core and the dim halo
					end
				end
				local click = handle:FindFirstChild("Click")
				if click then
					click:Play()
				end
			end
			local lens = tool:FindFirstChild("Lens")
			if lens then
				lens.Material = if on then Enum.Material.Neon else Enum.Material.Glass
			end
		end
	end

	local function toggleLight(player: Player)
		local now = os.clock()
		if now - (lastToggle[player] or 0) < 0.25 or player:GetAttribute("Downed") or (player:GetAttribute("Hidden") or 0) ~= 0 then
			return
		end
		lastToggle[player] = now
		setLight(player, not player:GetAttribute("Flashlight"))
		if hooks and hooks.onClick then
			hooks.onClick(player) -- the switch makes a tiny click
		end
	end

	local function equip(player: Player, character: Model)
		local humanoid = character:WaitForChild("Humanoid")
		humanoid.JumpHeight = JUMP_HEIGHT
		humanoid.WalkSpeed = Acoustics.SPEED.walk
		-- The engine clones StarterPack tools into the Backpack on every spawn.
		local tool = player.Backpack:WaitForChild("Flashlight", 3)
		if not tool then
			tool = buildFlashlight()
			tool.Parent = player.Backpack
		end
		for _, extra in player.Backpack:GetChildren() do
			if extra:IsA("Tool") and extra ~= tool then
				extra:Destroy() -- one item: the flashlight (other kits left in StarterPack would add scripts)
			end
		end
		tool.Activated:Connect(function()
			toggleLight(player)
		end)
		humanoid:EquipTool(tool)
		-- The hand and the torch sit right at the light: if they cast shadows they black out the beam.
		for _, d in character:GetDescendants() do
			if d:IsA("BasePart") then
				d.CastShadow = false
			end
		end
		character.DescendantAdded:Connect(function(d)
			if d:IsA("BasePart") then
				d.CastShadow = false
			end
		end)
		setLight(player, false)
	end

	local function onPlayer(player: Player)
		player:SetAttribute("Stance", "walk")
		player:SetAttribute("Stamina", 1)
		player:SetAttribute("Battery", 1)
		player:SetAttribute("Flashlight", false)
		wanted[player] = "walk"
		player.CharacterAdded:Connect(function(character)
			equip(player, character)
		end)
		if player.Character then
			equip(player, player.Character)
		end
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayer, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		wanted[player] = nil
		lastToggle[player] = nil
	end)

	stanceRemote.OnServerEvent:Connect(function(player, stance)
		if type(stance) == "string" and STANCES[stance] then
			wanted[player] = stance
		end
	end)
	lightRemote.OnServerEvent:Connect(toggleLight)

	RunService.Heartbeat:Connect(function(dt)
		for _, player in Players:GetPlayers() do
			local humanoid = humanoidOf(player)
			if humanoid then
				local stamina = player:GetAttribute("Stamina") or 1
				local stance = wanted[player] or "walk"
				local moving = humanoid.MoveDirection.Magnitude > 0.1
				local boosted = (player:GetAttribute("AdrenalineUntil") or 0) > Workspace:GetServerTimeNow()
				if stance == "sprint" and (stamina <= 0 and not boosted or not moving) then
					stance = "walk"
				end
				if stance == "sprint" and boosted then
					-- Adrenaline: faster, and the stamina bar does not drain
				elseif stance == "sprint" then
					stamina = math.max(0, stamina - dt / SPRINT_SECONDS)
				else
					stamina = math.min(1, stamina + dt * STAMINA_REGEN)
				end
				player:SetAttribute("Stamina", stamina)
				player:SetAttribute("Stance", stance)

				if player:GetAttribute("Downed") then
					humanoid.WalkSpeed = 0
					humanoid.JumpHeight = 0
					if player:GetAttribute("Flashlight") then
						setLight(player, false)
					end
				else
					humanoid.WalkSpeed = if stance == "sprint" and boosted then Items.ADRENALINE_SPEED else Acoustics.SPEED[stance]
					humanoid.JumpHeight = if stance == "crouch" then 0 else JUMP_HEIGHT
				end

				if player:GetAttribute("Flashlight") then
					local battery = math.max(0, (player:GetAttribute("Battery") or 0) - dt / BATTERY_SECONDS)
					player:SetAttribute("Battery", battery)
					if battery <= 0 then
						setLight(player, false)
					end
				end
			end
		end
	end)

	local kit = {}

	function kit.lightOff(player: Player)
		setLight(player, false)
	end

	-- New day: fresh batteries and full stamina for everyone.
	function kit.recharge()
		for _, player in Players:GetPlayers() do
			player:SetAttribute("Battery", 1)
			player:SetAttribute("Stamina", 1)
		end
	end

	return kit
end

return PlayerKit
