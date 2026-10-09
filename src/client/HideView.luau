--!nonstrict
-- What a hidden player sees and does (the server decides everything; see HideService):
--   camera   fixed at the spot's Eye (the gap between the wardrobe doors / under the cloth's
--            edge); the mouse (or a finger drag) turns the head a little
--   overlay  the wardrobe doors on both sides with a bright slit between them, or the cloth
--            hanging over the top of the view
--   meters   BREATH (hold SPACE / BREATH to stop breathing; empty = you gasp) and the hunter's
--            SUSPICION of this spot (its real belief)
--   keys     E / LEAVE to get out
-- Players attributes read: Hidden, HideKind, HideEye, Breath, HoldingBreath, Suspicion.

local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local HideView = {}

local LOOK = { -- yaw / pitch limits (radians) per kind
	wardrobe = { yaw = 0.55, up = 0.25, down = 0.35 },
	table = { yaw = 0.9, up = 0.12, down = 0.25 },
}
local SENSITIVITY = 0.0035

local function frame(parent, props)
	local f = Instance.new("Frame")
	f.BorderSizePixel = 0
	f.BackgroundColor3 = props.color or Color3.new(0, 0, 0)
	f.BackgroundTransparency = props.transparency or 0
	f.Size = props.size
	f.Position = props.pos or UDim2.new()
	f.AnchorPoint = props.anchor or Vector2.zero
	f.ZIndex = props.z or 5
	f.Parent = parent
	return f
end

local function gradient(parent, rotation, from, to)
	local g = Instance.new("UIGradient")
	g.Rotation = rotation
	g.Transparency = NumberSequence.new(from, to)
	g.Parent = parent
	return g
end

local function text(parent, props)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = props.font or Enum.Font.GothamBold
	l.TextSize = props.size or 14
	l.TextColor3 = props.color or Color3.new(1, 1, 1)
	l.TextStrokeTransparency = 0.5
	l.Size = props.frame
	l.Position = props.pos
	l.AnchorPoint = props.anchor or Vector2.new(0.5, 0)
	l.ZIndex = 7
	l.Text = props.text or ""
	l.Parent = parent
	return l
end

