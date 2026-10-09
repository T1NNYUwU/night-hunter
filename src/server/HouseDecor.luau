--!nonstrict
-- Furniture, wall finishes, windows and lights for the house: an abandoned family mansion at night.
--
-- Real furniture comes from ServerStorage.AssetLibrary: free Creator Store models that were
-- audited (scripts removed, see docs/assets.md) and normalised so each has a bottom-centre
-- "Root" part and its front facing -Z. Things the library does not have (fireplace, kitchen
-- counters, crib...) are built from parts. If the library is missing (another place), every
-- library prop falls back to a plain box of the same size, so the house still builds.
--
-- Coordinates are room-local: room centre = 0,0,0, floor top = y 0, inner wall faces at ±11.5.
-- Props hug the walls and stay out of the central "+" (room centre <-> doors), which is where
-- players and the hunter walk, and away from the wardrobe each room has for hiding.

local CollectionService = game:GetService("CollectionService")
local ServerStorage = game:GetService("ServerStorage")

local HouseGraph = require(game:GetService("ReplicatedStorage"):WaitForChild("NightHunter"):WaitForChild("HouseGraph"))

local HouseDecor = {}
HouseDecor.VERSION = 5 -- bump when decor changes, so saved houses get rebuilt

local FACE = 11.5 -- inner wall face
-- Library models are expected to face -Z. Measured exceptions (docs/assets.md):
-- the wardrobe's doors and handles sit on its +Z side, so it is turned around.
local ASSET_YAW = { Wardrobe = 180 }

local WOOD_DARK = Color3.fromRGB(58, 40, 30)
local WOOD = Color3.fromRGB(96, 66, 46)
local WOOD_LIGHT = Color3.fromRGB(140, 104, 72)
local CLOTH_RED = Color3.fromRGB(110, 36, 42)
local CLOTH_GREEN = Color3.fromRGB(52, 72, 58)
local CLOTH_BLUE = Color3.fromRGB(52, 62, 92)
local DIRTY_WHITE = Color3.fromRGB(196, 190, 176)
local METAL = Color3.fromRGB(92, 92, 98)
local BRASS = Color3.fromRGB(160, 125, 60)
local WARM_LIGHT = Color3.fromRGB(255, 196, 140)
local MOON_LIGHT = Color3.fromRGB(150, 175, 255)

local FALLBACK_SIZE = { -- used only when AssetLibrary is missing
	Furniture_Bed = Vector3.new(5.8, 3.5, 9),
	Furniture_Shelf = Vector3.new(10.9, 8.6, 3.4),
	Furniture_Cabinet = Vector3.new(4.2, 7.6, 2.5),
	Furniture_Table = Vector3.new(4.5, 3.3, 6.7),
	Furniture_Chair = Vector3.new(2.9, 4.9, 3),
	Furniture_Drawer = Vector3.new(6.6, 3.6, 3.1),
	Wardrobe = Vector3.new(5.1, 7.4, 2.1),
	HideWardrobe = Vector3.new(5.6, 7.9, 2.6),
	HideTable = Vector3.new(6.4, 3.1, 6.4),
	Bathtub = Vector3.new(7, 2.6, 3.8),
	Chandelier = Vector3.new(7.6, 8.7, 7.9),
	Candelabra = Vector3.new(2, 3.2, 0.8),
	Cobwebs = Vector3.new(15.2, 2.8, 15.7),
}

