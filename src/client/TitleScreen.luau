--!nonstrict
-- Title screen: a slow camera in the candle-lit hall, the name on the left, three quiet menu lines.
-- Shown while the server waits for someone to start, and to players who join mid-run.
-- Its buttons are Modal, so the mouse is free while it is up (the game is first person).

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local TitleScreen = {}

local BLOOD = Color3.fromRGB(176, 22, 26)
local BONE = Color3.fromRGB(226, 216, 200)
local ASH = Color3.fromRGB(150, 142, 134)
local MARGIN = 0.075

local HELP = [[
<b>SURVIVE 7 NIGHTS, THEN ESCAPE.</b>

The hunter is <b>blind</b>. It hunts by sound.

<b>Shift</b>   run: fast, but loud
<b>C</b>   sneak: slow and almost silent
Standing still makes no sound at all.
Hide in a wardrobe if it comes close.

Each night has a job. Doing it is loud.
Plan your route during the day: you can see where it sleeps.
On night 7, bring the relics to the altar by the pillar,
take the key and leave through the front door.

<b>1</b>  flashlight, click to switch   <b>E</b>  interact, doors, revive
<b>V</b>  shop (day)   <b>Q</b>  Noise Maker   <b>R</b>  Battery   <b>X</b>  Adrenaline
]]

local function label(parent, props)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = props.font or Enum.Font.Gotham
	l.TextSize = props.size or 18
	l.TextColor3 = props.color or BONE
	l.Size = props.frame
	l.Position = props.pos
	l.AnchorPoint = props.anchor or Vector2.zero
	l.TextWrapped = true
	l.RichText = props.rich == true
	l.TextXAlignment = props.alignX or Enum.TextXAlignment.Left
	l.TextYAlignment = props.alignY or Enum.TextYAlignment.Top
	l.Text = props.text or ""
	l.ZIndex = 22
	l.Parent = parent
	return l
end

-- One line of the menu: text, and a red rule that grows when you point at it.
local function menuLine(parent, text: string, y: number, primary: boolean)
	local b = Instance.new("TextButton")
	b.AutoButtonColor = false
	b.BackgroundTransparency = 1
	b.Size = UDim2.fromOffset(320, 50)
	b.Position = UDim2.new(MARGIN, 0, 0.5, y)
	b.Font = if primary then Enum.Font.GothamBold else Enum.Font.GothamMedium
	b.TextSize = if primary then 26 else 20
	b.TextColor3 = if primary then BONE else ASH
	b.TextXAlignment = Enum.TextXAlignment.Left
	b.Text = text
	b.Modal = true
	b.ZIndex = 22
	b.Parent = parent
	local rule = Instance.new("Frame")
	rule.BorderSizePixel = 0
	rule.BackgroundColor3 = BLOOD
	rule.Size = UDim2.fromOffset(if primary then 34 else 0, 2)
	rule.Position = UDim2.new(0, 0, 1, -4)
	rule.ZIndex = 22
	rule.Parent = b
	local rest = rule.Size
	local fast = TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	b.MouseEnter:Connect(function()
		TweenService:Create(b, fast, { TextColor3 = Color3.new(1, 1, 1) }):Play()
		TweenService:Create(rule, fast, { Size = UDim2.fromOffset(150, 2) }):Play()
	end)
	b.MouseLeave:Connect(function()
		TweenService:Create(b, fast, { TextColor3 = if primary then BONE else ASH }):Play()
		TweenService:Create(rule, fast, { Size = rest }):Play()
	end)
	return b
end

