--!nonstrict
-- The light that lights YOUR view is pinned to the camera. The flashlight in the hand swings with
-- the walking animation, so a beam taken from it sways left and right with every step. Instead the beam
-- you see rides on the camera (steady, no lag); the tool's own lights are switched off on this client
-- while it is held. Other players still see a plain beam come from your hand (StarterPack.Flashlight).
--
-- How the torch is lit (docs/lighting.md). NEEDS Lighting.Technology = Future: the older modes smear every
-- light over 4-stud blocks, and a narrow beam becomes a dim square patch.
--   cones   six nested SpotLights (CONES): each ring about half as bright as the one inside it, so the beam
--           fades outward smoothly. One cone alone has a hard edge and a flat, burnt-out disc.
--   colour  cool white against the house's warm lamps: you always know which light is yours.
--   bounce  a real beam lights the room a little by bouncing off what it hits. A dim light just in front of
--           the lit surface, tinted by it, stands in for that; without it the disc hangs in a black void.
--   shadows the four bright cones cast them (an unshadowed light shines through walls); the two dim outer
--           ones do not, to save the cost.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

-- At the eyes, a touch right and low. It must not be in front of the camera: with your nose to a wall the
-- light would end up inside the wall and light nothing.
local OFFSET = CFrame.new(0.25, -0.2, 0.15)

local TORCH = Color3.fromRGB(232, 238, 255)
-- { angle, brightness it adds, range, casts shadows }: the centre is the sum of all six (3.5)
local CONES = {
	{ 14, 1.6, 60, true },
	{ 22, 0.9, 60, true },
	{ 32, 0.5, 50, true },
	{ 44, 0.28, 40, true },
	{ 58, 0.16, 30, false },
	{ 74, 0.08, 22, false },
}

local FlashlightBeam = {}

function FlashlightBeam.start()
	local player = Players.LocalPlayer
	local beam: Part? = nil
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	local aim: CFrame? = nil -- where the beam points: it trails the camera a little, like a torch in a hand
	local bounce: Part? = nil
	local bounceLight: PointLight? = nil

	local function lightsOf(handle: Instance)
		local lights = {}
		for _, child in handle:GetChildren() do
			if child:IsA("SpotLight") then
				table.insert(lights, child)
			end
		end
		return lights
	end

	RunService.RenderStepped:Connect(function(dt)
		local camera = Workspace.CurrentCamera
		local tool = player.Character and player.Character:FindFirstChild("Flashlight")
		local handle = tool and tool:FindFirstChild("Handle")
		if not (camera and handle) then
			if beam then
				beam.Parent = nil
				bounce.Parent = nil
			end
			return
		end

		if not beam then
			beam = Instance.new("Part")
			beam.Name = "FlashlightBeam"
			beam.Anchored = true
			beam.CanCollide = false
			beam.CanQuery = false
			beam.CanTouch = false
			beam.CastShadow = false
			beam.Transparency = 1
			beam.Size = Vector3.new(0.2, 0.2, 0.2)
			for _, c in CONES do
				local cone = Instance.new("SpotLight")
				cone.Face = Enum.NormalId.Front
				cone.Angle, cone.Brightness, cone.Range, cone.Shadows = c[1], c[2], c[3], c[4]
				cone.Color = TORCH
				cone.Parent = beam
			end
			bounce = beam:Clone()
			bounce:ClearAllChildren()
			bounce.Name = "FlashlightBounce"
			bounceLight = Instance.new("PointLight")
			bounceLight.Range = 12
			bounceLight.Brightness = 0
			bounceLight.Shadows = false
			bounceLight.Parent = bounce
			-- the soft spill a real torch throws around you: what lights a wall right in front of your face
			local fill = Instance.new("PointLight")
			fill.Name = "Spill"
			fill.Color = TORCH
			fill.Range = 10 -- (reaches the floor at your feet, so you see where you step; no farther)
			fill.Brightness = 0.35
			fill.Shadows = false
			fill.Parent = beam
			-- the shaft of light in the dusty air, from the lens outward
			local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
			a0.Position = Vector3.new(0, 0, -0.3)
			a1.Position = Vector3.new(0, 0, -22)
			a0.Parent, a1.Parent = beam, beam
			local shaft = Instance.new("Beam")
			shaft.Name = "Shaft"
			shaft.Attachment0, shaft.Attachment1 = a0, a1
			shaft.Width0, shaft.Width1 = 0.35, 7
			shaft.FaceCamera = true
			shaft.LightEmission = 1
			shaft.LightInfluence = 0
			shaft.Color = ColorSequence.new(TORCH)
			shaft.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.9), NumberSequenceKeypoint.new(0.4, 0.95), NumberSequenceKeypoint.new(1, 1) }) -- (a hint of dust in the air, not a white wedge)
			shaft.Parent = beam
		end

		for _, light in lightsOf(handle) do
			light.Enabled = false
		end
		-- The light leaves the torch's lens and goes to the point the camera looks at. (From the camera itself,
		-- a third-person view put your own body in the beam: its shadow covered everything.)
		local character = player.Character
		local zoom = (camera.CFrame.Position - camera.Focus.Position).Magnitude
		local source = if zoom < 1.5 then (camera.CFrame * OFFSET).Position else (handle.CFrame * CFrame.new(0, 0, -0.9)).Position
		rayParams.FilterDescendantsInstances = { character, beam, bounce }
		local reach = camera.CFrame.LookVector * 90
		local start = camera.CFrame.Position + camera.CFrame.LookVector * zoom -- (past your own back)
		local hit = Workspace:Raycast(start, reach, rayParams)
		local target = if hit then hit.Position else start + reach
		if (target - source).Magnitude < 3 then
			target = source + camera.CFrame.LookVector * 3
		end
		local look = CFrame.lookAt(source, target).Rotation
		aim = if aim and beam.Parent then aim:Lerp(look, 1 - math.exp(-14 * dt)) else look
		beam.CFrame = CFrame.new(source) * aim
		beam.Parent = if player:GetAttribute("Flashlight") == true then camera else nil

		-- the bounce: weaker the farther the beam travels, tinted by the surface it comes off
		local level = 0
		if hit and beam.Parent then
			local spot = hit.Position + hit.Normal * 1.5
			bounce.Position = if bounce.Parent then bounce.Position:Lerp(spot, 1 - math.exp(-12 * dt)) else spot
			bounceLight.Color = TORCH:Lerp(hit.Instance.Color, 0.5)
			level = 0.45 * math.clamp(1 - (hit.Position - source).Magnitude / 55, 0, 1)
		end
		bounceLight.Brightness += (level - bounceLight.Brightness) * (1 - math.exp(-12 * dt))
		bounce.Parent = beam.Parent
	end)
end

return FlashlightBeam
