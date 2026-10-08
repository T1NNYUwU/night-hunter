--!nonstrict
-- Furniture, wall finishes, windows and lights for the house: an abandoned family home at night.
-- Everything is built from parts (no third-party models), placed per room in room-local
-- coordinates (room centre = 0,0,0, floor top = y 0, inner wall faces at ±11.5).
-- Props hug the walls and stay out of the central "+" (room centre ↔ doors), which is
-- where players and the hunter walk, and out of each room's closet corner.

local CollectionService = game:GetService("CollectionService")

local HouseGraph = require(game:GetService("ReplicatedStorage"):WaitForChild("NightHunter"):WaitForChild("HouseGraph"))

local HouseDecor = {}
HouseDecor.VERSION = 3 -- bump when decor changes, so saved houses get rebuilt

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

HouseDecor.THEMES = {
	[1] = { name = "Foyer", wall = Color3.fromRGB(78, 62, 58), floor = Color3.fromRGB(70, 66, 62), floorMat = Enum.Material.Marble },
	[2] = { name = "Library", wall = Color3.fromRGB(52, 66, 56), floor = WOOD, floorMat = Enum.Material.WoodPlanks },
	[3] = { name = "Bedroom", wall = Color3.fromRGB(86, 70, 92), floor = WOOD_LIGHT, floorMat = Enum.Material.WoodPlanks },
	[4] = { name = "Living room", wall = Color3.fromRGB(84, 54, 50), floor = WOOD, floorMat = Enum.Material.WoodPlanks },
	[5] = { name = "Hall", wall = Color3.fromRGB(80, 74, 60), floor = WOOD_DARK, floorMat = Enum.Material.WoodPlanks },
	[6] = { name = "Kitchen", wall = Color3.fromRGB(118, 114, 96), floor = Color3.fromRGB(150, 150, 140), floorMat = Enum.Material.Slate },
	[7] = { name = "Dining room", wall = Color3.fromRGB(70, 52, 70), floor = WOOD, floorMat = Enum.Material.WoodPlanks },
	[8] = { name = "Bathroom", wall = Color3.fromRGB(86, 108, 106), floor = Color3.fromRGB(170, 175, 172), floorMat = Enum.Material.Marble },
	[9] = { name = "Nursery", wall = Color3.fromRGB(120, 100, 82), floor = WOOD_LIGHT, floorMat = Enum.Material.WoodPlanks },
}

-- Rooms whose ceiling lamp flickers (picked by hand so the house has a rhythm, not noise).
local FLICKER_ROOMS = { [3] = true, [5] = true, [8] = true }

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

---------------------------------------------------------------- reusable furniture

local function table4(m, at, x, z, w, d, h, color)
	box(m, "Top", Vector3.new(w, 0.3, d), at(x, h, z), color, Enum.Material.Wood)
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			box(m, "Leg", Vector3.new(0.3, h, 0.3), at(x + sx * (w / 2 - 0.3), h / 2, z + sz * (d / 2 - 0.3)), color, Enum.Material.Wood)
		end
	end
end

local function chair(m, at, x, z, yaw, color)
	box(m, "Seat", Vector3.new(1.6, 0.25, 1.6), at(x, 1.6, z, yaw), color, Enum.Material.Wood)
	box(m, "Back", Vector3.new(1.6, 2, 0.25), at(x, 2.7, z, yaw) * CFrame.new(0, 0, 0.7), color, Enum.Material.Wood)
	for _, sx in { -0.65, 0.65 } do
		for _, sz in { -0.65, 0.65 } do
			box(m, "Leg", Vector3.new(0.2, 1.6, 0.2), at(x, 0.8, z, yaw) * CFrame.new(sx, 0, sz), color, Enum.Material.Wood)
		end
	end
end

