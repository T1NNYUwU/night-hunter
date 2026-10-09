-- Survivor client: first-person view, controls, HUD and the scary bits.
--   Shift (hold) sprint · C crouch on/off · F / click flashlight · E interact (prompts)
--   V shop (day) · Q Noise Maker · R Battery · X Adrenaline (night)
--   Mobile: on-screen RUN / SNEAK / LIGHT / SHOP / item buttons (ContextActionService touch buttons)
--   Studio only: G decoy · M switch brain · B show/hide the hunter's belief (debug)

local CollectionService = game:GetService("CollectionService")
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local SoundService = game:GetService("SoundService")

local player = Players.LocalPlayer
local Shared = ReplicatedStorage:WaitForChild("NightHunter")
local Sounds = require(Shared:WaitForChild("Sounds"))
local Items = require(Shared:WaitForChild("Items"))
local TitleScreen = require(script.Parent:WaitForChild("TitleScreen"))
local ShopPanel = require(script.Parent:WaitForChild("ShopPanel"))
local HideView = require(script.Parent:WaitForChild("HideView"))
local remotes = ReplicatedStorage:WaitForChild("NightHunterRemotes")
local state = Workspace:WaitForChild("NightHunterState")

player.CameraMode = Enum.CameraMode.LockFirstPerson
-- One item, switched with F / the LIGHT button: the default hotbar only covers our HUD.
pcall(function()
	game:GetService("StarterGui"):SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
end)

---------------------------------------------------------------- controls

local crouching = false
local sprintHeld = false

local function sendStance()
	local stance = if sprintHeld then "sprint" elseif crouching then "crouch" else "walk"
	remotes:WaitForChild("SetStance"):FireServer(stance)
end

ContextActionService:BindAction("NightHunterSprint", function(_, inputState)
	if inputState == Enum.UserInputState.Begin then
		sprintHeld = true
	elseif inputState == Enum.UserInputState.End or inputState == Enum.UserInputState.Cancel then
		sprintHeld = false
	end
	sendStance()
	return Enum.ContextActionResult.Sink
end, true, Enum.KeyCode.LeftShift, Enum.KeyCode.ButtonL3)

ContextActionService:BindAction("NightHunterCrouch", function(_, inputState)
	if inputState == Enum.UserInputState.Begin then
		crouching = not crouching
		sendStance()
	end
	return Enum.ContextActionResult.Sink
end, true, Enum.KeyCode.C, Enum.KeyCode.ButtonB)

ContextActionService:BindAction("NightHunterLight", function(_, inputState)
	if inputState == Enum.UserInputState.Begin then
		remotes:WaitForChild("ToggleFlashlight"):FireServer()
	end
	return Enum.ContextActionResult.Sink
end, true, Enum.KeyCode.F, Enum.KeyCode.ButtonY)

ContextActionService:SetTitle("NightHunterSprint", "RUN")
ContextActionService:SetTitle("NightHunterCrouch", "SNEAK")
ContextActionService:SetTitle("NightHunterLight", "LIGHT")
ContextActionService:SetPosition("NightHunterSprint", UDim2.new(1, -170, 1, -170))
ContextActionService:SetPosition("NightHunterCrouch", UDim2.new(1, -95, 1, -230))
ContextActionService:SetPosition("NightHunterLight", UDim2.new(1, -230, 1, -95))

-- Items: one key each, used at night. The server checks the phase, the count and a cooldown.
local ITEM_BUTTON_POS = {
	decoy = UDim2.new(1, -95, 1, -305),
	battery = UDim2.new(1, -170, 1, -305),
	adrenaline = UDim2.new(1, -245, 1, -305),
}
for _, id in Items.order do
	local actionName = "NightHunterItem_" .. id
	ContextActionService:BindAction(actionName, function(_, inputState)
		if inputState == Enum.UserInputState.Begin then
			remotes:WaitForChild("UseItem"):FireServer(id)
		end
		return Enum.ContextActionResult.Sink
	end, true, Enum.KeyCode[Items.list[id].key])
	ContextActionService:SetPosition(actionName, ITEM_BUTTON_POS[id])
end