-- onPlay() is called when the player presses PLAY.
function TitleScreen.mount(gui: ScreenGui, state: Instance, player: Player, onPlay: () -> ())
	local frame = Instance.new("Frame")
	frame.Name = "Title"
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundTransparency = 1
	frame.ZIndex = 20
	frame.Parent = gui

	-- The dark the words sit on: heavy on the left, gone by the middle of the screen, a little at the foot.
	local shade = Instance.new("Frame")
	shade.Size = UDim2.fromScale(1, 1)
	shade.BackgroundColor3 = Color3.fromRGB(4, 3, 5)
	shade.BorderSizePixel = 0
	shade.ZIndex = 20
	shade.Parent = frame
	local g = Instance.new("UIGradient")
	g.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.05), NumberSequenceKeypoint.new(0.42, 0.45), NumberSequenceKeypoint.new(0.75, 0.92), NumberSequenceKeypoint.new(1, 0.8) })
	g.Parent = shade

	-- Everything that is not the backdrop. Scales with the height of the screen, so it fits a phone.
	local content = Instance.new("Frame")
	content.BackgroundTransparency = 1
	content.ZIndex = 21
	content.Parent = frame
	local scale = Instance.new("UIScale")
	scale.Parent = content

	label(content, { frame = UDim2.fromOffset(700, 100), pos = UDim2.new(MARGIN, 0, 0.5, -270), size = 104, font = Enum.Font.Creepster, color = BLOOD, text = "7 NIGHTS", alignY = Enum.TextYAlignment.Center })
	label(content, { frame = UDim2.fromOffset(700, 100), pos = UDim2.new(MARGIN, 0, 0.5, -178), size = 104, font = Enum.Font.Creepster, color = BONE, text = "HUNTER", alignY = Enum.TextYAlignment.Center })
	label(content, { frame = UDim2.fromOffset(520, 28), pos = UDim2.new(MARGIN, 2, 0.5, -74), size = 20, font = Enum.Font.GothamMedium, color = ASH, text = "It is blind. It hears everything." })

	local play = menuLine(content, "PLAY", -20, true)
	local how = menuLine(content, "HOW TO PLAY", 34, false)
	local stats = label(content, { frame = UDim2.fromOffset(420, 22), pos = UDim2.new(MARGIN, 2, 0.5, 106), size = 15, color = Color3.fromRGB(116, 110, 106) })

	local help = Instance.new("Frame")
	help.AnchorPoint = Vector2.new(1, 0.5)
	help.Position = UDim2.new(1 - MARGIN * 0.6, 0, 0.5, 0)
	help.Size = UDim2.fromOffset(520, 430)
	help.BackgroundColor3 = Color3.fromRGB(8, 6, 8)
	help.BackgroundTransparency = 0.12
	help.BorderSizePixel = 0
	help.Visible = false
	help.ZIndex = 21
	help.Parent = content
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(70, 24, 26)
	stroke.Parent = help
	label(help, { frame = UDim2.new(1, -48, 1, -44), pos = UDim2.fromOffset(24, 22), size = 16, rich = true, color = BONE, text = HELP })

	local dismissed = false
	local lastPhase = nil
	local camStart = os.clock()

	play.Activated:Connect(function()
		dismissed = true
		onPlay()
	end)
	how.Activated:Connect(function()
		help.Visible = not help.Visible
	end)

	-- The camera: on the rug inside the front door, drifting a little, looking up at the carved pillar.
	local owned = false
	RunService:BindToRenderStep("NightHunterTitleCamera", Enum.RenderPriority.Camera.Value + 2, function()
		local camera = Workspace.CurrentCamera
		local viewport = camera and camera.ViewportSize
		if viewport then
			local s = math.clamp(viewport.Y / 760, 0.5, 1.15)
			scale.Scale = s
			content.Size = UDim2.fromScale(1 / s, 1 / s)
		end
		local house = Workspace:FindFirstChild("NightHunterHouse")
		local origin = house and house:GetAttribute("Origin")
		local open = frame.Visible and origin ~= nil
		if open then
			owned = true
			camera.CameraType = Enum.CameraType.Scriptable
			local t = os.clock() - camStart
			local eye = origin + Vector3.new(-5 + math.sin(t * 0.09) * 5, 7.5 + math.sin(t * 0.13) * 0.5, 80 + math.sin(t * 0.06) * 2)
			camera.CFrame = CFrame.lookAt(eye, origin + Vector3.new(4, 12, 30))
			camera.FieldOfView = 62
		elseif owned then
			owned = false
			camera.CameraType = Enum.CameraType.Custom
			camera.FieldOfView = 70
			local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
			if humanoid then
				camera.CameraSubject = humanoid
			end
		end
	end)

	local title = {}

	function title.update()
		local phase = state:GetAttribute("Phase") or "Waiting"
		if phase == "Waiting" and lastPhase ~= nil and lastPhase ~= "Waiting" then
			dismissed = false -- back at the title after a run: show it again
		end
		lastPhase = phase
		play.Text = if phase == "Waiting" then "PLAY" else "JOIN THE NIGHT"
		local best = player:GetAttribute("BestNight") or 0
		local escapes = player:GetAttribute("Escapes") or 0
		stats.Text = if best > 0 then ("Best night %d   ·   Escapes %d"):format(best, escapes) else ""
		frame.Visible = not dismissed
	end

	function title.isOpen(): boolean
		return frame.Visible
	end

	return title
end

return TitleScreen
