--!nonstrict
-- Small building blocks shared by the house shell (HouseDecor) and the furniture (Furniture).
-- Coordinates are room-local: the room's centre point (HouseGraph room.center) = 0,0,0, floor top = y 0.

local CollectionService = game:GetService("CollectionService")
local ServerStorage = game:GetService("ServerStorage")

local HouseKit = {}

HouseKit.WALL_FACE = 0.5 -- the wall's inner face is this far inside the room rectangle's edge
-- Yaw that turns a -Z-facing model so its front faces into the room from wall `side`.
HouseKit.WALL_YAW = { N = 180, S = 0, W = -90, E = 90 }

-- The palette of docs/theme.md: near-black wood, dull blood red, aged pale stone, tarnished brass. Nothing bright.
HouseKit.WOOD_DARK = Color3.fromRGB(44, 30, 22)
HouseKit.WOOD = Color3.fromRGB(72, 50, 36)
HouseKit.WOOD_LIGHT = Color3.fromRGB(104, 78, 56)
HouseKit.CLOTH_RED = Color3.fromRGB(92, 30, 34)
HouseKit.CLOTH_GREEN = Color3.fromRGB(42, 56, 46)
HouseKit.CLOTH_BLUE = Color3.fromRGB(44, 50, 70)
HouseKit.DIRTY_WHITE = Color3.fromRGB(170, 164, 150)
HouseKit.METAL = Color3.fromRGB(80, 80, 86)
HouseKit.BRASS = Color3.fromRGB(118, 94, 52)
HouseKit.WARM_LIGHT = Color3.fromRGB(255, 178, 104)
HouseKit.MOON_LIGHT = Color3.fromRGB(150, 175, 255)

-- Light levels the builders start from. The FINAL levels are the LIGHTS table of HouseKit.relight (below).
HouseKit.LAMP_BRIGHTNESS = 0.5
HouseKit.LAMP_RANGE = 30
HouseKit.CHANDELIER_BRIGHTNESS = 0.6
HouseKit.CHANDELIER_RANGE = 48
HouseKit.CANDLE_BRIGHTNESS = 0.5
HouseKit.WINDOW_BRIGHTNESS = 0.6

function HouseKit.box(parent, name, size, cf, color, material, collide)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CanCollide = collide ~= false
	p.Parent = parent
	return p
end

-- A room-local placement helper: at(x, y, z, yawDegrees) -> world CFrame.
function HouseKit.placer(roomOrigin: Vector3)
	return function(x, y, z, yaw)
		return CFrame.new(roomOrigin + Vector3.new(x or 0, y or 0, z or 0)) * CFrame.Angles(0, math.rad(yaw or 0), 0)
	end
end

function HouseKit.light(parent, color, range, brightness, flicker, shadows)
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = brightness
	l.Shadows = shadows == true -- only the few lamps that light a room: candles stay cheap
	l.Parent = parent
	if flicker then
		CollectionService:AddTag(parent, "NightHunterFlicker")
	end
	return l
end

-- A candle's flame: small, a deep orange teardrop with a pale heart on a black wick, standing on `foot` (the wick's
-- base). `size` = its height (0.3 for a candle). Every one lights its surroundings a little; `range` widens it.
function HouseKit.flame(parent, foot: CFrame, size: number?, range: number?)
	local h = size or 0.3
	local function blob(name, s, y, color, transparency)
		local p = HouseKit.box(parent, name, s, foot * CFrame.new(0, y, 0), color, Enum.Material.Neon, false)
		p.Transparency = transparency
		p.CastShadow = false
		p.CanQuery = false
		p.CanTouch = false
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = p
		return p
	end
	local wick = HouseKit.box(parent, "Wick", Vector3.new(h * 0.08, h * 0.25, h * 0.08), foot * CFrame.new(0, h * 0.12, 0), Color3.fromRGB(20, 16, 14), Enum.Material.SmoothPlastic, false)
	wick.CastShadow = false
	local outer = blob("Flame", Vector3.new(h * 0.3, h * 0.8, h * 0.3), h * 0.55, Color3.fromRGB(255, 118, 24), 0.12)
	blob("FlameCore", Vector3.new(h * 0.14, h * 0.36, h * 0.14), h * 0.4, Color3.fromRGB(255, 214, 120), 0)
	HouseKit.light(outer, HouseKit.WARM_LIGHT, range or 7, HouseKit.CANDLE_BRIGHTNESS, true)
	return outer