if RunService:IsStudio() then
	for actionName, binding in { NightHunterDecoy = { Enum.KeyCode.G, "Decoy" }, NightHunterMode = { Enum.KeyCode.M, "ToggleMode" }, NightHunterBelief = { Enum.KeyCode.B, "ToggleBelief" } } do
		ContextActionService:BindAction(actionName, function(_, inputState)
			if inputState == Enum.UserInputState.Begin then
				remotes[binding[2]]:FireServer()
			end
			return Enum.ContextActionResult.Pass
		end, false, binding[1])
	end
end

---------------------------------------------------------------- HUD

local gui = Instance.new("ScreenGui")
gui.Name = "NightHunterHud"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = player:WaitForChild("PlayerGui")

local shop = ShopPanel.mount(gui, state, player, remotes)
local hideView = HideView.mount(gui, player, remotes)
local title = TitleScreen.mount(gui, state, player, function()
	remotes:WaitForChild("Ready"):FireServer()
end)

ContextActionService:BindAction("NightHunterShop", function(_, inputState)
	if inputState == Enum.UserInputState.Begin then
		shop.toggle()
	end
	return Enum.ContextActionResult.Sink
end, true, Enum.KeyCode.V, Enum.KeyCode.ButtonSelect)
ContextActionService:SetTitle("NightHunterShop", "SHOP")
ContextActionService:SetPosition("NightHunterShop", UDim2.new(1, -95, 1, -380))

local function label(props)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = props.bg or 1
	l.BackgroundColor3 = Color3.fromRGB(10, 10, 14)
	l.TextColor3 = props.color or Color3.new(1, 1, 1)
	l.Font = props.font or Enum.Font.GothamMedium
	l.TextSize = props.size or 15
	l.Size = props.frame
	l.Position = props.pos
	l.AnchorPoint = props.anchor or Vector2.zero
	l.TextXAlignment = props.alignX or Enum.TextXAlignment.Center
	l.TextYAlignment = props.alignY or Enum.TextYAlignment.Center
	l.TextWrapped = true
	l.TextStrokeTransparency = props.stroke or 1
	l.Text = ""
	l.Parent = props.parent or gui
	return l
end

local info = label({ bg = 0.35, frame = UDim2.fromOffset(280, 64), pos = UDim2.fromOffset(12, 48), alignX = Enum.TextXAlignment.Left, alignY = Enum.TextYAlignment.Top })
local padding = Instance.new("UIPadding")
padding.PaddingLeft = UDim.new(0, 10)
padding.PaddingTop = UDim.new(0, 8)
padding.Parent = info
local wallet = label({ bg = 0.35, frame = UDim2.fromOffset(280, 26), pos = UDim2.fromOffset(12, 116), size = 13, color = Color3.fromRGB(255, 220, 150), alignX = Enum.TextXAlignment.Left })
local walletPadding = Instance.new("UIPadding")
walletPadding.PaddingLeft = UDim.new(0, 10)
walletPadding.Parent = wallet
local debugInfo = label({ frame = UDim2.fromOffset(280, 20), pos = UDim2.fromOffset(12, 146), size = 12, color = Color3.fromRGB(160, 160, 170), alignX = Enum.TextXAlignment.Left })
debugInfo.Visible = RunService:IsStudio()

local banner = label({ frame = UDim2.fromOffset(560, 90), pos = UDim2.fromScale(0.5, 0.22), anchor = Vector2.new(0.5, 0.5), size = 32, font = Enum.Font.GothamBold, stroke = 0.4 })
local downNotice = label({ frame = UDim2.fromOffset(620, 70), pos = UDim2.fromScale(0.5, 0.62), anchor = Vector2.new(0.5, 0.5), size = 22, font = Enum.Font.GothamBold, color = Color3.fromRGB(255, 90, 90), stroke = 0.3 })

local function bar(name: string, y: number, color: Color3)
	local back = Instance.new("Frame")
	back.Name = name
	back.Size = UDim2.fromOffset(220, 8)
	back.Position = UDim2.new(0.5, 0, 1, y)
	back.AnchorPoint = Vector2.new(0.5, 1)
	back.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
	back.BackgroundTransparency = 0.3
	back.BorderSizePixel = 0
	back.Parent = gui
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = color
	fill.BorderSizePixel = 0
	fill.Parent = back
	local caption = label({ parent = back, frame = UDim2.fromOffset(220, 14), pos = UDim2.fromOffset(0, -16), size = 11, color = Color3.fromRGB(200, 200, 205), alignX = Enum.TextXAlignment.Left })
	return fill, caption