-- Room themes. `noWindow` lists outer walls that get no window (a door, a fireplace, a shelf).
HouseDecor.THEMES = {
	[1] = { name = "Foyer", wall = Color3.fromRGB(78, 62, 58), floor = Color3.fromRGB(70, 66, 62), floorMat = Enum.Material.Marble, noWindow = { W = true } },
	[2] = { name = "Grand Hall", wall = Color3.fromRGB(70, 58, 50), floor = WOOD_DARK, floorMat = Enum.Material.WoodPlanks },
	[3] = { name = "Library", wall = Color3.fromRGB(52, 66, 56), floor = WOOD, floorMat = Enum.Material.WoodPlanks },
	[4] = { name = "Study", wall = Color3.fromRGB(74, 56, 46), floor = WOOD, floorMat = Enum.Material.WoodPlanks, noWindow = { N = true } },
	[5] = { name = "Storeroom", wall = Color3.fromRGB(86, 80, 70), floor = Color3.fromRGB(80, 74, 66), floorMat = Enum.Material.Concrete },
	[6] = { name = "Living Room", wall = Color3.fromRGB(84, 54, 50), floor = WOOD, floorMat = Enum.Material.WoodPlanks },
	[7] = { name = "Gallery", wall = Color3.fromRGB(60, 52, 72), floor = WOOD_DARK, floorMat = Enum.Material.WoodPlanks },
	[8] = { name = "Bedroom", wall = Color3.fromRGB(86, 70, 92), floor = WOOD_LIGHT, floorMat = Enum.Material.WoodPlanks },
	[9] = { name = "Kitchen", wall = Color3.fromRGB(118, 114, 96), floor = Color3.fromRGB(150, 150, 140), floorMat = Enum.Material.Slate },
	[10] = { name = "Dining Room", wall = Color3.fromRGB(70, 52, 70), floor = WOOD, floorMat = Enum.Material.WoodPlanks },
	[11] = { name = "Hallway", wall = Color3.fromRGB(80, 74, 60), floor = WOOD_DARK, floorMat = Enum.Material.WoodPlanks },
	[12] = { name = "Master Bedroom", wall = Color3.fromRGB(64, 50, 72), floor = WOOD_LIGHT, floorMat = Enum.Material.WoodPlanks },
	[13] = { name = "Pantry", wall = Color3.fromRGB(96, 88, 72), floor = Color3.fromRGB(90, 84, 74), floorMat = Enum.Material.Slate, noWindow = { S = true, W = true } },
	[14] = { name = "Servants' Room", wall = Color3.fromRGB(90, 80, 66), floor = WOOD, floorMat = Enum.Material.WoodPlanks },
	[15] = { name = "Nursery", wall = Color3.fromRGB(120, 100, 82), floor = WOOD_LIGHT, floorMat = Enum.Material.WoodPlanks },
	[16] = { name = "Bathroom", wall = Color3.fromRGB(86, 108, 106), floor = Color3.fromRGB(170, 175, 172), floorMat = Enum.Material.Marble },
}

-- Rooms whose light flickers (picked by hand so the house has a rhythm, not noise).
local FLICKER_ROOMS = { [5] = true, [7] = true, [11] = true, [14] = true, [16] = true }
-- Rooms lit by a chandelier instead of a pendant lamp.
local CHANDELIER_ROOMS = { [1] = true, [2] = true, [10] = true }

---------------------------------------------------------------- primitives

local function box(parent, name, size, cf, color, material, collide)
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
local function placer(roomOrigin: Vector3)
	return function(x, y, z, yaw)
		return CFrame.new(roomOrigin + Vector3.new(x, y, z)) * CFrame.Angles(0, math.rad(yaw or 0), 0)
	end
end

local function light(parent, color, range, brightness, flicker)
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = brightness
	l.Shadows = false
	l.Parent = parent
	if flicker then
		CollectionService:AddTag(parent, "NightHunterFlicker")
	end
	return l
end

-- Yaw that turns a -Z-facing model so its front faces into the room from wall `side`.
local WALL_YAW = { N = 180, S = 0, W = -90, E = 90 }

local function library(): Folder?
	return ServerStorage:FindFirstChild("AssetLibrary")
end

local function sizeOf(name: string): Vector3
	local lib = library()
	local template = lib and lib:FindFirstChild(name)
	return (template and template:GetAttribute("Size")) or FALLBACK_SIZE[name] or Vector3.new(2, 2, 2)
end

-- Place a library prop with its bottom centre at room-local (x, y, z), turned by `yaw` degrees.
-- `scale` (optional) is uniform. Falls back to a box if the library does not have it.
local function prop(m, at, name: string, x: number, y: number, z: number, yaw: number, scale: number?)
	local lib = library()
	local template = lib and lib:FindFirstChild(name)
	local k = scale or 1
	if template then
		local c = template:Clone()
		if k ~= 1 then
			c:ScaleTo(c:GetScale() * k)
		end
		c:PivotTo(at(x, y, z, yaw + (ASSET_YAW[name] or 0)))
		c.Parent = m
		return c
	end
	local size = sizeOf(name) * k
	return box(m, name .. "Placeholder", size, at(x, y + size.Y / 2, z, yaw), WOOD, Enum.Material.Wood)
end

-- Stand a library prop against a wall: `along` is its position along that wall.
local function againstWall(m, at, name: string, side: string, along: number, scale: number?)
	local depth = sizeOf(name).Z * (scale or 1)
	local d = FACE - depth / 2 - 0.05
	local x = if side == "W" then -d elseif side == "E" then d else along
	local z = if side == "N" then -d elseif side == "S" then d else along
	return prop(m, at, name, x, 0, z, WALL_YAW[side], scale)
end

---------------------------------------------------------------- part-built furniture

local function table4(m, at, x, z, w, d, h, color)
	box(m, "Top", Vector3.new(w, 0.3, d), at(x, h, z), color, Enum.Material.Wood)
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			box(m, "Leg", Vector3.new(0.3, h, 0.3), at(x + sx * (w / 2 - 0.3), h / 2, z + sz * (d / 2 - 0.3)), color, Enum.Material.Wood)
		end
	end
end