function HideView.mount(gui: ScreenGui, player: Player, remotes: Folder)
	local root = frame(gui, { size = UDim2.fromScale(1, 1), transparency = 1, z = 5 })
	root.Name = "HideView"
	root.Visible = false

	-- Wardrobe: two dark wooden doors with a thin bright gap between them.
	local doors = frame(root, { size = UDim2.fromScale(1, 1), transparency = 1 })
	local woodColor = Color3.fromRGB(22, 15, 11)
	local left = frame(doors, { size = UDim2.fromScale(0.43, 1), color = woodColor })
	local right = frame(doors, { size = UDim2.fromScale(0.43, 1), pos = UDim2.fromScale(1, 0), anchor = Vector2.new(1, 0), color = woodColor })
	gradient(left, 0, 0, 0.15)
	gradient(right, 180, 0, 0.15)
	-- Slats: a few faint horizontal lines on each door, so it reads as wood.
	for i = 1, 6 do
		for _, door in { left, right } do
			frame(door, { size = UDim2.new(1, 0, 0, 2), pos = UDim2.fromScale(0, i / 7), color = Color3.fromRGB(40, 28, 20), z = 6 })
		end
	end
	-- Darken the top and bottom of the gap too.
	local gapTop = frame(doors, { size = UDim2.new(0.14, 0, 0.12, 0), pos = UDim2.fromScale(0.5, 0), anchor = Vector2.new(0.5, 0), color = woodColor })
	gradient(gapTop, 90, 0, 1)
	local gapBottom = frame(doors, { size = UDim2.new(0.14, 0, 0.12, 0), pos = UDim2.fromScale(0.5, 1), anchor = Vector2.new(0.5, 1), color = woodColor })
	gradient(gapBottom, -90, 0, 1)

	-- Table: the cloth hangs over most of the view; you see the floor under its hem.
	local cloth = frame(root, { size = UDim2.fromScale(1, 0.62), color = Color3.fromRGB(70, 62, 52) })
	gradient(cloth, 90, 0, 0.05)
	local hem = frame(cloth, { size = UDim2.new(1, 0, 0, 14), pos = UDim2.fromScale(0, 1), color = Color3.fromRGB(95, 86, 72), z = 6 })
	gradient(hem, 90, 0, 0.6)
	local under = frame(root, { size = UDim2.fromScale(1, 0.38), pos = UDim2.fromScale(0, 1), anchor = Vector2.new(0, 1), color = Color3.new(0, 0, 0) })
	gradient(under, -90, 0.35, 1)

	-- HUD
	local hint = text(root, {
		frame = UDim2.fromOffset(560, 22),
		pos = UDim2.new(0.5, 0, 1, -118),
		size = 15,
		text = "HIDDEN   ·   E: leave   ·   hold SPACE: hold your breath",
	})
	local warn = text(root, { frame = UDim2.fromOffset(560, 30), pos = UDim2.fromScale(0.5, 0.15), size = 22, color = Color3.fromRGB(255, 90, 90) })

	local function meter(y: number, label: string, color: Color3)
		local back = frame(root, { size = UDim2.fromOffset(240, 10), pos = UDim2.new(0.5, 0, 1, y), anchor = Vector2.new(0.5, 1), color = Color3.fromRGB(20, 20, 24), transparency = 0.2, z = 7 })
		local fill = frame(back, { size = UDim2.fromScale(1, 1), color = color, z = 8 })
		text(back, { frame = UDim2.fromOffset(240, 14), pos = UDim2.new(0.5, 0, 0, -16), size = 11, text = label, color = Color3.fromRGB(210, 210, 215) })
		return fill
	end
	local breathFill = meter(-84, "BREATH", Color3.fromRGB(140, 210, 255))
	local suspicionFill = meter(-58, "IT SUSPECTS THIS SPOT", Color3.fromRGB(230, 60, 60))

	------------------------------------------------------------ input

	local yaw, pitch = 0, 0
	local hidden = false
	local kind = "wardrobe"

	local function bindControls(on: boolean)
		if on then
			ContextActionService:BindActionAtPriority("NightHunterUnhide", function(_, state)
				if state == Enum.UserInputState.Begin then
					remotes:WaitForChild("Unhide"):FireServer()
				end
				return Enum.ContextActionResult.Sink
			end, true, 3000, Enum.KeyCode.E, Enum.KeyCode.ButtonX)
			ContextActionService:BindActionAtPriority("NightHunterBreath", function(_, state)
				if state == Enum.UserInputState.Begin then
					remotes:WaitForChild("HoldBreath"):FireServer(true)
				elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
					remotes:WaitForChild("HoldBreath"):FireServer(false)
				end
				return Enum.ContextActionResult.Sink
			end, true, 3000, Enum.KeyCode.Space, Enum.KeyCode.ButtonA)
			ContextActionService:SetTitle("NightHunterUnhide", "LEAVE")
			ContextActionService:SetTitle("NightHunterBreath", "BREATH")
			ContextActionService:SetPosition("NightHunterUnhide", UDim2.new(1, -95, 1, -170))
			ContextActionService:SetPosition("NightHunterBreath", UDim2.new(1, -170, 1, -95))
		else
			ContextActionService:UnbindAction("NightHunterUnhide")
			ContextActionService:UnbindAction("NightHunterBreath")
		end
	end

	UserInputService.InputChanged:Connect(function(input, processed)
		if not hidden then
			return
		end
		local limits = LOOK[kind] or LOOK.wardrobe
		if input.UserInputType == Enum.UserInputType.MouseMovement or (input.UserInputType == Enum.UserInputType.Touch and not processed) then
			local k = if input.UserInputType == Enum.UserInputType.Touch then SENSITIVITY * 1.5 else SENSITIVITY
			yaw = math.clamp(yaw - input.Delta.X * k, -limits.yaw, limits.yaw)
			pitch = math.clamp(pitch - input.Delta.Y * k, -limits.down, limits.up)
		end
	end)

	------------------------------------------------------------ per frame

	local view = {}

	function view.isHidden(): boolean
		return hidden
	end

	-- Called every render step (before camera shake). Returns true while it owns the camera.
	function view.update(_dt: number): boolean
		local camera = Workspace.CurrentCamera
		local node = player:GetAttribute("Hidden") or 0
		local nowHidden = node ~= 0
		if nowHidden ~= hidden then
			hidden = nowHidden
			yaw, pitch = 0, 0
			bindControls(hidden)
			root.Visible = hidden
			if hidden then
				camera.CameraType = Enum.CameraType.Scriptable
			else
				camera.CameraType = Enum.CameraType.Custom
				local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
				if humanoid then
					camera.CameraSubject = humanoid
				end
			end
		end
		if not hidden then
			return false
		end

		kind = player:GetAttribute("HideKind") or "wardrobe"
		doors.Visible = kind == "wardrobe"
		cloth.Visible = kind == "table"
		under.Visible = kind == "table"
		if camera.CameraType ~= Enum.CameraType.Scriptable then
			camera.CameraType = Enum.CameraType.Scriptable -- something else reset it: take it back
		end
		UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
		local eye = player:GetAttribute("HideEye")
		if typeof(eye) == "CFrame" then
			camera.CFrame = eye * CFrame.Angles(0, yaw, 0) * CFrame.Angles(pitch, 0, 0)
		end

		local breath = player:GetAttribute("Breath") or 1
		local holding = player:GetAttribute("HoldingBreath") == true
		local suspicion = player:GetAttribute("Suspicion") or 0
		breathFill.Size = UDim2.fromScale(breath, 1)
		breathFill.BackgroundColor3 = if holding and breath < 0.3 then Color3.fromRGB(255, 120, 90) else Color3.fromRGB(140, 210, 255)
		suspicionFill.Size = UDim2.fromScale(math.clamp(suspicion, 0, 1), 1)
		warn.Text = if suspicion >= 0.85 then "IT IS COMING FOR THIS SPOT"
			elseif holding and breath < 0.3 then "...you can't hold it much longer"
			elseif holding then "holding your breath..."
			else ""
		hint.Text = ("HIDDEN (%s)   ·   E: leave   ·   hold SPACE: hold your breath"):format(if kind == "table" then "under the table" else "wardrobe")
		return true
	end

	function view.suspicion(): number
		return if hidden then (player:GetAttribute("Suspicion") or 0) else 0
	end

	return view
end

return HideView
