--!nonstrict
-- Small building blocks shared by the house shell (HouseDecor) and the furniture (Furniture).
-- Coordinates are room-local: the room's centre point (HouseGraph room.center) = 0,0,0, floor top = y 0.

local CollectionService = game:GetService("CollectionService")
local ServerStorage = game:GetService("ServerStorage")

local HouseKit = {}

HouseKit.WALL_FACE = 0.5 -- the wall's inner face is this far inside the room rectangle's edge
-- Yaw that turns a -Z-facing model so its front faces into the room from wall `side`.
HouseKit.WALL_YAW = { N = 180, S = 0, W = -90, E = 90 }

HouseKit.WOOD_DARK = Color3.fromRGB(58, 40, 30)
HouseKit.WOOD = Color3.fromRGB(96, 66, 46)
HouseKit.WOOD_LIGHT = Color3.fromRGB(140, 104, 72)
HouseKit.CLOTH_RED = Color3.fromRGB(110, 36, 42)
HouseKit.CLOTH_GREEN = Color3.fromRGB(52, 72, 58)
HouseKit.CLOTH_BLUE = Color3.fromRGB(52, 62, 92)
HouseKit.DIRTY_WHITE = Color3.fromRGB(196, 190, 176)
HouseKit.METAL = Color3.fromRGB(92, 92, 98)
HouseKit.BRASS = Color3.fromRGB(160, 125, 60)
HouseKit.WARM_LIGHT = Color3.fromRGB(255, 196, 140)
HouseKit.MOON_LIGHT = Color3.fromRGB(150, 175, 255)

-- Light levels (horror: dim). One place to tune the whole house.
HouseKit.LAMP_BRIGHTNESS = 0.3
HouseKit.LAMP_RANGE = 30
HouseKit.CHANDELIER_BRIGHTNESS = 0.32
HouseKit.CHANDELIER_RANGE = 44
HouseKit.CANDLE_BRIGHTNESS = 0.32
HouseKit.WINDOW_BRIGHTNESS = 0.45

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

-- The audited Creator Store models (see docs/assets.md). May be missing in another place.
function HouseKit.library(): Folder?
	return ServerStorage:FindFirstChild("AssetLibrary")
end

function HouseKit.libraryModel(name: string): Model?
	local lib = HouseKit.library()
	return lib and lib:FindFirstChild(name)
end

return HouseKit