local function rug(m, at, x, z, w, d, color)
	box(m, "Rug", Vector3.new(w, 0.06, d), at(x, 0.03, z), color, Enum.Material.Fabric, false)
	box(m, "RugBorder", Vector3.new(w - 0.8, 0.07, d - 0.8), at(x, 0.035, z), color:Lerp(Color3.new(0, 0, 0), 0.35), Enum.Material.Fabric, false)
end

local function painting(m, at, x, y, z, yaw, w, h, color)
	box(m, "Frame", Vector3.new(w, h, 0.2), at(x, y, z, yaw), BRASS, Enum.Material.Metal, false)
	box(m, "Canvas", Vector3.new(w - 0.5, h - 0.5, 0.22), at(x, y, z, yaw), color, Enum.Material.SmoothPlastic, false)
end

-- A painting hung on wall `side` at position `along`.
local function paintingOn(m, at, side, along, w, h, color)
	local d = FACE - 0.25
	local x = if side == "W" then -d elseif side == "E" then d else along
	local z = if side == "N" then -d elseif side == "S" then d else along
	local yaw = if side == "N" or side == "S" then 0 else 90
	painting(m, at, x, 6.5, z, yaw, w, h, color)
end

local function candle(m, at, x, y, z, withLight)
	box(m, "Candle", Vector3.new(0.3, 0.8, 0.3), at(x, y + 0.4, z), DIRTY_WHITE, Enum.Material.SmoothPlastic, false)
	local flame = box(m, "Flame", Vector3.new(0.15, 0.3, 0.15), at(x, y + 0.95, z), Color3.fromRGB(255, 170, 70), Enum.Material.Neon, false)
	if withLight then
		light(flame, WARM_LIGHT, 10, 0.8, true)
	end
end

-- A candelabra (library) with a warm flickering light on top.
local function candelabra(m, at, x, y, z, yaw)
	local c = prop(m, at, "Candelabra", x, y, z, yaw)
	local glow = box(m, "CandleGlow", Vector3.new(0.2, 0.2, 0.2), at(x, y + sizeOf("Candelabra").Y + 0.3, z), WARM_LIGHT, Enum.Material.Neon, false)
	glow.Transparency = 1
	light(glow, WARM_LIGHT, 12, 0.9, true)
	return c
end

local function boxes(m, at, x, z, seed)
	local rng = Random.new(seed)
	for i = 1, 5 do
		local s = rng:NextNumber(1.6, 3)
		box(m, "Box", Vector3.new(s, s * 0.8, s), at(x + rng:NextNumber(-0.8, 0.8), s * 0.4 + (if i > 3 then 1.6 else 0), z + (i % 3) * 1.4, rng:NextNumber(-20, 20)), Color3.fromRGB(150, 120, 80), Enum.Material.Cardboard)
	end
end

local function fireplace(m, at, side)
	local x = if side == "E" then 10.8 elseif side == "W" then -10.8 else 0
	local z = if side == "S" then 10.8 elseif side == "N" then -10.8 else 0
	local alongX = side == "N" or side == "S"
	local inward = if side == "E" then -1 elseif side == "W" then 1 elseif side == "S" then -1 else 1
	local function o(a, b) -- (inward offset, along offset) -> x, z
		return if alongX then x + b else x + a * inward, if alongX then z + a * inward else z + b
	end
	local fx, fz = o(0, 0)
	box(m, "Fireplace", if alongX then Vector3.new(7, 7, 1.6) else Vector3.new(1.6, 7, 7), at(fx, 3.5, fz), Color3.fromRGB(110, 100, 96), Enum.Material.Brick)
	local hx, hz = o(0.75, 0)
	box(m, "FireHole", if alongX then Vector3.new(3.6, 2.6, 0.4) else Vector3.new(0.4, 2.6, 3.6), at(hx, 1.4, hz), Color3.fromRGB(20, 16, 14), Enum.Material.SmoothPlastic, false)
	local ex, ez = o(0.9, 0)
	local embers = box(m, "Embers", if alongX then Vector3.new(3, 0.5, 0.6) else Vector3.new(0.6, 0.5, 3), at(ex, 0.4, ez), Color3.fromRGB(255, 90, 30), Enum.Material.Neon, false)
	light(embers, Color3.fromRGB(255, 120, 60), 16, 1.2, true)
	local mx, mz = o(0.5, 0)
	box(m, "Mantel", if alongX then Vector3.new(8, 0.4, 2.4) else Vector3.new(2.4, 0.4, 8), at(mx, 7.1, mz), WOOD_DARK, Enum.Material.Wood)
end