end
local staminaFill, staminaCaption = bar("Stamina", -46, Color3.fromRGB(120, 200, 255))
local batteryFill, batteryCaption = bar("Battery", -20, Color3.fromRGB(255, 220, 120))

-- Red edges that thicken as the hunter gets close (four gradient strips = a cheap vignette).
local vignette = {}
for _, side in { "Top", "Bottom", "Left", "Right" } do
	local f = Instance.new("Frame")
	f.BackgroundColor3 = Color3.fromRGB(120, 0, 0)
	f.BorderSizePixel = 0
	f.BackgroundTransparency = 1
	local horizontal = side == "Top" or side == "Bottom"
	f.Size = if horizontal then UDim2.new(1, 0, 0.22, 0) else UDim2.new(0.18, 0, 1, 0)
	f.Position = if side == "Bottom" then UDim2.fromScale(0, 0.78) elseif side == "Right" then UDim2.fromScale(0.82, 0) else UDim2.fromScale(0, 0)
	local g = Instance.new("UIGradient")
	g.Rotation = ({ Top = 90, Bottom = -90, Left = 0, Right = 180 })[side]
	g.Transparency = NumberSequence.new(0, 1)
	g.Parent = f
	f.Parent = gui
	table.insert(vignette, f)
end

local flash = Instance.new("Frame")
flash.Size = UDim2.fromScale(1, 1)
flash.BackgroundColor3 = Color3.fromRGB(150, 0, 0)
flash.BackgroundTransparency = 1
flash.BorderSizePixel = 0
flash.ZIndex = 10
flash.Parent = gui

---------------------------------------------------------------- flashlight beam (local)

-- The held tool's light points wherever the arm points, and the tool itself floats oddly in
-- first person. For your OWN view we hide the tool and draw a small flashlight in the lower
-- right of the screen (a viewmodel) whose beam follows the camera. Other players still see
-- the real tool and its light.
local VIEW_OFFSET = CFrame.new(0.85, -0.75, -1.5) * CFrame.Angles(math.rad(2), math.rad(4), 0)

local function viewPart(name, size, color, material, shape)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Size = size
	p.Color = color
	p.Material = material
	if shape then
		p.Shape = shape
	end
	return p
end

local viewmodel = Instance.new("Model")
viewmodel.Name = "FlashlightViewmodel"
-- Cylinders run along X; the body is turned so X points forward (-Z of the camera).
local vmBody = viewPart("Body", Vector3.new(1.1, 0.26, 0.26), Color3.fromRGB(28, 28, 32), Enum.Material.Metal, Enum.PartType.Cylinder)
local vmHead = viewPart("Head", Vector3.new(0.3, 0.36, 0.36), Color3.fromRGB(40, 40, 46), Enum.Material.Metal, Enum.PartType.Cylinder)
local vmLens = viewPart("Lens", Vector3.new(0.04, 0.3, 0.3), Color3.fromRGB(255, 240, 200), Enum.Material.Glass, Enum.PartType.Cylinder)
vmBody.Parent = viewmodel
vmHead.Parent = viewmodel
vmLens.Parent = viewmodel
viewmodel.Parent = Workspace.CurrentCamera -- parts under the camera render only for this player

-- Lights do not shine from parts parented to the camera, so the beam lives in Workspace.
-- It is created by this LocalScript, so it exists only on this client.
local beamPart = viewPart("LocalFlashlightBeam", Vector3.new(0.2, 0.2, 0.2), Color3.new(1, 1, 1), Enum.Material.SmoothPlastic)
beamPart.Transparency = 1
beamPart.Parent = Workspace
local localBeam = Instance.new("SpotLight")
localBeam.Face = Enum.NormalId.Front
localBeam.Angle = 55
localBeam.Range = 45
localBeam.Brightness = 4
localBeam.Color = Color3.fromRGB(255, 244, 220)
localBeam.Shadows = true
localBeam.Parent = beamPart
local glow = Instance.new("PointLight") -- a faint spill around you so walls next to you are not pitch black
glow.Range = 7
glow.Brightness = 0.35
glow.Color = localBeam.Color
glow.Shadows = false
glow.Parent = beamPart

