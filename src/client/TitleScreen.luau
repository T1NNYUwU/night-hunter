--!nonstrict
-- Title screen: name, one-line pitch, saved stats, PLAY and HOW TO PLAY.
-- Shown while the server waits for someone to start, and to players who join mid-run.
-- Its buttons are Modal, so the mouse is free while it is up (the game is first person).

local TitleScreen = {}

local RED = Color3.fromRGB(200, 40, 40)

local HELP = [[
SURVIVE 7 NIGHTS, THEN ESCAPE.

The hunter is BLIND. It hunts by sound.
  · Shift  run  — fast, but LOUD
  · C      sneak — slow and almost silent
  · Standing still makes no sound at all.
  · Hide in a wardrobe if it comes close.

Every night has a job: collect crates, fix fuse boxes,
and on night 7 find the key and leave by the front door.
Doing the job is loud. Plan your route during the day —
you can see which room the hunter sleeps in.

  · 1  take out the flashlight, click = light on/off   · E  interact / revive a teammate
  · V  shop (day)   · Q  Noise Maker   · R  Battery   · X  Adrenaline
]]

local function label(parent, props)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = props.font or Enum.Font.GothamMedium
	l.TextSize = props.size or 18
	l.TextColor3 = props.color or Color3.new(1, 1, 1)
	l.Size = props.frame
	l.Position = props.pos
	l.AnchorPoint = props.anchor or Vector2.new(0.5, 0)
	l.TextWrapped = true
	l.TextXAlignment = props.alignX or Enum.TextXAlignment.Center
	l.TextYAlignment = props.alignY or Enum.TextYAlignment.Top
	l.Text = props.text or ""
	l.Parent = parent
	return l
end

local function button(parent, text, pos, color)
	local b = Instance.new("TextButton")
	b.Size = UDim2.fromOffset(220, 54)
	b.AnchorPoint = Vector2.new(0.5, 0)
	b.Position = pos
	b.BackgroundColor3 = color
	b.TextColor3 = Color3.new(1, 1, 1)
	b.Font = Enum.Font.GothamBold
	b.TextSize = 22
	b.Text = text
	b.Modal = true -- frees the mouse while the title is up
	b.AutoButtonColor = true
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = b
	b.Parent = parent
	return b
end

-- onPlay() is called when the player presses PLAY.
function TitleScreen.mount(gui: ScreenGui, state: Instance, player: Player, onPlay: () -> ())
	local frame = Instance.new("Frame")
	frame.Name = "Title"
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Color3.fromRGB(6, 4, 6)
	frame.BackgroundTransparency = 0.5 -- the house shows through: the game is not "pitch black" at start
	frame.ZIndex = 20
	frame.Parent = gui

	label(frame, { frame = UDim2.fromOffset(900, 90), pos = UDim2.fromScale(0.5, 0.16), size = 64, font = Enum.Font.Creepster, color = RED, text = "7 NIGHTS HUNTER" })
	label(frame, { frame = UDim2.fromOffset(700, 30), pos = UDim2.fromScale(0.5, 0.29), size = 20, color = Color3.fromRGB(200, 190, 180), text = "It is blind. It hears everything." })
	local stats = label(frame, { frame = UDim2.fromOffset(600, 26), pos = UDim2.fromScale(0.5, 0.35), size = 16, color = Color3.fromRGB(150, 150, 160) })

	local play = button(frame, "PLAY", UDim2.fromScale(0.5, 0.45), RED)
	local how = button(frame, "HOW TO PLAY", UDim2.new(0.5, 0, 0.45, 66), Color3.fromRGB(40, 36, 44))

	local help = label(frame, {
		frame = UDim2.fromOffset(620, 360),
		pos = UDim2.new(0.5, 0, 0.45, 136),
		size = 16,
		font = Enum.Font.Code,
		color = Color3.fromRGB(215, 210, 200),
		alignX = Enum.TextXAlignment.Left,
		text = HELP,
	})
	help.Visible = false

	local dismissed = false
	local lastPhase = nil

	play.Activated:Connect(function()
		dismissed = true
		onPlay()
	end)
	how.Activated:Connect(function()
		help.Visible = not help.Visible
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
		stats.Text = if best > 0 then ("Best: night %d   ·   Escapes: %d"):format(best, escapes) else "No saved runs yet"
		frame.Visible = not dismissed
	end

	function title.isOpen(): boolean
		return frame.Visible
	end

	return title
end

return TitleScreen