local function clock(m, at, x, z, yaw)
	box(m, "ClockBody", Vector3.new(2, 8, 1.6), at(x, 4, z, yaw), WOOD_DARK, Enum.Material.Wood)
	box(m, "ClockFace", Vector3.new(1.5, 1.5, 0.2), at(x, 0, z, yaw) * CFrame.new(0, 6.6, -0.85), DIRTY_WHITE, Enum.Material.SmoothPlastic, false)
	box(m, "Pendulum", Vector3.new(0.2, 2.5, 0.1), at(x, 0, z, yaw) * CFrame.new(0, 3.5, -0.85), BRASS, Enum.Material.Metal, false)
end

local function armchair(m, at, x, z, yaw, color)
	box(m, "ArmchairSeat", Vector3.new(2.8, 2, 2.8), at(x, 1, z, yaw), color, Enum.Material.Fabric)
	box(m, "ArmchairBack", Vector3.new(2.8, 2.4, 0.6), at(x, 0, z, yaw) * CFrame.new(0, 2.6, 1.1), color, Enum.Material.Fabric)
end

---------------------------------------------------------------- rooms

local ROOM_PROPS = {}

ROOM_PROPS[1] = function(m, at) -- Foyer (spawn). Doors E,S · wardrobe N · front door on the W wall
	box(m, "FrontDoor", Vector3.new(0.4, 8, 5), at(-11.3, 4, 0), WOOD_DARK, Enum.Material.Wood, false)
	box(m, "DoorKnob", Vector3.new(0.3, 0.3, 0.3), at(-11.05, 4, 1.7), BRASS, Enum.Material.Metal, false)
	rug(m, at, 0, 0, 9, 7, CLOTH_RED)
	againstWall(m, at, "Furniture_Drawer", "S", -7.5)
	candelabra(m, at, -7.5, sizeOf("Furniture_Drawer").Y, 10.2, 0)
	paintingOn(m, at, "N", -5, 3, 4, Color3.fromRGB(80, 90, 70))
	prop(m, at, "Cobwebs", -8.5, 10.5, -8.5, 0, 0.45)
end

ROOM_PROPS[2] = function(m, at) -- Grand Hall. Doors W,E,S · wardrobe N (west side)
	againstWall(m, at, "Furniture_Cabinet", "N", 6)
	box(m, "Pedestal", Vector3.new(1.4, 3, 1.4), at(2.5, 1.5, -10.4), DIRTY_WHITE, Enum.Material.Marble)
	candelabra(m, at, 2.5, 3, -10.4, 180)
	paintingOn(m, at, "S", -7, 4, 5, Color3.fromRGB(90, 60, 50))
	paintingOn(m, at, "S", 7, 4, 5, Color3.fromRGB(60, 60, 90))
	rug(m, at, 0, 0, 18, 5, CLOTH_RED)
	prop(m, at, "Cobwebs", 8.5, 10.5, 8.5, 90, 0.45)
end

ROOM_PROPS[3] = function(m, at) -- Library. Doors W,E · solid S wall · wardrobe S (east side)
	againstWall(m, at, "Furniture_Shelf", "S", -5)
	againstWall(m, at, "Furniture_Shelf", "N", 6, 0.9)
	-- reading table = hiding spot (hideSpots)
	prop(m, at, "Furniture_Chair", -6, 0, -10.1, 180)
	candelabra(m, at, -6, sizeOf("HideTable").Y, -6, 0)
	rug(m, at, -5.5, -5, 9, 8, CLOTH_GREEN)
end

ROOM_PROPS[4] = function(m, at) -- Study. Doors W,S · wardrobe E
	-- desk = hiding spot (hideSpots)
	prop(m, at, "Furniture_Chair", -5.5, 0, -4.2, 180)
	candelabra(m, at, -5.5, sizeOf("HideTable").Y, -8, 180)
	againstWall(m, at, "Furniture_Shelf", "N", 6, 0.8)
	againstWall(m, at, "Furniture_Cabinet", "W", -7)
	paintingOn(m, at, "W", 7, 3, 4, Color3.fromRGB(70, 50, 40))
end

ROOM_PROPS[5] = function(m, at) -- Storeroom. Doors N,E · solid S wall · wardrobe W
	againstWall(m, at, "Furniture_Shelf", "S", 2)
	boxes(m, at, 8, 4.5, 5)
	boxes(m, at, -8, 6, 55)
	againstWall(m, at, "Furniture_Drawer", "N", 7)
	prop(m, at, "Cobwebs", 8, 10.5, 8, 0, 0.5)
	prop(m, at, "Cobwebs", -8, 10.5, -8, 180, 0.45)
end

ROOM_PROPS[6] = function(m, at) -- Living room. Doors W,N,S · solid E wall (fireplace) · wardrobe N
	fireplace(m, at, "E")
	armchair(m, at, 5.4, -5, -90, CLOTH_RED)
	armchair(m, at, 5.4, 5, -90, CLOTH_RED)
	rug(m, at, 6, 0, 6, 10, CLOTH_BLUE)
	againstWall(m, at, "Furniture_Drawer", "S", -7.5)
	paintingOn(m, at, "W", -7, 4, 3, Color3.fromRGB(120, 90, 60))