end

-- THE light levels of the house, by "<piece>/<the part its light sits in>":
--   { brightness, range (nil = keep), casts shadows, one light per piece }   ·   false = no light there.
-- The rules behind the numbers (docs/lighting.md):
--   key     one ceiling lamp or chandelier per room. It casts the room's shadows, and its pool ends short of the
--           corners, so every room keeps dark edges.
--   accent  candles and sconces: small warm pools you can see from far off and walk toward. No shadows (cost).
--   A source lights what is around it about as much as it glows itself: a 5-stud candle pool beside a
--   blazing flame reads as a sticker, not a light.
--   A fixture never casts a shadow from its own lamp: the chandelier's stem and the lamp's brass frame stood
--   round their lights and blacked the rooms out.
local LIGHTS = {
	["Ceiling light/Bulb"] = { 0.8, 28, true },
	["Chandelier/ChandelierGlow"] = { 0.9, nil, true },
	["Chandelier/Meshes/Funnel Connector 1"] = false, -- the model's own lamp: ChandelierGlow is the chandelier's light
	["Wall sconce/Flame"] = { 0.8, 14 },
	["StandingCandelabra/Flame"] = { 0.9, 14, false, true }, -- one light for its five candles, not five
	["Candelabra/Flame"] = { 0.7, 11, false, true },
	["Candlesticks/Particle"] = { 0.6, 10 },
	["Candle/Flame"] = { 0.5, 9 },
	["Fireplace/Embers"] = { 1, 18 },
}

-- Sets every light under `root` to the table above. Runs on every server start (HouseBuilder.ensure) and in
-- Edit mode after a rebuild, so the saved house and freshly built pieces always agree.
function HouseKit.relight(root: Instance)
	local kept = {}
	for _, d in root:GetDescendants() do
		if d:IsA("Light") then
			local top = d:FindFirstAncestorWhichIsA("Model")
			while top and top.Parent:IsA("Model") do
				top = top.Parent
			end
			local spec = top and LIGHTS[top.Name .. "/" .. d.Parent.Name]
			if spec == false or (spec and spec[4] and kept[top]) then
				d:Destroy()
			elseif spec then
				kept[top] = true
				d.Brightness = spec[1]
				d.Range = spec[2] or d.Range
				d.Shadows = spec[3] == true
				if spec[3] then
					for _, p in top:GetDescendants() do
						if p:IsA("BasePart") then
							p.CastShadow = false
						end
					end
				end
			end
		end
	end
end

-- The audited Creator Store models (see docs/assets.md). May be missing in another place.
function HouseKit.library(): Folder?
	return ServerStorage:FindFirstChild("AssetLibrary")
end

function HouseKit.libraryModel(name: string): Model?
	local lib = HouseKit.library()
	return lib and lib:FindFirstChild(name)
end

-- Colours you can set without code: give a model in the AssetLibrary a Color3 attribute "Tint" and every copy of
-- it under `root` takes that colour (through its SurfaceAppearance, so the sculpted detail stays).
-- Edit mode only: game scripts may not read SurfaceAppearance.ColorMap (Plugin capability). The tints are saved with
-- the place, and the library's own SurfaceAppearances are tinted too, so copies made while the game runs match.
function HouseKit.applyTints(root: Instance)
	local lib = HouseKit.library()
	if not lib or game:GetService("RunService"):IsRunning() then
		return
	end
	local tintOf = {}
	for _, model in lib:GetChildren() do
		local tint = model:GetAttribute("Tint")
		if typeof(tint) == "Color3" then
			for _, d in model:GetDescendants() do
				if d:IsA("SurfaceAppearance") then
					tintOf[d.ColorMap] = tint
					d.Color = tint
				end
			end
		end
	end
	for _, d in root:GetDescendants() do
		if d:IsA("SurfaceAppearance") and tintOf[d.ColorMap] then
			d.Color = tintOf[d.ColorMap]
		end
	end
end

return HouseKit
