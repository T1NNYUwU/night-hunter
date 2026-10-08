-- Survivor client: first-person view, controls, HUD and the scary bits.
--   Shift (hold) sprint · C crouch on/off · F / click flashlight · E interact (prompts)
--   Mobile: on-screen SPRINT / CROUCH / LIGHT buttons (ContextActionService touch buttons)
--   Studio only: G decoy · M switch brain · B show/hide the hunter's belief (debug)

local CollectionService = game:GetService("CollectionService")
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("NightHunterRemotes")
local state = Workspace:WaitForChild("NightHunterState")

player.CameraMode = Enum.CameraMode.LockFirstPerson

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
local debugInfo = label({ frame = UDim2.fromOffset(280, 20), pos = UDim2.fromOffset(12, 116), size = 12, color = Color3.fromRGB(160, 160, 170), alignX = Enum.TextXAlignment.Left })
debugInfo.Visible = RunService:IsStudio()

local banner = label({ frame = UDim2.fromOffset(560, 90), pos = UDim2.fromScale(0.5, 0.22), anchor = Vector2.new(0.5, 0.5), size = 32, font = Enum.Font.GothamBold, stroke = 0.4 })
local downNotice = label({ frame = UDim2.fromOffset(560, 40), pos = UDim2.fromScale(0.5, 0.62), anchor = Vector2.new(0.5, 0.5), size = 22, font = Enum.Font.GothamBold, color = Color3.fromRGB(255, 90, 90), stroke = 0.3 })

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

-- The held tool's light points wherever the arm points; for your own view the beam follows
-- the camera instead. Other players still see the tool's light.
local beamPart = Instance.new("Part")
beamPart.Name = "LocalFlashlight"
beamPart.Anchored = true
beamPart.CanCollide = false
beamPart.CanQuery = false
beamPart.CanTouch = false
beamPart.Transparency = 1
beamPart.Size = Vector3.new(0.2, 0.2, 0.2)
beamPart.Parent = Workspace.CurrentCamera
local localBeam = Instance.new("SpotLight")
localBeam.Face = Enum.NormalId.Front
localBeam.Angle = 50
localBeam.Range = 42
localBeam.Brightness = 3
localBeam.Color = Color3.fromRGB(255, 244, 220)
localBeam.Shadows = true
localBeam.Parent = beamPart

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
	end
	wasDown = down
end)

local function hunterPart(): BasePart?
	local house = Workspace:FindFirstChild("NightHunterHouse")
	local model = house and house:FindFirstChild("Hunter")
	return model and model.PrimaryPart
end

-- Runs right after Roblox's camera script, so the shake and the beam use this frame's camera.
RunService:BindToRenderStep("NightHunterView", Enum.RenderPriority.Camera.Value + 1, function()
	local camera = Workspace.CurrentCamera
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")

	-- Crouch lowers the eyes.
	if humanoid then
		local targetY = if crouching and not sprintHeld then -1.6 else 0
		local y = humanoid.CameraOffset.Y
		humanoid.CameraOffset = Vector3.new(0, y + (targetY - y) * 0.2, 0)
	end

	-- Local beam follows the camera; hide the hand-held beam in our own view.
	local lightOn = player:GetAttribute("Flashlight") == true
	beamPart.CFrame = camera.CFrame * CFrame.new(0.6, -0.5, 0)
	localBeam.Enabled = lightOn
	local tool = character and character:FindFirstChild("Flashlight")
	if tool and tool:FindFirstChild("Handle") and tool.Handle:FindFirstChild("Beam") then
		tool.Handle.Beam.Enabled = false
	end

	-- Hunter proximity: vignette pulses faster and harder the closer it is.
	local part = hunterPart()
	local closeness = 0
	if part and character and character.PrimaryPart and state:GetAttribute("Phase") == "Night" then
		local d = (part.Position - character.PrimaryPart.Position).Magnitude
		closeness = math.clamp((26 - d) / 20, 0, 1)
	end
	local pulse = 0.5 + 0.5 * math.sin(os.clock() * (4 + closeness * 8))
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
	Complete = "YOU SURVIVED ALL 7 NIGHTS!",
}

local function clock(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	return ("%d:%02d"):format(seconds // 60, seconds % 60)
end

while true do
	local phase = state:GetAttribute("Phase") or "Waiting"
	local night = state:GetAttribute("Night") or 1
	local left = (state:GetAttribute("PhaseEndsAt") or 0) - Workspace:GetServerTimeNow()

	info.Text = ("NIGHT %d / %d   ·   %s %s\nCrates: %d / %d"):format(
		night,
		state:GetAttribute("LastNight") or 7,
		string.upper(phase),
		clock(left),
		state:GetAttribute("Crates") or 0,
		state:GetAttribute("CratesNeeded") or 0
	)
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

	if phase == "Day" then
		banner.Text = ("DAY %d — get ready (%s)\nThe hunter sleeps in the %s"):format(night, clock(left), state:GetAttribute("LairRoom") or "?")
		banner.TextColor3 = Color3.fromRGB(255, 220, 150)
	elseif phase == "Report" then
		local result = state:GetAttribute("Result") or ""
		banner.Text = RESULT_TEXT[result] or result
		banner.TextColor3 = if result == "Fail" then Color3.fromRGB(255, 90, 90) else Color3.fromRGB(120, 255, 150)
	elseif phase == "Night" and (state:GetAttribute("WakeAt") or 0) > 0 then
		local wake = (state:GetAttribute("WakeAt") or 0) - Workspace:GetServerTimeNow()
		banner.Text = ("NIGHT %d — collect %d crates\nIt is blind. It hears everything. Wakes in %d…"):format(night, state:GetAttribute("CratesNeeded") or 0, math.max(0, math.ceil(wake)))
		banner.TextColor3 = Color3.fromRGB(255, 120, 120)
	else
		banner.Text = ""
	end

	downNotice.Text = if player:GetAttribute("Downed") then "YOU ARE DOWN — a teammate can hold E on you to revive" else ""
	task.wait(0.1)
end