end

ROOM_PROPS[7] = function(m, at) -- Gallery. Doors E,S · solid N and W walls · wardrobe W (south side)
	paintingOn(m, at, "N", -6, 4, 5, Color3.fromRGB(70, 40, 40))
	paintingOn(m, at, "N", 1, 3, 4, Color3.fromRGB(40, 50, 70))
	paintingOn(m, at, "N", 7.5, 3.5, 5, Color3.fromRGB(80, 70, 40))
	paintingOn(m, at, "W", -6, 4, 5, Color3.fromRGB(60, 30, 60))
	for _, z in { -7, 7 } do
		box(m, "Pedestal", Vector3.new(1.4, 3, 1.4), at(-5, 1.5, z), DIRTY_WHITE, Enum.Material.Marble)
		candelabra(m, at, -5, 3, z, 0)
	end
	rug(m, at, 0, 0, 6, 16, CLOTH_RED)
end

ROOM_PROPS[8] = function(m, at) -- Bedroom. Doors W,N,S · outer E · wardrobe E (north side)
	againstWall(m, at, "Furniture_Bed", "S", 6.5)
	againstWall(m, at, "Furniture_Drawer", "N", -7)
	prop(m, at, "Furniture_Chair", -8.5, 0, 6, 90)
	candle(m, at, -7, sizeOf("Furniture_Drawer").Y, -10.3, true)
	paintingOn(m, at, "W", -7, 3, 3, Color3.fromRGB(90, 70, 80))
end

ROOM_PROPS[9] = function(m, at) -- Kitchen. Doors E,S · solid N wall · outer W · wardrobe W (south side)
	box(m, "CounterN", Vector3.new(14, 3.2, 2.4), at(1, 1.6, -10.3), DIRTY_WHITE, Enum.Material.SmoothPlastic)
	box(m, "CounterTop", Vector3.new(14.2, 0.3, 2.6), at(1, 3.3, -10.3), Color3.fromRGB(60, 60, 64), Enum.Material.Granite, false)
	box(m, "Sink", Vector3.new(2.2, 0.2, 1.6), at(3, 3.46, -10.2), METAL, Enum.Material.Metal, false)
	box(m, "Stove", Vector3.new(2.6, 3.2, 2.4), at(-8, 1.6, -10.3), METAL, Enum.Material.Metal)
	box(m, "Fridge", Vector3.new(3, 7, 2.6), at(10, 3.5, -10), Color3.fromRGB(200, 205, 200), Enum.Material.SmoothPlastic)
	-- kitchen table = hiding spot (hideSpots)
	prop(m, at, "Furniture_Chair", 3.2, 0, 6, -90)
	prop(m, at, "Furniture_Chair", 10.8, 0, 6, 90)
end

ROOM_PROPS[10] = function(m, at) -- Dining room. Doors W,E,N,S · wardrobe S (east side)
	-- dining table = hiding spot (hideSpots)
	prop(m, at, "Furniture_Chair", -10, 0, -6.5, -90)
	prop(m, at, "Furniture_Chair", -2.7, 0, -6.5, 90)
	candelabra(m, at, -6.5, sizeOf("HideTable").Y, -6.5, 0)
	againstWall(m, at, "Furniture_Cabinet", "E", -7)
	paintingOn(m, at, "W", 7, 3, 3, Color3.fromRGB(70, 60, 50))
end

ROOM_PROPS[11] = function(m, at) -- Hallway. Doors W,E,N,S · wardrobe E (south side)
	clock(m, at, -9.5, -10.2, 0)
	paintingOn(m, at, "N", 7, 3, 4, Color3.fromRGB(80, 60, 50))
	paintingOn(m, at, "W", 7, 3, 4, Color3.fromRGB(50, 60, 80))
	rug(m, at, 0, 0, 20, 4, CLOTH_RED)
	rug(m, at, 0, 0, 4, 20, CLOTH_RED)
	prop(m, at, "Cobwebs", -8.5, 10.5, 8.5, 270, 0.45)
end

ROOM_PROPS[12] = function(m, at) -- Master bedroom. Doors W,N,S · outer E · wardrobe E (north side)
	againstWall(m, at, "Furniture_Bed", "S", 6.5, 1.1)
	againstWall(m, at, "Furniture_Drawer", "N", -7)
	againstWall(m, at, "Furniture_Cabinet", "W", 7)
	box(m, "Mirror", Vector3.new(3, 3.5, 0.2), at(-7, 6, -11.35), Color3.fromRGB(150, 170, 180), Enum.Material.Glass, false)
	candelabra(m, at, -9, sizeOf("Furniture_Drawer").Y, -10.3, 180)
	rug(m, at, 6.5, 2, 7, 6, CLOTH_BLUE)
