--!nonstrict
-- The DEFAULT furniture layout, room by room. This is only the starting point: Furniture.seed turns
-- it into independent Models in the house, and from then on the pieces in Studio are the truth.
--
-- Each room function receives a builder `f`:
--   f.piece(kind, x, z, yaw, opts)      room-local position (the room's centre point = 0,0), front = -Z
--   f.wall(kind, side, along, opts)     against a wall ("N" "S" "E" "W"), front into the room
--   f.art(side, along, w, h, color)     a picture or mirror hung on a wall
--   f.rug(x, z, w, d, color)
--   f.dist(side)                        distance from the centre point to that wall's inner face
-- opts: { y = lift above the floor, scale = number, seed = number, color = Color3 }
-- Kinds are listed in Furniture.lua (CATALOG). Hiding wardrobes and tables are placed from
-- HouseGraph, not here: a candelabra on a hiding table sits at y = HIDE_TABLE_TOP.
--
-- Rooms are 24 wide (x) by 32 deep (z), the hall and the rooms along the middle 32 wide. Doors sit in the
-- middle of a wall or near a corner (see HouseGraph.DOORS); three stairwells (Study, Kitchen: the
-- east/west edge; Landing: the hall void) are kept clear.

local HouseKit = require(script.Parent.HouseKit)

local RED, GREEN, BLUE = HouseKit.CLOTH_RED, HouseKit.CLOTH_GREEN, HouseKit.CLOTH_BLUE
local PURPLE = Color3.fromRGB(96, 40, 110)
local HIDE_TABLE_TOP = 3.1
local MIRROR = Color3.fromRGB(150, 170, 180)

local rooms = {}

rooms[1] = function(f) -- Entrance Hall (spawn). Pillar + altar in the middle (shell); stairs along E and W
	f.rug(0, 2, 12, 20, RED)
	for _, x in { -7, 7 } do
		f.piece("pedestal", x, 14.5, 0)
		f.piece("candelabra", x, 14.5, 180, { y = 3 })
	end
	f.wall("clock", "S", 6)
	f.art("N", 9, 3.5, 9, PURPLE, { y = 8.5 })
	for _, z in { 0, 8 } do
		f.art("W", z, 3.5, 9, PURPLE, { y = 8.5 })
		f.art("E", z, 3.5, 9, PURPLE, { y = 8.5 })
	end
end

rooms[2] = function(f) -- Library. Doors E (z -12), N (middle) · wardrobe W (+8) · hiding table (-4, 6)
	f.wall("shelf", "W", -10)
	f.wall("shelf", "W", -1.5)
	f.wall("cabinet", "W", 13)
	f.wall("shelf", "S", -6)
	f.wall("shelf", "S", 6)
	f.wall("fireplace", "E", 5)
	f.piece("armchair", 6.5, -1, 90, { color = GREEN })
	f.piece("armchair", 6.5, 11, 90, { color = GREEN })
	f.piece("candelabra", -4, 6, 0, { y = HIDE_TABLE_TOP })
	f.piece("chair", -4, 10.5, 180)
	f.rug(-4, 6, 11, 9, GREEN)
	f.art("N", -8, 4, 5, Color3.fromRGB(80, 90, 70))
	f.art("N", 8, 4, 5, Color3.fromRGB(70, 60, 50))
end

rooms[3] = function(f) -- Dining Room. Doors W (z -12), N (middle) · wardrobe E (+8) · hiding dining table (-2, 6)
	f.piece("chair", -5.65, 6, -90)
	f.piece("chair", 1.65, 6, 90)
	f.piece("candelabra", -2, 6, 0, { y = HIDE_TABLE_TOP })
	f.rug(-2, 6, 12, 10, RED)
	f.wall("cabinet", "E", -8)
	f.wall("cabinet", "E", -3.5)
	f.wall("fireplace", "W", 8)
	f.art("S", -6, 4, 5, Color3.fromRGB(90, 60, 50))
	f.art("S", 6, 4, 5, Color3.fromRGB(60, 60, 90))
	f.art("N", -8, 3, 4, Color3.fromRGB(70, 60, 50))
end

rooms[4] = function(f) -- Study. Doors S (middle), E (middle) · stairwell on the W side (x -12..-6, z -10..10) · wardrobe N (+8.5) · hiding desk (4, 4)
	f.wall("shelf", "N", 1, { scale = 0.8 })
	f.wall("cabinet", "S", -8)
	f.wall("clock", "S", 8)
	f.wall("cabinet", "E", 8)
	f.wall("drawer", "E", -8)
	f.piece("chair", 4, 9, 180)
	f.piece("candelabra", 4, 4, 180, { y = HIDE_TABLE_TOP })
	f.rug(4, 5, 9, 8, RED)
	f.art("E", -12, 3, 4, Color3.fromRGB(70, 50, 40))
end

rooms[5] = function(f) -- Living Room. Doors W, E (middle), S (middle) · wardrobe N (-10) · fireplace N (+6)
	f.wall("fireplace", "N", 6)
	f.piece("sofa", 6, -5, 0)
	f.piece("armchair", 11, -8, 90, { color = RED })
	f.piece("armchair", 1, -8, -90, { color = RED })
	f.rug(6, -7, 14, 10, BLUE)
	f.wall("piano", "S", -9)
	f.art("W", -8, 4, 3, Color3.fromRGB(120, 90, 60))
	f.art("W", 8, 4, 3, Color3.fromRGB(60, 80, 70))
	f.art("E", -8, 4, 3, Color3.fromRGB(90, 70, 80))
	f.art("E", 8, 4, 3, Color3.fromRGB(80, 60, 50))
end

rooms[6] = function(f) -- Kitchen. Doors W (middle), S (middle) · stairwell on the E side (x 6..12, z -10..10) · wardrobe N (-6) · hiding table (-4, 6)
	f.wall("counter", "N", 1.8, { scale = 0.7 })
	f.piece("sink", 2.5, -14.25, 0, { y = 3.5 })
	f.wall("stove", "W", -9)
	f.wall("fridge", "W", -13.5)
	f.piece("chair", -7.5, 6, -90)
	f.piece("chair", -0.5, 6, 90)
	f.piece("candelabra", -4, 6, 0, { y = HIDE_TABLE_TOP })
	for _, x in { -9, -6.5 } do
		f.piece("barrel", x, 14, 0)
	end
	f.piece("boxPile", -9, 10, 0, { seed = 6 })
end

rooms[7] = function(f) -- Landing (a balcony over the hall, z -3.5..+4 from its centre point). Doors W, E (middle), N (middle) · wardrobe N (-7)
	f.rug(0, 0, 18, 4, RED)
	for _, x in { -6.5, 6.5 } do
		f.piece("pedestal", x, 1.8, 0)
		f.piece("candelabra", x, 1.8, 0, { y = 3 })
	end
	f.art("N", 8, 4, 5, Color3.fromRGB(70, 40, 40))
	f.art("N", -4, 3, 4, Color3.fromRGB(40, 50, 70))
end

rooms[8] = function(f) -- Gallery. Doors S (middle), W, E (middle) · wardrobe N (+8)
	f.art("N", -10, 4, 5, Color3.fromRGB(70, 40, 40))
	f.art("N", -3, 3, 4, Color3.fromRGB(40, 50, 70))
	f.art("N", 0, 3.5, 5, Color3.fromRGB(80, 70, 40))
	f.art("S", -9, 4, 5, Color3.fromRGB(60, 30, 60))
	f.art("S", 9, 4, 5, Color3.fromRGB(70, 60, 40))
	for _, z in { -8, 8 } do
		for _, x in { -6, 6 } do
			f.piece("pedestal", x, z, 0)
			f.piece("candelabra", x, z, 0, { y = 3 })
		end
	end
	f.rug(0, 0, 6, 22, RED)
end

rooms[9] = function(f) -- Guest Bedroom. Doors E (z -12), N (middle) · wardrobe W (+8)
	f.wall("bed", "W", -6)
	f.piece("smallTable", -9.4, -10.8, 0)
	f.piece("candle", -9.4, -10.8, 0, { y = 2.6 })
	f.wall("drawer", "S", -6)
	f.wall("drawer", "S", 6)
	f.piece("chair", 4, 6, 90)
	f.rug(2, -6, 9, 7, BLUE)
	f.art("S", 0, 3, 3, Color3.fromRGB(90, 70, 80), { y = 8 })
	f.art("N", -7, 3, 3, Color3.fromRGB(80, 90, 70))
end

rooms[10] = function(f) -- Bathroom. Doors W (z -12), N (middle) · wardrobe E (+9)
	f.wall("bathtub", "S", -6)
	f.wall("vanity", "S", 4)
	f.piece("toilet", 8.6, 14.1, 0)
	f.art("S", 4, 3, 3.5, MIRROR, { y = 7, material = Enum.Material.Glass })
	f.wall("cabinet", "W", 8)
	f.rug(-2, 6, 6, 5, Color3.fromRGB(150, 160, 160))
end

rooms[11] = function(f) -- Nursery. Doors S (middle), E (middle) · wardrobe W (-8)
	f.piece("crib", -6, -8, 0)
	f.piece("rockingHorse", 6, -6, 0)
	f.piece("toyBlocks", 4, 7, 0)
	f.piece("toyBlocks", -8, 9, 90)
	f.wall("drawer", "N", 5)
	f.rug(2, 2, 9, 9, Color3.fromRGB(150, 120, 100))
	f.art("N", -4, 3, 4, Color3.fromRGB(100, 90, 70))
end

rooms[12] = function(f) -- Master Bedroom. Doors W (middle), S (middle) · wardrobe E (-8) · hiding dressing table (-4, 6)
	f.wall("bed", "N", 0, { scale = 1.1 })
	f.wall("drawer", "N", -8)
	f.wall("drawer", "N", 8)
	f.wall("cabinet", "W", 8)
	f.art("N", -10.5, 3, 3.5, MIRROR, { y = 7, material = Enum.Material.Glass })
	f.piece("candelabra", -4, 6, 180, { y = HIDE_TABLE_TOP })
	f.piece("chair", -4, 10, 180)
	f.rug(0, -6, 10, 8, BLUE)
end

rooms[13] = function(f) -- Boiler Room. Doors E (middle), S (middle) · steps up to the study on the W side (x -12..-6, z -10..10) · wardrobe N (+8)
	f.piece("boiler", 4, -7, 0)
	f.wall("drawer", "N", -4)
	f.piece("boxPile", 4, 8, 0, { seed = 13 })
	f.piece("boxPile", -8, 9, 0, { seed = 31 })
	f.piece("barrel", 10, -12, 0)
	f.piece("barrel", 10, -9.5, 0)
end

rooms[14] = function(f) -- Wine Cellar. Doors W, E (middle), S (middle) · wardrobe N (-9)
	f.wall("wineRack", "N", 3)
	for _, z in { -9, 9 } do
		f.wall("wineRack", "W", z)
		f.wall("wineRack", "E", z)
	end
	for _, x in { -9, -6.5, 6.5, 9 } do
		f.piece("barrel", x, 13.5, 0)
	end
	f.piece("smallTable", 0, -2, 0)
	f.piece("candle", 0, -2, 0, { y = 2.6 })
end

rooms[15] = function(f) -- Cold Storage. Doors W (middle) · steps up to the kitchen on the E side (x 6..12, z -10..10) · wardrobe N (-6) · hiding slab (-4, 6)
	f.wall("slab", "W", -9)
	f.wall("slab", "W", 9)
	f.piece("boxPile", 3, -10, 0, { seed = 15 })
	f.piece("boxPile", -9, 12, 0, { seed = 51 })
	f.piece("barrel", -9, -12, 0)
	f.piece("barrel", -6.5, -12, 0)
	f.piece("candle", -4, 6, 0, { y = HIDE_TABLE_TOP })
end

rooms[16] = function(f) -- Crypt (the lair). Doors N (middle), W (middle) · wardrobes S (+8), E (+8)
	for _, x in { -8, 0, 8 } do
		f.piece("coffin", x, -4, 0)
	end
	f.piece("coffin", -8, 8, 0)
	f.piece("coffin", 3, 8, 0)
	for _, z in { -8, 8 } do
		f.piece("pedestal", -13, z, 0)
		f.piece("candelabra", -13, z, 0, { y = 3 })
	end
end

rooms[17] = function(f) -- Coal Cellar. Doors N (middle), E (middle) · wardrobe W (+8)
	f.piece("boxPile", 4, -7, 0, { seed = 17 })
	f.piece("boxPile", -6, -10, 0, { seed = 71 })
	f.piece("boxPile", 7, 9, 0, { seed = 117 })
	for _, z in { -12, -9.5, -7 } do
		f.piece("barrel", -10, z, 0)
	end
	f.wall("shelf", "S", 0, { scale = 0.9 })
end

return { rooms = rooms, HIDE_TABLE_TOP = HIDE_TABLE_TOP }
