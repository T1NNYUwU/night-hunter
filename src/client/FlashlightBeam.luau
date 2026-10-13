--!nonstrict
-- The light that lights YOUR view is pinned to the camera. The flashlight in the hand swings with
-- the walking animation, so a beam taken from it sways left and right with every step. Instead a copy
-- of the tool's lights rides on the camera (steady, no lag); the tool's own lights are switched off on
-- this client while it is held. Other players still see the beam come from your hand.
--
-- The copy takes its looks from the lights inside StarterPack.Flashlight.Handle, so tuning them there
-- (Brightness, Range, Angle) still works.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local OFFSET = CFrame.new(0.5, -0.4, -1) -- a little to the right and below the eyes, like a held torch

local FlashlightBeam = {}

function FlashlightBeam.start()
	local player = Players.LocalPlayer
	local beam: Part? = nil

	local function lightsOf(handle: Instance)
		local lights = {}
		for _, child in handle:GetChildren() do
			if child:IsA("SpotLight") then
				table.insert(lights, child)
			end
		end
		return lights
	end

	RunService.RenderStepped:Connect(function()
		local camera = Workspace.CurrentCamera
		local tool = player.Character and player.Character:FindFirstChild("Flashlight")
		local handle = tool and tool:FindFirstChild("Handle")
		if not (camera and handle) then
			if beam then
				beam.Parent = nil
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
			for _, light in lightsOf(handle) do
				local copy = light:Clone()
				copy.Enabled = true
				copy.Parent = beam
			end
		end

		for _, light in lightsOf(handle) do
			light.Enabled = false
		end
		beam.CFrame = camera.CFrame * OFFSET
		beam.Parent = if player:GetAttribute("Flashlight") == true then camera else nil
	end)
end

return FlashlightBeam