end

ROOM_PROPS[13] = function(m, at) -- Pantry. Doors N,E · outer W,S · wardrobe S (west side)
	againstWall(m, at, "Furniture_Shelf", "W", -5, 0.9)
	againstWall(m, at, "Furniture_Shelf", "S", 5, 0.9)
	for i, x in { 5.5, 8, 10.2 } do
		local barrel = box(m, "Barrel", Vector3.new(3, 2.4, 2.4), at(x, 1.5, -10) * CFrame.Angles(0, 0, math.pi / 2), WOOD, Enum.Material.Wood)
		barrel.Shape = Enum.PartType.Cylinder
		barrel.Name = "Barrel" .. i
	end
	boxes(m, at, 6, 4.5, 13)
	prop(m, at, "Cobwebs", 8, 10.5, 8, 0, 0.5)
end

ROOM_PROPS[14] = function(m, at) -- Servants' room. Doors N,W · solid E wall · outer S · wardrobe S (east side)
	againstWall(m, at, "Furniture_Bed", "E", -5)
	prop(m, at, "Furniture_Chair", -8.5, 0, -8, 90)
	table4(m, at, -6, -9.8, 3, 2, 2.6, WOOD)
	candle(m, at, -6, 2.75, -9.8, true)
	prop(m, at, "Cobwebs", -8.5, 10.5, 8.5, 0, 0.45)
end

ROOM_PROPS[15] = function(m, at) -- Nursery. Doors N,E · solid W wall · outer S · wardrobe S (west side)
	box(m, "CribBase", Vector3.new(2.6, 1.2, 4.2), at(-10, 1.8, -6), WOOD_LIGHT, Enum.Material.Wood)
	for i = 0, 8 do
		box(m, "CribBar", Vector3.new(0.15, 2.4, 0.15), at(-8.8, 3.6, -7.9 + i * 0.47), WOOD_LIGHT, Enum.Material.Wood, false)
	end
	box(m, "HorseBody", Vector3.new(1, 1.4, 2.8), at(6, 2.2, -6), Color3.fromRGB(180, 150, 120), Enum.Material.Wood)
	box(m, "HorseHead", Vector3.new(0.9, 1.6, 1), at(6, 3.4, -7.1), Color3.fromRGB(180, 150, 120), Enum.Material.Wood)
	box(m, "Rocker", Vector3.new(0.4, 0.5, 4), at(6, 0.6, -6), WOOD_DARK, Enum.Material.Wood)
	for i = 1, 4 do
		box(m, "Block", Vector3.new(0.8, 0.8, 0.8), at(3 + i * 0.9, 0.4, 7.5 - (i % 2)), ({ CLOTH_RED, CLOTH_BLUE, BRASS, CLOTH_GREEN })[i], Enum.Material.SmoothPlastic)
	end
	againstWall(m, at, "Furniture_Drawer", "W", 4.5)
end

ROOM_PROPS[16] = function(m, at) -- Bathroom. Doors W,N · outer E,S · wardrobe E (north side)
	againstWall(m, at, "Bathtub", "S", -6.5)
	box(m, "Vanity", Vector3.new(4, 3.2, 2), at(-7, 1.6, -10.4), DIRTY_WHITE, Enum.Material.SmoothPlastic)
	box(m, "Basin", Vector3.new(2, 0.3, 1.4), at(-7, 3.35, -10.2), Color3.fromRGB(220, 220, 215), Enum.Material.SmoothPlastic, false)
	box(m, "Mirror", Vector3.new(3, 3.5, 0.2), at(-7, 6, -11.35), Color3.fromRGB(150, 170, 180), Enum.Material.Glass, false)
	box(m, "Toilet", Vector3.new(1.8, 1.8, 2.4), at(9.8, 0.9, 9.6), DIRTY_WHITE, Enum.Material.SmoothPlastic)
	box(m, "ToiletTank", Vector3.new(1.8, 1.6, 0.8), at(9.8, 2.6, 10.8), DIRTY_WHITE, Enum.Material.SmoothPlastic)
end

---------------------------------------------------------------- shared finishes

-- Which wall sides of a room have a door, and which are outer walls.
local function sides(graph, room)
	local cols, rows = HouseGraph.COLS, HouseGraph.ROWS
	local index = room - 1
	local col, row = index % cols, index // cols
	return {
		N = { name = "N", door = row > 0 and HouseGraph.hasDoor(graph, room, room - cols), outer = row == 0, axisX = true, sign = -1 },
		S = { name = "S", door = row < rows - 1 and HouseGraph.hasDoor(graph, room, room + cols), outer = row == rows - 1, axisX = true, sign = 1 },
		W = { name = "W", door = col > 0 and HouseGraph.hasDoor(graph, room, room - 1), outer = col == 0, axisX = false, sign = -1 },
		E = { name = "E", door = col < cols - 1 and HouseGraph.hasDoor(graph, room, room + 1), outer = col == cols - 1, axisX = false, sign = 1 },
	}