local function bookshelf(m, at, x, z, yaw, width)
	box(m, "Frame", Vector3.new(width, 9, 1.4), at(x, 4.5, z, yaw), WOOD_DARK, Enum.Material.Wood)
	local rng = Random.new(math.floor(x * 31 + z * 17))
	local books = { CLOTH_RED, CLOTH_GREEN, CLOTH_BLUE, BRASS, DIRTY_WHITE, WOOD_LIGHT }
	for shelf = 0, 3 do
		local cursor = -width / 2 + 0.4
		while cursor < width / 2 - 0.6 do
			local bw = rng:NextNumber(0.25, 0.5)
			local bh = rng:NextNumber(1.2, 1.8)
			box(m, "Book", Vector3.new(bw, bh, 1), at(x, 0, z, yaw) * CFrame.new(cursor + bw / 2, 0.8 + shelf * 2.1 + bh / 2, -0.3), books[rng:NextInteger(1, #books)], Enum.Material.Fabric, false)
			cursor += bw + rng:NextNumber(0.02, 0.15)
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

local function candle(m, at, x, y, z, withLight)
	box(m, "Candle", Vector3.new(0.3, 0.8, 0.3), at(x, y + 0.4, z), DIRTY_WHITE, Enum.Material.SmoothPlastic, false)
	local flame = box(m, "Flame", Vector3.new(0.15, 0.3, 0.15), at(x, y + 0.95, z), Color3.fromRGB(255, 170, 70), Enum.Material.Neon, false)
	if withLight then
		light(flame, WARM_LIGHT, 10, 0.8, true)
	end
end

---------------------------------------------------------------- per-room furniture

local ROOM_PROPS = {}

ROOM_PROPS[1] = function(m, at) -- Foyer (spawn): doors E,S · closet NW · front door on the W wall
	box(m, "FrontDoor", Vector3.new(0.4, 8, 5), at(-11.3, 4, 0), WOOD_DARK, Enum.Material.Wood, false)
	box(m, "DoorKnob", Vector3.new(0.3, 0.3, 0.3), at(-11.05, 4, 1.7), BRASS, Enum.Material.Metal, false)
	rug(m, at, 0, 0, 9, 7, CLOTH_RED)
	box(m, "Bench", Vector3.new(5, 1.6, 1.6), at(6, 0.8, -10.3), WOOD, Enum.Material.Wood)
	box(m, "CoatRack", Vector3.new(0.4, 6, 0.4), at(9.8, 3, 9.8), WOOD_DARK, Enum.Material.Wood)
	box(m, "Coat", Vector3.new(1.4, 2.6, 0.6), at(9.8, 4.3, 9.3), CLOTH_GREEN, Enum.Material.Fabric, false)
	box(m, "UmbrellaStand", Vector3.new(1.2, 2, 1.2), at(-9.8, 1, 9.8), METAL, Enum.Material.Metal)
	painting(m, at, -5, 6.5, 11.25, 0, 3, 4, Color3.fromRGB(80, 90, 70))
end

ROOM_PROPS[2] = function(m, at) -- Library: doors W,E · closet NE · solid S wall
	bookshelf(m, at, -5.5, 10.6, 180, 8)
	bookshelf(m, at, 5.5, 10.6, 180, 8)
	table4(m, at, -7.5, -8.5, 4.5, 2.4, 2.8, WOOD_DARK)
	chair(m, at, -7.5, -6.6, 0, WOOD)
	local lamp = box(m, "DeskLamp", Vector3.new(0.5, 0.6, 0.5), at(-6, 3.25, -9), Color3.fromRGB(255, 170, 90), Enum.Material.Neon, false)
	light(lamp, WARM_LIGHT, 12, 0.7, false)
	box(m, "BookPile", Vector3.new(1.2, 1, 0.9), at(-8.6, 3.45, -8.8), CLOTH_RED, Enum.Material.Fabric, false)
	rug(m, at, 0, 0, 8, 6, CLOTH_GREEN)
end

ROOM_PROPS[3] = function(m, at) -- Bedroom: doors W,S · closet NE
	box(m, "BedFrame", Vector3.new(5.5, 1.6, 8), at(8.2, 0.8, 6.6), WOOD_DARK, Enum.Material.Wood)
	box(m, "Mattress", Vector3.new(5, 0.9, 7.4), at(8.2, 2, 6.8), DIRTY_WHITE, Enum.Material.Fabric)
	box(m, "Blanket", Vector3.new(5.1, 0.3, 4.5), at(8.2, 2.5, 8.2), Color3.fromRGB(96, 60, 98), Enum.Material.Fabric, false)
	box(m, "Pillow", Vector3.new(3.2, 0.6, 1.4), at(8.2, 2.7, 3.7), DIRTY_WHITE, Enum.Material.Fabric, false)
	box(m, "Headboard", Vector3.new(5.5, 4, 0.5), at(8.2, 2, 2.6), WOOD_DARK, Enum.Material.Wood)
	box(m, "Dresser", Vector3.new(6, 3.6, 2), at(-6.5, 1.8, -10.4), WOOD, Enum.Material.Wood)
	box(m, "Mirror", Vector3.new(3, 3.5, 0.2), at(-6.5, 5.6, -11.3), Color3.fromRGB(150, 170, 180), Enum.Material.Glass, false)
	box(m, "Nightstand", Vector3.new(1.8, 2.2, 1.8), at(-9.8, 1.1, 9.8), WOOD, Enum.Material.Wood)
	candle(m, at, -9.8, 2.2, 9.8, true)
end

ROOM_PROPS[4] = function(m, at) -- Living room: doors N,E,S · closet SW · fireplace on the W wall
	box(m, "Fireplace", Vector3.new(1.6, 7, 7), at(-10.8, 3.5, -1), Color3.fromRGB(110, 100, 96), Enum.Material.Brick)
	box(m, "FireHole", Vector3.new(0.4, 2.6, 3.6), at(-10.05, 1.4, -1), Color3.fromRGB(20, 16, 14), Enum.Material.SmoothPlastic, false)
	local embers = box(m, "Embers", Vector3.new(0.6, 0.5, 3), at(-9.9, 0.4, -1), Color3.fromRGB(255, 90, 30), Enum.Material.Neon, false)
	light(embers, Color3.fromRGB(255, 120, 60), 16, 1.2, true)
	box(m, "Mantel", Vector3.new(2.4, 0.4, 8), at(-10.3, 7.1, -1), WOOD_DARK, Enum.Material.Wood)
	box(m, "Armchair", Vector3.new(2.8, 2, 2.8), at(-5.4, 1, -5), CLOTH_RED, Enum.Material.Fabric)
	box(m, "ArmchairBack", Vector3.new(0.6, 2.4, 2.8), at(-4.3, 2.6, -5), CLOTH_RED, Enum.Material.Fabric)
	box(m, "Armchair", Vector3.new(2.8, 2, 2.8), at(-5.4, 1, 3.4), CLOTH_RED, Enum.Material.Fabric)
	box(m, "ArmchairBack", Vector3.new(0.6, 2.4, 2.8), at(-4.3, 2.6, 3.4), CLOTH_RED, Enum.Material.Fabric)
	rug(m, at, -6.5, -1, 6, 9, CLOTH_BLUE)
	box(m, "Cabinet", Vector3.new(1.8, 4, 5), at(10.4, 2, 7.5), WOOD, Enum.Material.Wood)
	painting(m, at, 8, 6.5, -11.25, 0, 4, 3, Color3.fromRGB(120, 90, 60))
end

ROOM_PROPS[5] = function(m, at) -- Hall: doors W,E,S · solid N wall · closets NW + SE
	box(m, "ClockBody", Vector3.new(2, 8, 1.6), at(4, 4, -10.6), WOOD_DARK, Enum.Material.Wood)
	box(m, "ClockFace", Vector3.new(1.5, 1.5, 0.2), at(4, 6.6, -9.75), DIRTY_WHITE, Enum.Material.SmoothPlastic, false)
	box(m, "Pendulum", Vector3.new(0.2, 2.5, 0.1), at(4, 3.5, -9.75), BRASS, Enum.Material.Metal, false)
	painting(m, at, -1.5, 6.5, -11.25, 0, 3, 4, Color3.fromRGB(70, 60, 90))
	painting(m, at, 8.5, 6.5, -11.25, 0, 2.5, 3, Color3.fromRGB(90, 70, 60))
	rug(m, at, 0, 0, 16, 4.5, CLOTH_RED)
	box(m, "Bench", Vector3.new(1.6, 1.6, 4.5), at(-10.3, 0.8, 7), WOOD, Enum.Material.Wood)
end

ROOM_PROPS[6] = function(m, at) -- Kitchen: doors N,W,S · closet SE · window on the E wall
	box(m, "CounterE", Vector3.new(2.4, 3.2, 7), at(10.3, 1.6, -7.5), DIRTY_WHITE, Enum.Material.SmoothPlastic)
	box(m, "CounterN", Vector3.new(5.5, 3.2, 2.4), at(8.2, 1.6, -10.3), DIRTY_WHITE, Enum.Material.SmoothPlastic)
	box(m, "CounterTop", Vector3.new(2.6, 0.3, 7.2), at(10.3, 3.3, -7.5), Color3.fromRGB(60, 60, 64), Enum.Material.Granite, false)
	box(m, "Sink", Vector3.new(1.6, 0.2, 2.2), at(10.3, 3.46, -6), METAL, Enum.Material.Metal, false)
	box(m, "Fridge", Vector3.new(3, 7, 2.6), at(-9.8, 3.5, -10), Color3.fromRGB(200, 205, 200), Enum.Material.SmoothPlastic)
	box(m, "Stove", Vector3.new(2.4, 3.2, 2.4), at(4.2, 1.6, -10.3), METAL, Enum.Material.Metal)
	table4(m, at, -7, 7, 4, 3, 2.8, WOOD_LIGHT)
	chair(m, at, -7, 4.6, 180, WOOD)
	chair(m, at, -4.4, 7, 90, WOOD)
	box(m, "Plate", Vector3.new(0.9, 0.08, 0.9), at(-7.5, 2.99, 6.6), DIRTY_WHITE, Enum.Material.SmoothPlastic, false)
end

ROOM_PROPS[7] = function(m, at) -- Dining room: doors N,E · closet SW
	table4(m, at, 7, 7, 4, 7, 3, WOOD_DARK)
	box(m, "TableCloth", Vector3.new(4.3, 0.05, 7.3), at(7, 3.2, 7), Color3.fromRGB(150, 140, 125), Enum.Material.Fabric, false)
	chair(m, at, 4.5, 5, -90, WOOD)
	chair(m, at, 4.5, 9, -90, WOOD)
	chair(m, at, 9.5, 5, 90, WOOD)
	candle(m, at, 7, 3.2, 6, true)
	candle(m, at, 7, 3.2, 8, false)
	box(m, "Hutch", Vector3.new(1.8, 8, 6), at(-10.4, 4, -6.5), WOOD, Enum.Material.Wood)
	box(m, "HutchGlass", Vector3.new(0.2, 3.5, 5), at(-9.45, 5.8, -6.5), Color3.fromRGB(140, 160, 170), Enum.Material.Glass, false)
end

ROOM_PROPS[8] = function(m, at) -- Bathroom: doors W,N,E · closet SE
	box(m, "Tub", Vector3.new(7, 2.4, 3.4), at(-6.5, 1.2, 9.6), DIRTY_WHITE, Enum.Material.SmoothPlastic)
	box(m, "TubWater", Vector3.new(6.2, 0.2, 2.6), at(-6.5, 2.2, 9.6), Color3.fromRGB(90, 110, 100), Enum.Material.Glass, false)
	box(m, "Vanity", Vector3.new(4, 3.2, 2), at(7, 1.6, -10.4), DIRTY_WHITE, Enum.Material.SmoothPlastic)
	box(m, "Basin", Vector3.new(2, 0.3, 1.4), at(7, 3.35, -10.2), Color3.fromRGB(220, 220, 215), Enum.Material.SmoothPlastic, false)
	box(m, "Mirror", Vector3.new(3, 3.5, 0.2), at(7, 6, -11.35), Color3.fromRGB(150, 170, 180), Enum.Material.Glass, false)
	box(m, "Toilet", Vector3.new(1.8, 1.8, 2.4), at(-9.8, 0.9, -9.6), DIRTY_WHITE, Enum.Material.SmoothPlastic)
	box(m, "ToiletTank", Vector3.new(1.8, 1.6, 0.8), at(-9.8, 2.6, -10.8), DIRTY_WHITE, Enum.Material.SmoothPlastic)
end

ROOM_PROPS[9] = function(m, at) -- Nursery: doors W,N · closet SE
	box(m, "CribBase", Vector3.new(4.2, 1.2, 2.6), at(7.5, 1.8, -10), WOOD_LIGHT, Enum.Material.Wood)
	for i = 0, 8 do
		box(m, "CribBar", Vector3.new(0.15, 2.4, 0.15), at(5.6 + i * 0.47, 3.6, -8.8), WOOD_LIGHT, Enum.Material.Wood, false)
	end
	box(m, "HorseBody", Vector3.new(1, 1.4, 2.8), at(-7, 2.2, 7), Color3.fromRGB(180, 150, 120), Enum.Material.Wood)
	box(m, "HorseHead", Vector3.new(0.9, 1.6, 1), at(-7, 3.4, 5.9), Color3.fromRGB(180, 150, 120), Enum.Material.Wood)
	box(m, "Rocker", Vector3.new(0.4, 0.5, 4), at(-7, 0.6, 7), WOOD_DARK, Enum.Material.Wood)
	local rng = Random.new(9)
	for i = 1, 5 do
		local s = rng:NextNumber(1.6, 3)
		box(m, "Box", Vector3.new(s, s * 0.8, s), at(-9.6 + rng:NextNumber(-0.6, 0.6), s * 0.4 + (i > 3 and 1.6 or 0), -9.6 + (i % 3) * 1.4, rng:NextNumber(-20, 20)), Color3.fromRGB(150, 120, 80), Enum.Material.Cardboard)
	end
	for i = 1, 4 do
		box(m, "Block", Vector3.new(0.8, 0.8, 0.8), at(-3 + i * 0.9, 0.4, 9.5 - (i % 2)), ({ CLOTH_RED, CLOTH_BLUE, BRASS, CLOTH_GREEN })[i], Enum.Material.SmoothPlastic)
	end
end

---------------------------------------------------------------- shared finishes

local function hasDoor(graph, a, b)
	for _, door in graph.doors do
		if (door[1] == a and door[2] == b) or (door[1] == b and door[2] == a) then
			return true
		end
	end
	return false
end

-- Which wall sides of a room have a door, and which are outer walls.
local function sides(graph, room)
	local index = room - 1
	local col, row = index % 3, index // 3
	return {
		N = { door = row > 0 and hasDoor(graph, room, room - 3), outer = row == 0, axisX = true, sign = -1 },
		S = { door = row < 2 and hasDoor(graph, room, room + 3), outer = row == 2, axisX = true, sign = 1 },
		W = { door = col > 0 and hasDoor(graph, room, room - 1), outer = col == 0, axisX = false, sign = -1 },
		E = { door = col < 2 and hasDoor(graph, room, room + 1), outer = col == 2, axisX = false, sign = 1 },
	}
end

-- Wallpaper + dark wainscot + baseboard on every inner face, with a gap where a door is.
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

function HouseDecor.decorate(root: Instance, graph, origin: Vector3)
	local decor = Instance.new("Folder")
	decor.Name = "Decor"
	for room = 1, graph.roomCount do
		local theme = HouseDecor.THEMES[room]
		local roomOrigin = origin + HouseGraph.roomCenter(room)
		local at = placer(roomOrigin)
		local m = Instance.new("Model")
		m.Name = theme.name
		for _, side in sides(graph, room) do
			finishWalls(m, at, theme, side)
		end
		local s = sides(graph, room)
		for _, key in { "N", "S", "E", "W" } do
			if s[key].outer and not (room == 1 and key == "W") and not (room == 4 and key == "W") then
				windowOn(m, at, s[key]) -- the foyer's W wall has the front door, the living room's the fireplace
			end
		end
		box(m, "Ceiling", Vector3.new(24, 1, 24), at(0, 12.5, 0), Color3.fromRGB(60, 56, 54), Enum.Material.Plaster)
		box(m, "LampCord", Vector3.new(0.1, 1.6, 0.1), at(0, 11.2, 0), Color3.fromRGB(20, 20, 20), Enum.Material.SmoothPlastic, false)
		local shade = box(m, "LampShade", Vector3.new(2.2, 1, 2.2), at(0, 10.1, 0), Color3.fromRGB(70, 52, 36), Enum.Material.Fabric, false)
		shade.Shape = Enum.PartType.Cylinder
		shade.CFrame = at(0, 10.1, 0) * CFrame.Angles(0, 0, math.pi / 2)
		shade.Size = Vector3.new(1, 2.4, 2.4)
		local bulb = box(m, "Bulb", Vector3.new(0.6, 0.6, 0.6), at(0, 9.45, 0), Color3.fromRGB(255, 170, 90), Enum.Material.Neon, false)
		bulb.Shape = Enum.PartType.Ball
		light(bulb, WARM_LIGHT, 18, 0.7, FLICKER_ROOMS[room])
		ROOM_PROPS[room](m, at)
		m.Parent = decor
	end
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