---------------------------------------------------------------- sound (2D, this player only)

local function localSound(id: string, volume: number, looped: boolean): Sound
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = volume
	s.Looped = looped
	s.Parent = SoundService
	return s
end
local ambience = localSound(Sounds.ambience, 0, true)
local heartbeat = localSound(Sounds.heartbeat, 0, true)
local scare = localSound(Sounds.hunterGrowl, 2, false)
ambience:Play()
heartbeat:Play()

---------------------------------------------------------------- feedback loops

local shakeUntil = 0
local wasDown = false

player:GetAttributeChangedSignal("Downed"):Connect(function()
	local down = player:GetAttribute("Downed") == true
	if down and not wasDown then
		-- Jumpscare: red flash and a hard shake.
		flash.BackgroundTransparency = 0.05
		TweenService:Create(flash, TweenInfo.new(1.2), { BackgroundTransparency = 1 }):Play()
		shakeUntil = os.clock() + 0.8
		scare:Play()
	end
	wasDown = down
end)

-- The hunter's limbs are animated here, on each client (Roblox will not play animations
-- this game does not own, and posing joints locally costs the server nothing). Small angles
-- on the rig's Motor6D joints: legs and arms swing with its real speed, the body sways and
-- breathes, and the head twitches while it stands still listening.
local hunterAnim = { phase = 0, lastPos = nil, speed = 0, twitch = CFrame.new(), nextTwitch = 0 }

local function animateHunter(model: Model, dt: number)
	local root = model.PrimaryPart
	if not root then
		return
	end
	local pos = root.Position
	if hunterAnim.lastPos and dt > 0 then
		local v = (Vector3.new(pos.X, 0, pos.Z) - Vector3.new(hunterAnim.lastPos.X, 0, hunterAnim.lastPos.Z)).Magnitude / dt
		hunterAnim.speed += (v - hunterAnim.speed) * math.min(1, dt * 8)
	end
	hunterAnim.lastPos = pos
	local gait = math.clamp(hunterAnim.speed / 12, 0, 1.4)
	hunterAnim.phase += dt * (2 + hunterAnim.speed * 0.45)
	local s = math.sin(hunterAnim.phase)
	local breathe = math.sin(os.clock() * 1.6) * 0.04

	local mode = state:GetAttribute("HunterMode")
	if (mode == "listen" or mode == "search-closet") and os.clock() > hunterAnim.nextTwitch then
		hunterAnim.nextTwitch = os.clock() + math.random() * 0.5 + 0.15
		hunterAnim.twitch = CFrame.Angles(math.rad(math.random(-18, 18)), math.rad(math.random(-35, 35)), math.rad(math.random(-15, 15)))
	elseif mode ~= "listen" and mode ~= "search-closet" then
		hunterAnim.twitch = hunterAnim.twitch:Lerp(CFrame.new(), math.min(1, dt * 6))
	end

	for _, joint in model:GetDescendants() do
		if joint:IsA("Motor6D") then
			local name = joint.Name
			if name == "Torso" then
				joint.Transform = CFrame.new(0, -math.abs(s) * 0.25 * gait + breathe, 0) * CFrame.Angles(0, 0, s * 0.06 * gait)
			elseif name == "Head" then
				joint.Transform = hunterAnim.twitch
			elseif name == "Left Leg" then
				joint.Transform = CFrame.Angles(s * 0.45 * gait, 0, 0)
			elseif name == "Right Leg" then
				joint.Transform = CFrame.Angles(-s * 0.45 * gait, 0, 0)
			elseif name == "Left Forearm" then
				joint.Transform = CFrame.Angles(-s * 0.3 * gait + breathe, 0, 0)
			elseif name == "Right Forearm" then
				joint.Transform = CFrame.Angles(s * 0.3 * gait + breathe, 0, 0)
			end
		end
	end
end

local function hunterPart(): BasePart?
	local house = Workspace:FindFirstChild("NightHunterHouse")
	local model = house and house:FindFirstChild("Hunter")
	return model and model.PrimaryPart