end

-- Wallpaper + dark wainscot + rail on every inner face, with a gap where a door is.
local function finishWalls(m, at, theme, side)
	local face = 11.45
	local function strip(name, y, height, depth, color, material)
		local pieces = if side.door then { { -7.5, 9 }, { 7.5, 9 } } else { { 0, 23 } }
		for _, piece in pieces do
			local offset, length = piece[1], piece[2]
			local size = if side.axisX then Vector3.new(length, height, depth) else Vector3.new(depth, height, length)
			local x = if side.axisX then offset else side.sign * face
			local z = if side.axisX then side.sign * face else offset
			box(m, name, size, at(x, y, z), color, material, false)
		end
	end
	strip("Wallpaper", 7.5, 9, 0.1, theme.wall, Enum.Material.Fabric)
	strip("Wainscot", 1.5, 3, 0.25, WOOD_DARK, Enum.Material.Wood)
	strip("Rail", 3.05, 0.2, 0.35, WOOD_LIGHT, Enum.Material.Wood)
end

local function windowOn(m, at, side)
	local face = 11.35
	local x = if side.axisX then 0 else side.sign * face
	local z = if side.axisX then side.sign * face else 0
	local yaw = if side.axisX then 0 else 90
	box(m, "WindowFrame", Vector3.new(5.4, 4.4, 0.3), at(x, 6.5, z, yaw), WOOD_DARK, Enum.Material.Wood, false)
	local glass = box(m, "WindowGlass", Vector3.new(4.6, 3.6, 0.35), at(x, 6.5, z, yaw), Color3.fromRGB(30, 40, 70), Enum.Material.Neon, false)
	glass.Transparency = 0.35
	box(m, "WindowBarV", Vector3.new(0.2, 3.6, 0.4), at(x, 6.5, z, yaw), WOOD_DARK, Enum.Material.Wood, false)
	box(m, "WindowBarH", Vector3.new(4.6, 0.2, 0.4), at(x, 6.5, z, yaw), WOOD_DARK, Enum.Material.Wood, false)
	local beam = Instance.new("SpotLight")
	beam.Color = MOON_LIGHT
	beam.Range = 20
	beam.Brightness = 1.2
	beam.Angle = 60
	beam.Face = Enum.NormalId.Front
	beam.Parent = glass
	-- Front of the glass must face into the room.
	glass.CFrame = CFrame.lookAt(glass.Position, glass.Position - (if side.axisX then Vector3.new(0, 0, side.sign) else Vector3.new(side.sign, 0, 0)))
end

local function ceilingLight(m, at, room)
	if CHANDELIER_ROOMS[room] then
		local h = sizeOf("Chandelier").Y * 0.6
		prop(m, at, "Chandelier", 0, 12 - h, 0, 0, 0.6)
		local glow = box(m, "ChandelierGlow", Vector3.new(0.2, 0.2, 0.2), at(0, 12 - h * 0.5, 0), WARM_LIGHT, Enum.Material.Neon, false)
		glow.Transparency = 1
		light(glow, WARM_LIGHT, 22, 0.9, FLICKER_ROOMS[room])
		return
	end
	box(m, "LampCord", Vector3.new(0.1, 1.6, 0.1), at(0, 11.2, 0), Color3.fromRGB(20, 20, 20), Enum.Material.SmoothPlastic, false)
	local shade = box(m, "LampShade", Vector3.new(1, 2.4, 2.4), at(0, 10.1, 0) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(70, 52, 36), Enum.Material.Fabric, false)
	shade.Shape = Enum.PartType.Cylinder
	local bulb = box(m, "Bulb", Vector3.new(0.6, 0.6, 0.6), at(0, 9.45, 0), Color3.fromRGB(255, 170, 90), Enum.Material.Neon, false)
	bulb.Shape = Enum.PartType.Ball
	light(bulb, WARM_LIGHT, 18, 0.7, FLICKER_ROOMS[room])
end

-- Hiding spots: one per hide node. A wardrobe with doors (opening into the room) or a table
-- with a long cloth. Each gets marker parts HideService uses:
--   PromptPart  where the "Hide" prompt sits     Inside  where the hidden player is kept
--   Eye         the camera while hidden (looking out through the door gap / under the cloth)
-- Doors (DoorL / DoorR, pivot = hinge) and the cloth are animated by HideService.
HouseDecor.HIDE_TAG = "NightHunterHideSpot"

