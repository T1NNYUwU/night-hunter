--!nonstrict
-- The DEFAULT furniture layout, room by room (the furniture of the floor plans in docs/mansion.md). This is
-- only the starting point: Furniture.seed turns it into independent Models in the house, and from then on
-- the pieces in Studio are the truth.
--
-- Each room function receives a builder `f`:
--   f.piece(kind, x, z, yaw, opts)      room-local position (the room's centre point = 0,0), front = -Z
--   f.wall(kind, side, along, opts)     against a wall ("N" "S" "E" "W"), front into the room
--   f.art(side, along, w, h, color, opts)  a picture hung on a wall (opts.kind = "mirror" / "antlers")
--   f.rug(x, z, w, d, color)
--   f.dist(side)                        distance from the centre point to that wall's inner face
-- opts: { y = lift above the floor, scale, seed, color, sheet = dust sheet over it, tipped = knocked
--         over, tilt = degrees a picture hangs crooked, empty = a shelf without books }
-- Yaw: a piece faces -Z at 0; 90 faces -X (west), -90 faces +X (east), 180 faces +Z (south).
-- Hiding wardrobes and tables are placed from HouseGraph, not here: a candelabra on a hiding table sits
-- at y = HIDE_TABLE_TOP.
--
-- Rules of the house: furniture stands along the walls, every doorway and stair end stays clear, and the
-- middle of a room is open floor, or holds ONE big piece you can run circles round (fountain, piano, tub,
-- table, sarcophagus).

local HouseKit = require(script.Parent.HouseKit)

local RED, GREEN, BLUE = HouseKit.CLOTH_RED, HouseKit.CLOTH_GREEN, HouseKit.CLOTH_BLUE
local PURPLE = Color3.fromRGB(80, 34, 92)
local DUSTY = Color3.fromRGB(110, 100, 90)
local HIDE_TABLE_TOP = 3.1

local rooms = {}

-- FLOOR 1 --------------------------------------------------------------------------------------------

rooms[1] = function(f) -- Entrance Hall. Measured from (0, 10) under the balcony; pillar at z +11, altar z +15.5; front door z +58
	f.rug(0, 46, 30, 16, RED) -- the grand rug in the open front of the hall
	f.rug(0, 28, 6, 18, RED) -- a runner from the rug to the altar
	for _, x in { -12, 12 } do
		f.piece("pedestal", x, 52, 0)
		f.piece("statuette", x, 52, 180, { y = 3 })
	end
	for _, x in { -7, 7 } do
		f.piece("pedestal", x, 16, 0)
		f.piece("candelabra", x, 16, 0, { y = 3 })
	end
	f.wall("sofa", "W", 48, { color = PURPLE })
	f.wall("sofa", "E", 48, { color = PURPLE })
	for _, x in { -28, 28 } do
		f.piece("planter", x, 40, 0)
	end
	f.wall("clock", "S", 24)
	f.art("N", -12, 2.8, 3.9, nil, { kind = "antlers", y = 11 })
	f.art("N", 12, 4, 5, Color3.fromRGB(70, 50, 40), { tilt = -4 })
end

rooms[2] = function(f) -- Library. Doors E (to the hall, z +10), N (to the study, x +15) · secret stair along the north (x -14..+10, z -12.5..-7.5) · reading table (0, 2)
	f.wall("shelf", "S", -8)
	f.wall("shelf", "S", 6, { scale = 0.7 })
	f.wall("shelf", "E", -4, { scale = 0.7 })
	f.wall("shelf", "W", -3, { scale = 0.7 }) -- the bookcase by the secret stair
	f.wall("fireplace", "W", 7)
	f.piece("armchair", -9, 4, 90, { color = GREEN, sheet = true })
	f.piece("armchair", -9, 10, 90, { color = GREEN })
	f.piece("candelabra", 0, 2, 0, { y = HIDE_TABLE_TOP })
	f.piece("chair", 0, 6.6, 0)
	f.piece("chair", 8, 9, 30, { tipped = true })
	f.rug(0, 2, 14, 10, GREEN)
	f.art("S", 13, 3, 4, Color3.fromRGB(80, 90, 70), { tilt = 7 })
end

rooms[3] = function(f) -- Dining Room. Doors W (to the hall, z +10), N (to the kitchen, x 0) · dining table (0, 0) · china cabinet S (+10)
	f.piece("chair", -4.6, 0, -90)
	f.piece("chair", 4.6, 0, 90)
	f.piece("chair", 0, 4.6, 0)
	f.piece("chair", -1, -5, 200, { tipped = true })
	f.piece("candelabra", 0, 0, 0, { y = HIDE_TABLE_TOP })
	f.rug(0, 0, 18, 14, RED)
	f.wall("fireplace", "E", 0)
	f.wall("drawer", "S", -8)
	f.piece("candlesticks", -8, 11.8, 180, { y = 3.6 })
	f.art("N", -10, 4, 5, Color3.fromRGB(90, 60, 50), { tilt = 5 })
	f.art("N", 10, 4, 5, Color3.fromRGB(60, 60, 90))
	f.art("W", -6, 3, 5, nil, { kind = "mirror" })
end

rooms[4] = function(f) -- Study. Doors N (corridor, x 0), S (library, x +15), E (hall, z -2) · desk (3, 0) · wardrobe S (-6)
	f.piece("chair", 3, 4.4, 0)
	f.piece("candelabra", 3, 0, 180, { y = HIDE_TABLE_TOP })
	f.wall("shelf", "N", -10)
	f.wall("shelf", "N", 10, { scale = 0.7 })
	f.wall("fireplace", "W", 0)
	f.wall("clock", "S", 6)
	f.rug(3, 0, 12, 9, RED)
	f.art("E", 6, 3, 4, Color3.fromRGB(70, 50, 40), { tilt = -6 })
end

rooms[5] = function(f) -- Ballroom. Archway S (corridor), doors W, E (z 0) · wardrobe N (-14). The floor stays empty but for the piano.
	f.piece("piano", 9, -10, 160)
	f.wall("clock", "N", 0)
	for _, z in { -12, -7, 8 } do
		f.wall("chair", "W", z, { sheet = z == 8 })
	end
	for _, z in { 8, 12 } do
		f.wall("chair", "E", z)
	end
	f.piece("chair", 4, 2, 140, { tipped = true })
	for _, x in { -19, 19 } do
		f.piece("pedestal", x, 15, 0)
		f.piece("statuette", x, 15, 180, { y = 3 })
	end
	f.art("N", 8, 5, 6, Color3.fromRGB(60, 40, 40), { tilt = 3 })
	f.art("S", -14, 3, 5, nil, { kind = "mirror" })
	f.art("S", 14, 3, 5, nil, { kind = "mirror" })
end

rooms[6] = function(f) -- Kitchen. Doors N (corridor), S (dining), both x 0 · table (-4, 1) · pantry W (+5)
	f.wall("counter", "N", -10, { scale = 0.85 })
	f.piece("sink", -10, -7.25, 0, { y = 3.5 })
	f.wall("stove", "N", 7)
	f.wall("fridge", "N", 13)
	f.piece("chair", -8.6, 1, -90)
	f.piece("chair", 0.6, 1, 90, { tipped = true })
	f.piece("candle", -4, 1, 0, { y = HIDE_TABLE_TOP })
	for _, x in { -12, -9.5 } do
		f.wall("barrel", "S", x)
	end
	f.piece("boxPile", 12, 5, 0, { seed = 6 })
end

rooms[7] = function(f) -- Conservatory (glass walls, moonlit). Doors E (ballroom, z 0), S (corridor, x 0) · potting cabinet W (+9)
	f.piece("fountain", 0, 4, 0)
	for _, x in { -17, -7, 7, 17 } do
		f.wall("planter", "N", x)
	end
	for _, z in { -10, 12 } do
		f.wall("planter", "W", z)
		f.wall("planter", "E", z + 1)
	end
	f.piece("chair", -7, -3, 30, { color = DUSTY })
	f.piece("chair", 7, -3, -30, { color = DUSTY })
	f.piece("statuette", 0, -12, 180)
end

rooms[8] = function(f) -- Servants' Hall. Doors W (ballroom, z 0), S (corridor, x 0) · back stairs on the east (x +9..+22) · long table (-5, 0)
	f.piece("longTable", -13, 0, 90)
	f.piece("longTable", 3, 0, 90)
	for _, x in { -13, -5, 3 } do
		f.piece("chair", x, -4.6, 180)
		f.piece("chair", x, 4.6, 0)
	end
	f.piece("candle", -5, 0, 0, { y = HIDE_TABLE_TOP })
	f.wall("cabinet", "W", -12)
	f.wall("cabinet", "W", 12)
	f.wall("shelf", "N", -12, { empty = true })
	f.wall("clock", "S", -14)
end

rooms[9] = function(f) -- Main Corridor (136 x 10). Doors on both sides; nothing in the way
	f.rug(0, 0, 120, 4, RED)
	f.wall("clock", "N", -30)
	for _, x in { -60, -22, 22, 60 } do
		f.art("N", x, 3.5, 4.5, Color3.fromRGB(60, 46, 40), { tilt = if x == 22 then 6 else 0 })
	end
	for _, x in { -62, -22, 22, 62 } do
		f.art("S", x, 3, 4, Color3.fromRGB(50, 46, 60))
	end
end

-- FLOOR 2 --------------------------------------------------------------------------------------------

rooms[10] = function(f) -- Landing: the balcony (z -6.5..+7) and the side galleries along the hall (x ±29, z +7..+41). Archway N; doors W (z 0, z +27), E (z +27)
	f.rug(0, 0, 40, 4, RED)
	for _, x in { -8, 8 } do
		f.piece("pedestal", x, -3, 0)
		f.piece("candelabra", x, -3, 0, { y = 3 })
	end
	f.art("N", 12, 4, 5, Color3.fromRGB(70, 40, 40), { tilt = -5 })
	for _, side in { "W", "E" } do
		f.art(side, 14, 3, 4, Color3.fromRGB(60, 50, 70))
		f.art(side, 36, 3, 4, Color3.fromRGB(70, 60, 50), { tilt = if side == "W" then 7 else 0 })
	end
end

rooms[11] = function(f) -- Upper Corridor (136 x 10)
	f.rug(0, 0, 120, 4, BLUE)
	f.wall("clock", "N", 30)
	for _, x in { -60, -22, 22, 60 } do
		f.art("N", x, 3.5, 4.5, Color3.fromRGB(56, 50, 64))
	end
	for _, x in { -62, -22, 62 } do
		f.art("S", x, 3, 4, Color3.fromRGB(70, 56, 46), { tilt = if x == -22 then -7 else 0 })
	end
end

rooms[12] = function(f) -- Sitting Room. Doors N (corridor), S (master bedroom), both x 0; E (balcony, z -3) · wardrobe S (+10)
	f.wall("fireplace", "W", 0)
	f.piece("sofa", -8, 0, 90, { color = RED, sheet = true })
	f.piece("armchair", 2, -3, 90, { color = RED })
	f.piece("armchair", 2, 3, 90, { color = RED })
	f.rug(-4, 0, 12, 10, RED)
	f.art("E", 6, 3, 4, Color3.fromRGB(90, 70, 80))
end

rooms[13] = function(f) -- Master Bedroom. Doors N (sitting room, x 0), E (side gallery, z 0) · wardrobe N (+12)
	f.wall("bed", "S", 0, { scale = 1.2 })
	for _, x in { -6, 6 } do
		f.wall("smallTable", "S", x)
		f.piece("candle", x, 12.5, 0, { y = 2.6 })
	end
	f.wall("fireplace", "W", -4)
	f.wall("drawer", "N", -10)
	f.piece("armchair", -11, -6, 90, { color = BLUE })
	f.rug(0, 2, 14, 12, BLUE)
	f.art("E", 8, 3, 4.5, nil, { kind = "mirror" })
end

rooms[14] = function(f) -- Bathroom. Doors N (corridor), S (guest bedroom), both x 0 · linen cupboard E (-4). The tub stands free.
	f.piece("bathtub", -8, 1, 90)
	f.wall("vanity", "W", 4)
	f.art("W", 4, 3, 4, nil, { kind = "mirror", y = 7, tilt = -4 })
	f.wall("toilet", "E", 6)
	f.rug(-8, 1, 6, 10, Color3.fromRGB(120, 130, 128))
end

rooms[15] = function(f) -- Guest Bedroom. Doors N (bathroom, x 0), W (side gallery, z 0) · wardrobe N (-12)
	f.wall("bed", "S", 0, { sheet = true })
	for _, x in { -6, 6 } do
		f.wall("smallTable", "S", x)
	end
	f.wall("fireplace", "E", -4)
	f.wall("drawer", "N", 10)
	f.piece("armchair", 11, -4, -90, { color = GREEN, sheet = true })
	f.rug(0, 2, 14, 12, GREEN)
	f.art("W", 8, 3, 4, Color3.fromRGB(80, 90, 70), { tilt = 6 })
end

rooms[16] = function(f) -- Nursery. Doors E (gallery, z 0), S (corridor, x 0) · wardrobe W (+7)
	f.piece("crib", -15, -11, 0)
	f.piece("rockingHorse", 0, -1, 30)
	f.piece("toyBlocks", 11, -14, 0)
	f.piece("toyBlocks", -8, 9, 90)
	f.wall("drawer", "N", 8)
	f.rug(0, 0, 14, 12, Color3.fromRGB(140, 110, 100))
	f.art("N", -4, 3, 4, Color3.fromRGB(110, 90, 80), { tilt = -9 })
end

rooms[17] = function(f) -- Portrait Gallery. Doors W, E (z 0), archway S · wardrobe N (+17)
	local tilts = { 0, -6, 0, 4 }
	for i, x in { -16, -9, -2, 5 } do
		f.art("N", x, 4, 5.5, Color3.fromRGB(50 + i * 8, 40, 40 + i * 6), { tilt = tilts[i] })
	end
	for i, x in { -17, -11, 11, 17 } do
		f.art("S", x, 4, 5.5, Color3.fromRGB(40, 40 + i * 6, 50), { tilt = if i == 2 then 8 else 0 })
	end
	for _, z in { -9, 7 } do
		for _, x in { -10, 10 } do
			f.piece("pedestal", x, z, 0)
			f.piece("statuette", x, z, 180, { y = 3 })
		end
	end
	f.rug(0, 0, 6, 30, RED)
end

rooms[18] = function(f) -- Maid's Room. Doors W (gallery, z 0), S (corridor, x 0) · back stair down on the east (x +9..+15) · wardrobe W (-10)
	f.wall("bed", "N", -12, { scale = 0.8 })
	f.wall("drawer", "N", -2)
	f.piece("chair", -6, 6, 20)
	f.piece("boxPile", -16, 12, 0, { seed = 18 })
end

-- BASEMENT -------------------------------------------------------------------------------------------

rooms[19] = function(f) -- Service Tunnel (136 x 10)
	for _, x in { -64, -34, 30, 62 } do
		f.wall("barrel", "N", x)
	end
	f.wall("shelf", "S", -30, { empty = true, scale = 0.7 })
	f.wall("shelf", "S", 30, { empty = true, scale = 0.7 })
end

rooms[20] = function(f) -- Boiler Room. Doors E (wine cellar, z 0), S (tunnel, x 0) · wardrobe W (+9)
	f.piece("boiler", -5, -1, 0)
	f.piece("boxPile", 8, 8, 0, { seed = 13 })
	f.piece("barrel", 19, -12, 0)
	f.piece("barrel", 19, -9.5, 0)
	f.wall("shelf", "N", 8, { empty = true })
end

rooms[21] = function(f) -- Wine Cellar. Doors W, E (z 0), archway S · wardrobe N (-18). Three rows of racks make aisles.
	for _, x in { -12, 0, 12 } do
		for _, z in { -9, 0, 9 } do
			f.piece("wineRack", x, z, 90)
		end
	end
	for _, x in { -18, -15.5, 15.5, 18 } do
		f.piece("barrel", x, 16, 0)
	end
end

rooms[22] = function(f) -- Laundry. Doors W (wine cellar, z 0), S (tunnel, x 0) · back stair up on the east (x +16..+22) · wardrobe W (-12)
	f.piece("clothesline", -3, -6, 0)
	f.piece("clothesline", -3, 3, 0)
	f.piece("bathtub", -8, -15, 0, { scale = 0.7 })
	f.piece("boxPile", 9, 13, 0, { seed = 22 })
end

rooms[23] = function(f) -- Catacombs. Measured from (-50, 38). Doors N (tunnel, x 0), E (crypt, z -8) · the secret stair comes down along x -14..+8, z -16.5..-11.5 · niche S (+10)
	f.piece("coffin", 0, -5, 0, { scale = 0.8 })
	f.wall("shelf", "W", 4, { empty = true })
	f.wall("shelf", "W", -28, { empty = true })
	f.wall("shelf", "N", -10, { empty = true, scale = 0.7 })
	f.piece("candle", 4, 3, 0)
end

rooms[24] = function(f) -- Crypt (the lair). Archway N, door W (z +6) · wardrobes S (±26). The lair is in the middle.
	for _, x in { -22, 22 } do
		f.piece("coffin", x, -8, 0, { scale = 0.7 })
		f.piece("coffin", x, 10, 0, { scale = 0.7 })
	end
	f.piece("coffin", 0, 18, 90, { scale = 0.7, sheet = true })
	for _, x in { -28, 28 } do
		f.piece("pedestal", x, -20, 0)
		f.piece("candelabra", x, -20, 0, { y = 3 })
	end
end

rooms[25] = function(f) -- Cold Storage. Door N (tunnel, x 0) · butcher's slab (-6, 1)
	f.wall("shelf", "E", 0, { empty = true })
	f.piece("barrel", 12, 6, 0)
	f.piece("barrel", 14, 6, 0)
	f.piece("boxPile", 10, -5, 0, { seed = 25 })
	f.piece("candle", -6, 1, 0, { y = HIDE_TABLE_TOP })
end

return { rooms = rooms, HIDE_TABLE_TOP = HIDE_TABLE_TOP }