end

-- Runs right after Roblox's camera script, so the shake and the beam use this frame's camera.
RunService:BindToRenderStep("NightHunterView", Enum.RenderPriority.Camera.Value + 1, function(dt)
	local camera = Workspace.CurrentCamera
	local houseFolder = Workspace:FindFirstChild("NightHunterHouse")
	local hunterModel = houseFolder and houseFolder:FindFirstChild("Hunter")
	if hunterModel then
		animateHunter(hunterModel, dt)
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local hiding = hideView.update(dt) -- hidden: the camera peeks out of the spot

	-- Crouch lowers the eyes.
	if humanoid and not hiding then
		local targetY = if crouching and not sprintHeld then -1.6 else 0
		local y = humanoid.CameraOffset.Y
		humanoid.CameraOffset = Vector3.new(0, y + (targetY - y) * 0.2, 0)
	end

	-- Viewmodel + local beam follow the camera; the real tool is hidden in our own view.
	local lightOn = player:GetAttribute("Flashlight") == true
	local tool = character and character:FindFirstChild("Flashlight")
	local holding = tool ~= nil and not player:GetAttribute("Downed") and not hiding
	local bob = if humanoid and humanoid.MoveDirection.Magnitude > 0.1 then math.sin(os.clock() * 9) * 0.03 else 0
	local hand = camera.CFrame * VIEW_OFFSET * CFrame.new(0, bob, 0)
	local forward = CFrame.Angles(0, math.rad(90), 0) -- cylinder X axis → camera forward
	vmBody.CFrame = hand * forward
	vmHead.CFrame = hand * CFrame.new(0, 0, -0.65) * forward
	vmLens.CFrame = hand * CFrame.new(0, 0, -0.82) * forward
	vmLens.Material = if lightOn then Enum.Material.Neon else Enum.Material.Glass
	for _, p in viewmodel:GetChildren() do
		p.Transparency = if holding then 0 else 1
	end
	beamPart.CFrame = camera.CFrame * CFrame.new(0.6, -0.5, -1)
	localBeam.Enabled = lightOn and holding
	glow.Enabled = lightOn and holding
	if tool then
		for _, p in tool:GetDescendants() do
			if p:IsA("BasePart") then
				p.LocalTransparencyModifier = 1
			elseif p:IsA("Light") then
				p.Enabled = false -- local only: others still see the tool's light
			end
		end
	end

	-- Hunter proximity: vignette pulses faster and harder the closer it is.
	local part = hunterPart()
	local closeness = 0
	if part and character and character.PrimaryPart and state:GetAttribute("Phase") == "Night" then
		local d = (part.Position - character.PrimaryPart.Position).Magnitude
		closeness = math.clamp((26 - d) / 20, 0, 1)
	end
	closeness = math.max(closeness, hideView.suspicion()) -- hidden: your heart follows its suspicion
	local pulse = 0.5 + 0.5 * math.sin(os.clock() * (4 + closeness * 8))
	local night = state:GetAttribute("Phase") == "Night"
	ambience.Volume += ((if night then 0.45 else 0.12) - ambience.Volume) * 0.02
	heartbeat.Volume = closeness * 1.1
	heartbeat.PlaybackSpeed = 1 + closeness * 0.5
	for _, f in vignette do
		f.BackgroundTransparency = 1 - closeness * (0.55 + 0.25 * pulse)
	end

	-- Shake: jumpscare, or a light tremor when it is right next to you.
	local shake = if os.clock() < shakeUntil then 0.35 else closeness * 0.04
	if shake > 0 then
		camera.CFrame *= CFrame.Angles(math.rad((math.random() - 0.5) * shake * 10), math.rad((math.random() - 0.5) * shake * 10), 0)
	end
end)

-- Flickering lamps and candles: purely cosmetic, so each client animates its own copy.
task.spawn(function()
	local rng = Random.new()
	while true do
		for _, part in CollectionService:GetTagged("NightHunterFlicker") do
			local light = part:FindFirstChildWhichIsA("Light")
			if light then
				local base = light:GetAttribute("BaseBrightness")
				if not base then
					base = light.Brightness
					light:SetAttribute("BaseBrightness", base)
				end
				light.Brightness = if rng:NextNumber() < 0.08 then base * 0.15 else base * rng:NextNumber(0.85, 1.1)
			end
		end
		task.wait(0.12)
	end
end)

