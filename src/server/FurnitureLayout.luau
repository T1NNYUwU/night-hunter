--!nonstrict
-- The DEFAULT furniture layout, room by room. This is only the starting point: Furniture.seed turns
-- it into independent Models in the house, and from then on the pieces in Studio are the truth.
--
-- Each room function receives a builder `f`:
--   f.piece(kind, x, z, yaw, opts)      room-local position (the room's centre point = 0,0), front = -Z
--   f.wall(kind, side, along, opts)     against a wall ("N" "S" "E" "W"), front into the room
--   f.art(side, along, w, h, color, opts)  a picture hung on a wall (opts.kind = "mirror" / "antlers")
--   f.rug(x, z, w, d, color)
--   f.dist(side)                        distance from the centre point to that wall's inner face
-- opts: { y = lift above the floor, scale, seed, color, sheet = dust sheet over it, tipped = knocked
--         over, tilt = degrees a picture hangs crooked }
-- Kinds are listed in Furniture.lua (CATALOG). Hiding wardrobes and tables are placed from
-- HouseGraph, not here: a candelabra on a hiding table sits at y = HIDE_TABLE_TOP.
--
-- Rule of the house: furniture stands along the walls and the middle of every room stays OPEN, so a
-- chased player always has room to run and to loop round. Rooms are 34-44 studs across; doorways sit
-- in the middle of a wall (the hall's side doors and the landing's are near the north end), and the
-- stairwells (Study, Kitchen: the outer edge; Landing: the hall void) are kept clear.

local HouseKit = require(script.Parent.HouseKit)

local RED, GREEN, BLUE = HouseKit.CLOTH_RED, HouseKit.CLOTH_GREEN, HouseKit.CLOTH_BLUE
local PURPLE = Color3.fromRGB(80, 34, 92)
local HIDE_TABLE_TOP = 3.1

local rooms = {}

rooms[1] = function(f) -- Entrance Hall (spawn). Measured from (0, 10) under the balcony; the pillar + altar stand at z +11..+16 (shell);
	-- the curved staircases run from z +30 back to the balcony; the front (z +30..+46) is open floor
	f.rug(0, 31, 22, 14, RED)
	f.rug(0, 18, 6, 12, RED)
	for _, x in { -14, 14 } do
		f.piece("pedestal", x, 42, 0)
		f.piece("statuette", x, 42, 180, { y = 3 })
	end
	for _, x in { -8, 8 } do
		f.piece("pedestal", x, 26, 0)
		f.piece("candelabra", x, 26, 0, { y = 3 })
	end
	f.wall("clock", "S", 12)
	f.art("N", 13, 4, 5, Color3.fromRGB(70, 50, 40), { tilt = -4 })
	f.art("N", -12, 2.8, 3.9, nil, { kind = "antlers", y = 11 })
	f.art("N", 18, 3.5, 12, PURPLE, { y = 7 })
end

rooms[2] = function(f) -- Library. Doors E (z -15, archway), N (middle) · wardrobe W (+10) · hiding table (-6, 8)
	f.wall("shelf", "W", -15.5)
	f.wall("shelf", "W", -4)
	f.wall("cabinet", "W", 17)
	f.wall("shelf", "S", -10)
	f.wall("shelf", "S", 2)
	f.wall("shelf", "N", -10.5)
	f.wall("shelf", "N", 8.6, { scale = 0.7 })
	f.wall("fireplace", "E", 8)
	f.piece("armchair", 9, 4, -90, { color = GREEN, sheet = true })
	f.piece("armchair", 9, 12, -90, { color = GREEN })
	f.piece("candelabra", -6, 8, 0, { y = HIDE_TABLE_TOP })
	f.piece("chair", -6, 12.6, 0)
	f.piece("chair", -1, -12, 30, { tipped = true })
	f.rug(-6, 8, 12, 11, GREEN)
	f.art("S", 13, 3, 4, Color3.fromRGB(80, 90, 70), { tilt = 7 })
end

rooms[3] = function(f) -- Dining Room. Doors W (z -15, archway), N (middle) · wardrobe E (+10) · hiding dining table (0, 8)
	f.piece("chair", -4.6, 8, -90)
	f.piece("chair", 4.6, 8, 90)
	f.piece("chair", 0, 12.6, 0)
	f.piece("chair", -1.5, 1.5, 200, { tipped = true })
	f.piece("candelabra", 0, 8, 0, { y = HIDE_TABLE_TOP })
	f.rug(0, 8, 14, 13, RED)
	f.wall("cabinet", "E", -8)
	f.wall("cabinet", "E", -3)
	f.wall("drawer", "E", 17)
	f.wall("fireplace", "W", 10)
	f.art("S", -8, 4, 5, Color3.fromRGB(90, 60, 50), { tilt = 5 })
	f.art("S", 8, 4, 5, Color3.fromRGB(60, 60, 90))
	f.art("N", -10, 3, 5, nil, { kind = "mirror" })
end

rooms[4] = function(f) -- Study. Doors S, E (middle) · stairs down on the W side (x -17..-10, z -10..14) · wardrobe N (+10) · hiding desk (6, 6)
	f.wall("shelf", "N", 0, { scale = 0.8 })
	f.wall("clock", "S", 10)
	f.wall("cabinet", "E", 10)
	f.wall("drawer", "E", -10)
	f.piece("chair", 6, 10.5, 0)
	f.piece("candelabra", 6, 6, 180, { y = HIDE_TABLE_TOP })
	f.rug(6, 6, 10, 9, RED)
	f.art("N", 0, 2.8, 3.9, nil, { kind = "antlers", y = 11 })
	f.art("E", -1, 3, 4, Color3.fromRGB(70, 50, 40), { tilt = -6 })
end

rooms[5] = function(f) -- Ballroom. Archway S (to the hall), doors W, E (middle) · wardrobe N (-14). The floor stays empty.
	f.piece("piano", 5, -9, 160)
	f.wall("clock", "N", 17)
	for _, z in { -10, 10 } do
		f.wall("chair", "W", z)
		f.wall("chair", "E", z, { sheet = z > 0 })
	end
	f.piece("chair", 4, -2, 140, { tipped = true })
	for _, x in { -19, 19 } do
		f.piece("pedestal", x, 15, 0)
		f.piece("statuette", x, 15, 180, { y = 3 })
	end
	f.art("N", -4, 5, 6, Color3.fromRGB(60, 40, 40), { tilt = 3 })
	f.art("S", -14, 3, 5, nil, { kind = "mirror" })
	f.art("S", 14, 3, 5, nil, { kind = "mirror" })
end

rooms[6] = function(f) -- Kitchen. Doors W, S (middle) · stairs down on the E side (x 10..17, z -10..14) · wardrobe N (-8) · hiding table (-6, 8)
	f.wall("counter", "N", 1, { scale = 0.7 })
	f.piece("sink", 1, -16.25, 0, { y = 3.5 })
	f.wall("stove", "W", -9)
	f.wall("fridge", "W", -14)
	f.wall("cabinet", "W", 12)
	f.piece("chair", -10.6, 8, -90)
	f.piece("chair", -1.4, 8, 90, { tipped = true })
	f.piece("candle", -6, 8, 0, { y = HIDE_TABLE_TOP })
	for _, x in { -12, -9.5 } do
		f.piece("barrel", x, 15.5, 0)
	end
	f.piece("boxPile", 6, 15, 0, { seed = 6 })
end

rooms[7] = function(f) -- Landing (the balcony over the hall: z -6.5..+7 from its centre point). Archway N, doors W, E (middle) · wardrobe N (-11)
	f.rug(0, 0, 24, 6, RED)
	for _, x in { -10, 10 } do
		f.piece("pedestal", x, -4.5, 0)
		f.piece("candelabra", x, -4.5, 0, { y = 3 })
	end
	f.art("N", 13, 4, 5, Color3.fromRGB(70, 40, 40), { tilt = -5 })
	f.art("N", -11, 2.8, 3.9, nil, { kind = "antlers", y = 11 })
end

rooms[8] = function(f) -- Gallery. Archway S, doors W, E (middle) · wardrobe N (+12). Portraits; a clear lane down the middle.
	local tilts = { 0, -6, 0, 4 }
	for i, x in { -17, -10, -3, 4 } do
		f.art("N", x, 4, 5.5, Color3.fromRGB(50 + i * 8, 40, 40 + i * 6), { tilt = tilts[i] })
	end
	for i, x in { -17, -11, 11, 17 } do
		f.art("S", x, 4, 5.5, Color3.fromRGB(40, 40 + i * 6, 50), { tilt = if i == 2 then 8 else 0 })
	end
	for _, z in { -8, 8 } do
		for _, x in { -10, 10 } do
			f.piece("pedestal", x, z, 0)
			f.piece("statuette", x, z, 180, { y = 3 })
		end
	end
	f.rug(0, 0, 6, 30, RED)
end

rooms[9] = function(f) -- Guest Bedroom. Doors E (z -15), N (middle) · wardrobe W (+10)
	f.wall("bed", "W", -6)
	f.piece("smallTable", -14.4, -11.5, 0)
	f.piece("candlesticks", -14.4, -11.5, 90, { y = 2.6 })
	f.wall("drawer", "S", -8)
	f.wall("drawer", "S", 8)
	f.art("S", 0, 3, 4.5, nil, { kind = "mirror", y = 7 })
	f.piece("chair", 6, 8, 60, { tipped = true })
	f.rug(-4, -6, 10, 9, BLUE)
	f.art("N", 10, 3, 4, Color3.fromRGB(80, 90, 70), { tilt = 6 })
end

rooms[10] = function(f) -- Bathroom. Doors W (z -15), N (middle) · wardrobe E (+10). The tub stands free.
	f.piece("bathtub", -3, 8, 90)
	f.wall("vanity", "S", 6)
	f.art("S", 6, 3, 4, nil, { kind = "mirror", y = 7, tilt = -4 })
	f.piece("toilet", 13, 19.6, 0)
	f.wall("cabinet", "W", 10)
	f.rug(-3, 8, 9, 12, Color3.fromRGB(120, 130, 128))
end

rooms[11] = function(f) -- Nursery. Doors S, E (middle) · wardrobe W (-10)
	f.piece("crib", -8, -10, 0)
	f.piece("rockingHorse", 8, -8, 30)
	f.piece("toyBlocks", 4, 9, 0)
	f.piece("toyBlocks", -6, 11, 90)
	f.wall("drawer", "N", 6)
	f.art("N", -12, 3, 4, Color3.fromRGB(110, 90, 80), { tilt = -9 })
	f.rug(0, 0, 12, 12, Color3.fromRGB(140, 110, 100))
end

rooms[12] = function(f) -- Master Bedroom. Doors W, S (middle) · wardrobe E (-10) · hiding dressing table (-6, 8)
	f.wall("bed", "N", 0, { scale = 1.2 })
	f.wall("drawer", "N", -10)
	f.wall("drawer", "N", 10)
	f.wall("cabinet", "W", 10)
	f.art("W", -10, 3, 5, nil, { kind = "mirror" })
	f.piece("candelabra", -6, 8, 180, { y = HIDE_TABLE_TOP })
	f.piece("chair", -6, 12.6, 0)
	f.rug(0, -6, 14, 10, BLUE)
	f.art("S", 10, 4, 5, Color3.fromRGB(60, 50, 70), { tilt = 5 })
end

rooms[13] = function(f) -- Boiler Room. Doors E, S (middle) · steps up to the study on the W side (x -17..-10, z -10..14) · wardrobe N (+10)
	f.piece("boiler", 6, -9, 0)
	f.piece("boxPile", 7, 9, 0, { seed = 13 })
	f.piece("barrel", 14, -14, 0)
	f.piece("barrel", 14, -11.5, 0)
end

rooms[14] = function(f) -- Wine Cellar. Doors W, E (middle), archway S · wardrobe N (-12)
	f.wall("wineRack", "N", 2)
	f.wall("wineRack", "N", 13)
	for _, z in { -10, 10 } do
		f.wall("wineRack", "W", z)
		f.wall("wineRack", "E", z)
	end
	for _, x in { -15, -12.5, 12.5, 15 } do
		f.piece("barrel", x, 15.5, 0)
	end
	f.piece("smallTable", 0, -4, 0)
	f.piece("candle", 0, -4, 0, { y = 2.6 })
end

rooms[15] = function(f) -- Cold Storage. Door W (middle) · steps up to the kitchen on the E side (x 10..17, z -10..14) · wardrobe N (-8) · hiding slab (-6, 8)
	f.wall("slab", "W", -10)
	f.wall("slab", "W", 10)
	f.piece("boxPile", 2, -13, 0, { seed = 15 })
	f.piece("barrel", -14, -15, 0)
	f.piece("candle", -6, 8, 0, { y = HIDE_TABLE_TOP })
end

rooms[16] = function(f) -- Crypt (the lair). Archway N, door W (middle) · wardrobes S (+12), E (+10)
	for _, z in { -10, 2 } do
		f.piece("coffin", -15, z, 0, { scale = 0.7 })
		f.piece("coffin", 15, z - 4, 0, { scale = 0.7 })
	end
	f.piece("coffin", -6, 17, 90, { scale = 0.7, sheet = true })
	f.piece("coffin", 4, -4, 20, { scale = 0.7 }) -- one left in the middle, lid ajar
	for _, x in { -18, 18 } do
		f.piece("pedestal", x, -18, 0)
		f.piece("candelabra", x, -18, 0, { y = 3 })
	end
	f.piece("statuette", 0, 17.5, 180)
end

rooms[17] = function(f) -- Coal Cellar. Doors N, E (middle) · wardrobe W (+10)
	f.piece("boxPile", 6, -10, 0, { seed = 17 })
	f.piece("boxPile", -8, -14, 0, { seed = 71 })
	f.piece("boxPile", 9, 14, 0, { seed = 117 })
	for _, z in { -6, -3.5, -1 } do
		f.piece("barrel", -14, z, 0)
	end
	f.wall("shelf", "S", 0, { scale = 0.9 })
end

return { rooms = rooms, HIDE_TABLE_TOP = HIDE_TABLE_TOP }
