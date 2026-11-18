--!nonstrict
-- What the house sounds and feels like, on this client only.
--   music    menu / day / night / chase tracks that cross-fade (ids in Sounds.luau)
--   fear     colour drains, the view tightens and blurs a little as the hunter gets close
--   storm    lightning through the windows, thunder a moment later (nights only)
--   storm    on RAINY nights: rain on the roof, lightning through the windows, thunder a moment later
--   house    a floorboard creaks, a whisper, the wind (nights only)
--   haunt    rarely: a portrait changes while your back is turned, a shadow crosses ahead of you

local Lighting = game:GetService("Lighting")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Sounds = require(game:GetService("ReplicatedStorage"):WaitForChild("NightHunter"):WaitForChild("Sounds"))

local BASE_FOV = 70
local LEVELS = { menu = 0.55, day = 0.35, night = 0.5, chase = 0.75 }
local FADE = 1.6 -- volume per second
local RAINY = { [2] = true, [3] = true, [5] = true, [7] = true } -- the nights it rains

local Atmosphere = {}

function Atmosphere.start(state: Instance, player: Player)
	local tracks = {}
	for name in LEVELS do
		local s = Instance.new("Sound")
		s.Name = "Music_" .. name
		s.SoundId = if name == "night" then Sounds.ambience else Sounds[name]
		s.Looped = true
		s.Volume = 0
		s:SetAttribute("Managed", true) -- peace mode does not touch these: update() sets their volume
		s.Parent = SoundService
		s:Play()
		tracks[name] = s
	end

	-- weather beds: rain (rainy nights) and a low wind (every night)
	local beds = {}
	for name, level in { rain = 0.4, wind = 0.16 } do
		local s = Instance.new("Sound")
		s.Name = "Bed_" .. name
		s.SoundId = Sounds[name]
		s.Looped = true
		s.Volume = 0
		s:SetAttribute("Managed", true)
		s.Parent = SoundService
		s:Play()
		beds[name] = { sound = s, level = level }
	end

	local grade = Instance.new("ColorCorrectionEffect")
	grade.Name = "LocalFear"
	grade.Parent = Lighting
	local blur = Instance.new("BlurEffect")
	blur.Name = "LocalFearBlur"
	blur.Size = 0
	blur.Parent = Lighting

	local fear = 0
	local flash = 0

	local function isQuietNight(): boolean
		return state:GetAttribute("Phase") == "Night" and state:GetAttribute("Peace") ~= true
	end

	local function isRaining(): boolean
		return isQuietNight() and RAINY[state:GetAttribute("Night") or 0] == true
	end

	local function oneShot(id: string, volume: number, parent: Instance)
		local s = Instance.new("Sound")
		s.SoundId = id
		s.Volume = volume
		s.RollOffMinDistance = 12
		s.RollOffMaxDistance = 90
		s.Parent = parent
		s.Ended:Once(function()
			s:Destroy()
		end)
		s:Play()
		return s
	end

	-- Lightning: every window flashes, the room jumps out of the dark for a blink, then the thunder.
	task.spawn(function()
		local rng = Random.new()
		while true do
			task.wait(rng:NextNumber(12, 35))
			local house = Workspace:FindFirstChild("NightHunterHouse")
			if isRaining() and house then
				local panes = {}
				for _, d in house:GetDescendants() do
					if d.Name == "WindowGlass" then
						table.insert(panes, { part = d, color = d.Color })
					end
				end
				for _, strike in { 0.09, 0.05, 0.14 } do
					flash = 0.16
					for _, pane in panes do
						pane.part.Color = Color3.fromRGB(215, 225, 255)
					end
					task.wait(strike)
					flash = 0
					for _, pane in panes do
						pane.part.Color = pane.color
					end
					task.wait(rng:NextNumber(0.05, 0.12))
				end
				task.wait(rng:NextNumber(0.6, 2))
				oneShot(Sounds.thunder, 0.9, SoundService)
			end
		end
	end)

	-- Something settles upstairs. Or something is walking.
	task.spawn(function()
		local rng = Random.new()
		while true do
			task.wait(rng:NextNumber(18, 48))
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			if isQuietNight() and root then
				local a = rng:NextNumber(0, math.pi * 2)
				local spot = Instance.new("Part")
				spot.Anchored = true
				spot.CanCollide = false
				spot.CanQuery = false
				spot.CanTouch = false
				spot.Transparency = 1
				spot.Size = Vector3.one
				spot.Position = root.Position + Vector3.new(math.cos(a) * 24, rng:NextNumber(-3, 12), math.sin(a) * 24)
				spot.Parent = Workspace
				oneShot(if rng:NextNumber() < 0.3 then Sounds.whisper else Sounds.creak, 0.3, spot).Ended:Once(function()
					spot:Destroy()
				end)
			end
		end
	end)

	-- Hauntings, rare: a portrait behind you is another picture for a while; a tall shadow crosses ahead of you.
	task.spawn(function()
		local rng = Random.new()
		while true do
			task.wait(rng:NextNumber(70, 160))
			local camera = Workspace.CurrentCamera
			local house = Workspace:FindFirstChild("NightHunterHouse")
			local furniture = house and house:FindFirstChild("Furniture")
			if isQuietNight() and camera and furniture then
				local eye, look = camera.CFrame.Position, camera.CFrame.LookVector
				if rng:NextNumber() < 0.5 then
					for _, m in furniture:GetDescendants() do
						local picture = m.Name == "Picture" and m:FindFirstChildOfClass("Decal")
						if picture and (m.Position - eye).Magnitude < 45 and (m.Position - eye):Dot(look) < 0 then
							local was = picture.Texture
							picture.Texture = "rbxassetid://12218923137"
							task.delay(25, function()
								picture.Texture = was
							end)
							break
						end
					end
				else
					local right = camera.CFrame.RightVector
					local start = eye + Vector3.new(look.X, 0, look.Z).Unit * 38 - right * 9
					local shade = Instance.new("Part")
					shade.Anchored = true
					shade.CanCollide = false
					shade.CanQuery = false
					shade.CanTouch = false
					shade.CastShadow = false
					shade.Material = Enum.Material.SmoothPlastic
					shade.Color = Color3.new(0, 0, 0)
					shade.Transparency = 0.3
					shade.Size = Vector3.new(1.8, 6.5, 1.2)
					shade.Position = start
					shade.Parent = Workspace
					TweenService:Create(shade, TweenInfo.new(0.8, Enum.EasingStyle.Linear), { Position = start + right * 18 }):Play()
					task.delay(0.85, function()
						shade:Destroy()
					end)
				end
			end
		end
	end)

	local atmosphere = {}

	-- Every frame. closeness: 0 (safe) .. 1 (it is on you).
	function atmosphere.update(dt: number, closeness: number, titleOpen: boolean)
		local phase = state:GetAttribute("Phase")
		local peace = state:GetAttribute("Peace") == true
		local chased = closeness > 0.15 or state:GetAttribute("HunterMode") == "charge"
		local want = if titleOpen then "menu"
			elseif peace then nil
			elseif phase == "Night" then (if chased then "chase" else "night")
			else "day"
		for name, s in tracks do
			local target = if name == want then LEVELS[name] else 0
			s.Volume += math.clamp(target - s.Volume, -FADE * dt, FADE * dt)
		end

		for name, bed in beds do
			local on = not titleOpen and (if name == "rain" then isRaining() else isQuietNight())
			bed.sound.Volume += math.clamp((if on then bed.level else 0) - bed.sound.Volume, -FADE * dt * 0.3, FADE * dt * 0.3)
		end

		fear += (closeness - fear) * math.min(1, dt * 3)
		grade.Saturation = -0.55 * fear
		grade.Contrast = 0.18 * fear
		grade.Brightness = flash
		grade.TintColor = Color3.new(1, 1 - 0.14 * fear, 1 - 0.16 * fear)
		blur.Size = 3 * fear
		local camera = Workspace.CurrentCamera
		if camera and not titleOpen then
			camera.FieldOfView = BASE_FOV - 7 * fear + math.sin(os.clock() * 7) * 0.8 * fear
		end
	end

	return atmosphere
end

return Atmosphere