---------------------------------------------------------------- text

local RESULT_TEXT = {
	Win = "NIGHT SURVIVED",
	Fail = "THE HUNTER WINS — back to night 1",
	Complete = "YOU ESCAPED THE HOUSE!",
}

local function clock(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	return ("%d:%02d"):format(seconds // 60, seconds % 60)
end

while true do
	local phase = state:GetAttribute("Phase") or "Waiting"
	local night = state:GetAttribute("Night") or 1
	local left = (state:GetAttribute("PhaseEndsAt") or 0) - Workspace:GetServerTimeNow()

	title.update()
	shop.update()

	info.Text = ("NIGHT %d / %d   ·   %s %s\n%s"):format(
		night,
		state:GetAttribute("LastNight") or 7,
		string.upper(phase),
		clock(left),
		state:GetAttribute("ObjectiveText") or ""
	)

	-- Wallet line: coins, what you carry, the key, and the adrenaline timer.
	local parts = { ("%d coins"):format(player:GetAttribute("Coins") or 0) }
	for _, id in Items.order do
		local count = player:GetAttribute("Inv_" .. id) or 0
		ContextActionService:SetTitle("NightHunterItem_" .. id, ("%s %d"):format(Items.list[id].key, count))
		if count > 0 then
			table.insert(parts, ("%s x%d [%s]"):format(Items.list[id].name, count, Items.list[id].key))
		end
	end
	if player:GetAttribute("HasKey") then
		table.insert(parts, "KEY: go to the front door!")
	end
	local boostLeft = (player:GetAttribute("AdrenalineUntil") or 0) - Workspace:GetServerTimeNow()
	if boostLeft > 0 then
		table.insert(parts, ("ADRENALINE %ds"):format(math.ceil(boostLeft)))
	end
	wallet.Text = table.concat(parts, "  ·  ")
	debugInfo.Text = ("[debug] brain %s · %s · %.3f ms · G/M/B"):format(
		string.upper(state:GetAttribute("Mode") or "?"),
		state:GetAttribute("HunterMode") or "?",
		state:GetAttribute("BrainMs") or 0
	)

	local stamina = player:GetAttribute("Stamina") or 1
	local battery = player:GetAttribute("Battery") or 1
	staminaFill.Size = UDim2.fromScale(stamina, 1)
	batteryFill.Size = UDim2.fromScale(battery, 1)
	staminaCaption.Text = ("%s  (Shift run · C sneak)"):format(string.upper(player:GetAttribute("Stance") or "walk"))
	batteryCaption.Text = ("FLASHLIGHT %s  %d%%  (F)"):format(if player:GetAttribute("Flashlight") then "ON" else "OFF", math.floor(battery * 100))

	if phase == "Waiting" then
		banner.Text = ""
	elseif phase == "Day" then
		banner.Text = ("DAY %d — get ready (%s)\nThe hunter sleeps in the %s  ·  V: shop"):format(night, clock(left), state:GetAttribute("LairRoom") or "?")
		banner.TextColor3 = Color3.fromRGB(255, 220, 150)
	elseif phase == "Report" then
		local result = state:GetAttribute("Result") or ""
		banner.Text = RESULT_TEXT[result] or result
		banner.TextColor3 = if result == "Fail" then Color3.fromRGB(255, 90, 90) else Color3.fromRGB(120, 255, 150)
	elseif phase == "Night" and (state:GetAttribute("WakeAt") or 0) > 0 then
		local wake = (state:GetAttribute("WakeAt") or 0) - Workspace:GetServerTimeNow()
		banner.Text = ("NIGHT %d — %s\nIt is blind. It hears everything. Wakes in %d…"):format(night, state:GetAttribute("ObjectiveText") or "", math.max(0, math.ceil(wake)))
		banner.TextColor3 = Color3.fromRGB(255, 120, 120)
	else
		banner.Text = ""
	end

	downNotice.Text = if player:GetAttribute("Downed") then "YOU ARE DOWN — a teammate can hold E on you to revive" else ""
	task.wait(0.1)
end