local function marker(parent, name, cf)
	local p = box(parent, name, Vector3.new(0.4, 0.4, 0.4), cf, Color3.new(1, 1, 1), Enum.Material.SmoothPlastic, false)
	p.Transparency = 1
	p.CanQuery = false
	p.CanTouch = false
	return p
end

local function hideSpots(decor, graph, origin)
	for _, node in graph.nodes do
		if node.kind == "hide" then
			local at = placer(origin + HouseGraph.roomCenter(node.room))
			local rel = node.pos - HouseGraph.roomCenter(node.room)
			local spot
			if node.spot == "table" then
				spot = prop(decor, at, "HideTable", rel.X, 0, rel.Z, 0)
				local pivot = spot:GetPivot()
				marker(spot, "PromptPart", pivot * CFrame.new(0, 2, 0))
				marker(spot, "Inside", pivot * CFrame.new(0, 1, 0))
				-- Low, at the cloth's edge, looking out under it.
				marker(spot, "Eye", pivot * CFrame.new(0, 0.55, -sizeOf("HideTable").Z / 2 - 0.15))
			else
				local depth = sizeOf("HideWardrobe").Z
				local side = node.wall or "N"
				local x = if side == "W" then -(FACE - depth / 2 - 0.05) elseif side == "E" then FACE - depth / 2 - 0.05 else rel.X
				local z = if side == "N" then -(FACE - depth / 2 - 0.05) elseif side == "S" then FACE - depth / 2 - 0.05 else rel.Z
				spot = prop(decor, at, "HideWardrobe", x, 0, z, WALL_YAW[side])
				local pivot = spot:GetPivot()
				marker(spot, "PromptPart", pivot * CFrame.new(0, 3.5, -depth / 2 - 0.6))
				marker(spot, "Inside", pivot * CFrame.new(0, 3, 0))
				-- At the gap between the doors, eye height, looking into the room.
				marker(spot, "Eye", pivot * CFrame.new(0, 5.2, -depth / 2 - 0.12))
			end
			spot.Name = "HideSpot" .. node.id
			spot:SetAttribute("Node", node.id)
			spot:SetAttribute("Kind", node.spot)
			CollectionService:AddTag(spot, HouseDecor.HIDE_TAG)
		end
	end
end

function HouseDecor.decorate(root: Instance, graph, origin: Vector3)
	local decor = Instance.new("Folder")
	decor.Name = "Decor"
	for room = 1, graph.roomCount do
		local theme = HouseDecor.THEMES[room]
		local at = placer(origin + HouseGraph.roomCenter(room))
		local m = Instance.new("Model")
		m.Name = theme.name
		local s = sides(graph, room)
		for _, key in { "N", "S", "E", "W" } do
			finishWalls(m, at, theme, s[key])
			if s[key].outer and not (theme.noWindow and theme.noWindow[key]) then
				windowOn(m, at, s[key])
			end
		end
		box(m, "Ceiling", Vector3.new(24, 1, 24), at(0, 12.5, 0), Color3.fromRGB(60, 56, 54), Enum.Material.Plaster)
		ceilingLight(m, at, room)
		ROOM_PROPS[room](m, at)
		m.Parent = decor
	end
	hideSpots(decor, graph, origin)
	decor.Parent = root
end

-- The hunter's nest for tonight: candles in a ring, a pile of rags, a red glow.
function HouseDecor.lair(parent: Instance, origin: Vector3, room: number): Instance
	local m = Instance.new("Model")
	m.Name = "Lair"
	local at = placer(origin + HouseGraph.roomCenter(room))
	local rng = Random.new(room)
	for i = 1, 8 do
		local a = (i / 8) * math.pi * 2
		candle(m, at, math.cos(a) * 4.5, 0, math.sin(a) * 4.5, false)
	end
	for _ = 1, 7 do
		box(m, "Rags", Vector3.new(rng:NextNumber(1.5, 3), 0.5, rng:NextNumber(1.5, 3)), at(rng:NextNumber(-1.8, 1.8), 0.25, rng:NextNumber(-1.8, 1.8), rng:NextNumber(0, 180)), Color3.fromRGB(35, 28, 26), Enum.Material.Fabric, false)
	end
	for i = 1, 4 do
		box(m, "Scratch", Vector3.new(0.15, 0.02, 3), at(-2.2 + i * 0.5, 0.07, -6, 15), Color3.fromRGB(90, 20, 20), Enum.Material.SmoothPlastic, false)
	end
	local glow = box(m, "Glow", Vector3.new(0.5, 0.5, 0.5), at(0, 2, 0), Color3.fromRGB(255, 40, 40), Enum.Material.Neon, false)
	glow.Transparency = 1
	light(glow, Color3.fromRGB(255, 50, 40), 18, 1.5, true)
	m.Parent = parent
	return m
end

return HouseDecor
