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

rooms[1] = function(f) -- Entrance Hall (88 x 92). Measured from (0, 10). Imperial stair at the back, monument z +36, altar +40.5, carpet from the front door.
	f.rug(0, 65, 18, 34, RED)
	for _, x in { -12, 12 } do
		f.piece("pedestal", x, 78, 0)
		f.piece("candelabra", x, 78, 0, { y = 3 })
	end
	for _, x in { -16, 16 } do
		f.piece("pedestal", x, 52, 0)
		f.piece("statuette", x, 52, 180, { y = 3 })
	end
	for _, sx in { -1, 1 } do
		-- armour standing guard along the colonnade
		for _, z in { 51, 61 } do
			f.piece("suitOfArmor", sx * 32.5, z, sx * 90) -- (facing into the hall)
		end
		-- tall candelabra by the feet of the stairs and under the landing
		f.piece("standingCandelabra", sx * 18, 36, 0)
		f.piece("standingCandelabra", sx * 9, 20, 0)
	end
	for _, x in { -40, 40 } do
		f.piece("planter", x, 76, 0)
	end
	f.wall("clock", "S", 32)
	f.wall("clock", "S", -32)
	f.art("N", -12, 2.8, 3.9, nil, { kind = "antlers", y = 11 })
	f.art("N", 12, 4, 5, Color3.fromRGB(70, 50, 40))
	for _, side in { "W", "E" } do -- behind the colonnade
		for _, z in { 14, 22, 42, 50, 68, 78 } do -- (the doors to the library and dining room are at z +31)
			f.art(side, z, 4, 5)
		end
	end
	for _, x in { -22, -13, 13, 22 } do
		f.art("S", x, 4, 5)
	end
end

rooms[2] = function(f) -- Library. Doors E (to the hall, z +10), N (to the study, x +15) · secret stair along the north (x -14..+10, z -12.5..-7.5) · reading table (0, 2)
	f.wall("shelf", "S", -6)
	f.wall("shelf", "S", 6.5, { scale = 0.7 })
	f.wall("shelf", "E", -4, { scale = 0.7 })
	f.wall("shelf", "W", -3, { scale = 0.7 }) -- the bookcase by the secret stair
	f.wall("fireplace", "W", 7)
	f.piece("armchair", -8, 7.8, 90, { color = GREEN })
	f.piece("candelabra", 0, 2, 0, { y = HIDE_TABLE_TOP })
	f.piece("chair", 0, 6.6, 0)
	f.rug(0, 2, 14, 10, GREEN)
	f.art("S", 13, 3, 4, Color3.fromRGB(80, 90, 70), { tilt = 7 })
end

rooms[3] = function(f) -- Dining Room. Doors W (to the hall, z +10), N (to the kitchen, x 0) · dining table (0, 0) · china cabinet S (+10)
	f.piece("chair", -4.6, 0, -90)
	f.piece("chair", 4.6, 0, 90)
	f.piece("chair", 0, 5.2, 0)
	f.piece("candelabra", 0, 0, 0, { y = HIDE_TABLE_TOP })
	f.rug(0, 0, 18, 14, RED)
	f.wall("fireplace", "E", 0)
	f.wall("drawer", "S", -8)
	f.wall("cabinet", "S", 3)
	f.piece("chair", 0, -5.2, 180)
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
	f.art("W", -7.5, 3, 4, Color3.fromRGB(70, 50, 40))
end

rooms[5] = function(f) -- Ballroom. Archway S (corridor), doors W, E (z 0) · wardrobe N (-14). The floor stays empty but for the piano.
	f.piece("piano", 6, -7, 160)
	f.wall("clock", "N", -6)
	for _, z in { -12, -7, 8 } do
		f.wall("chair", "W", z, { sheet = z == 8 })
	end
	for _, z in { 8, 12 } do
		f.wall("chair", "E", z)
	end
	for _, x in { -19, 19 } do
		f.piece("pedestal", x, 15, 0)
		f.piece("statuette", x, 15, 180, { y = 3 })
	end
		f.art("S", -14, 3, 5, nil, { kind = "mirror" })
	f.art("S", 14, 3, 5, nil, { kind = "mirror" })
end

rooms[6] = function(f) -- Kitchen. Doors N (corridor), S (dining), both x 0 · table (-4, 1) · pantry W (+5)
	f.wall("counter", "N", -11, { scale = 0.85 })
	f.piece("sink", -11, -7, 0, { y = 3.5 })
	f.wall("stove", "N", 7)
	f.wall("fridge", "N", 13)
	f.piece("chair", -8.8, 1, -90)
	f.piece("candle", -4, 1, 0, { y = HIDE_TABLE_TOP })
	f.wall("barrel", "S", -9)
	f.wall("barrel", "S", -11.6)
	f.wall("cabinet", "S", 10)
	f.wall("shelf", "E", 0, { scale = 0.7 })
end

rooms[7] = function(f) -- Conservatory (glass walls, moonlit). Doors E (ballroom, z 0), S (corridor, x 0) · potting cabinet W (+9)
	f.piece("fountain", 0, 4, 0)
	for _, x in { -17, -7, 7, 17 } do
		f.wall("planter", "N", x)
	end
	for _, z in { -10, 15 } do
		f.wall("planter", "W", z)
		f.wall("planter", "E", z + 1)
	end
	f.piece("chair", -7, -3, -135, { color = DUSTY })
	f.piece("chair", 7, -3, 135, { color = DUSTY })
	f.piece("statuette", 0, -12, 180)
	f.wall("gardenBench", "W", 2.5)
	f.wall("gardenBench", "E", 7.5)
	f.piece("mourner", -12, 4, -90)
	f.piece("mourner", 12, 4, 90)
	f.wall("drawer", "S", -16)
end

rooms[8] = function(f) -- Servants' Hall. Doors W (ballroom, z 0), S (corridor, x 0) · back stairs on the east (x +4..+22) · long table (-5, 0)
	f.piece("longTable", -13, 0, 90)
	for _, x in { -13, -5 } do
		f.piece("chair", x, -5.2, 180)
		f.piece("chair", x, 5.2, 0)
	end
	f.piece("candle", -5, 0, 0, { y = HIDE_TABLE_TOP })
	f.wall("cabinet", "W", -12)
	f.wall("cabinet", "W", 12)
	f.wall("shelf", "N", -12, { empty = true })
	f.wall("clock", "S", -14)
	f.wall("counter", "N", 2, { scale = 0.7 })
	f.wall("barrel", "S", 8)
	f.wall("barrel", "S", 10.6)
	f.piece("boxPile", -22, 13, 0, { seed = 8 })
end

rooms[9] = function(f) -- Main Corridor (136 x 16). Doors on both sides; nothing in the way
	f.rug(0, 0, 124, 7, RED)
	f.wall("clock", "N", -30)
	f.wall("drawer", "N", -38)
	f.piece("candlesticks", -38, -5.6, 0, { y = 4 })
	f.wall("chair", "N", 15)
	f.wall("chair", "N", 40, { sheet = true })
	for _, x in { -35, 35 } do
		f.wall("suitOfArmor", "S", x)
	end
	for _, x in { -11, 11 } do -- flanking the archway to the hall
		f.piece("pedestal", x, 6.2, 0)
		f.piece("candelabra", x, 6.2, 180, { y = 3 })
	end
	for _, x in { -60, -22, 22, 60 } do
		f.art("N", x, 3.5, 4.5, Color3.fromRGB(60, 46, 40), { tilt = if x == 22 then 6 else 0 })
	end
	for _, x in { -72, -22, 22, 72 } do
		f.art("S", x, 3, 4, Color3.fromRGB(50, 46, 60))
	end
end

-- FLOOR 2 --------------------------------------------------------------------------------------------

rooms[10] = function(f) -- Landing: the rear balcony (z -7..+5), the bowed landing, and the galleries (x +-34..44) round the hall to the front wall. Archway N; doors W (z 0, z +27), E (z +27)
	f.rug(0, -1, 56, 6, RED)
	for _, x in { -14, 14 } do
		f.piece("pedestal", x, -5.5, 0)
		f.piece("candelabra", x, -5.5, 0, { y = 3 })
	end
	f.art("N", 12, 4, 5, Color3.fromRGB(70, 40, 40))
	for _, x in { -40, 40 } do
		f.piece("standingCandelabra", x * 0.75, -5.5, 0)
		f.wall("chair", "S", x * 0.3)
	end
	for _, side in { "W", "E" } do
		f.rug(if side == "W" then -39 else 39, 41, 6, 66, RED)
		f.art(side, 14, 3, 4, Color3.fromRGB(60, 50, 70))
		f.art(side, 38, 3, 4, Color3.fromRGB(70, 60, 50))
	end
	for _, x in { -24, 24 } do
		f.art("S", x, 4, 5)
	end
	for _, x in { -19, 19 } do
		f.wall("suitOfArmor", "S", x)
	end
end

rooms[11] = function(f) -- Upper Corridor (136 x 16)
	f.rug(0, 0, 124, 7, BLUE)
	f.wall("clock", "N", 30)
	f.wall("drawer", "N", -38)
	f.piece("candle", -38, -5.6, 0, { y = 4 })
	f.wall("chair", "N", -15)
	f.wall("chair", "N", 40)
	f.wall("cabinet", "S", 35)
	for _, x in { -11, 11 } do -- flanking the archway to the landing
		f.piece("pedestal", x, 6.2, 0)
		f.piece("statuette", x, 6.2, 180, { y = 3 })
	end
	for _, x in { -60, -22, 22, 60 } do
		f.art("N", x, 3.5, 4.5, Color3.fromRGB(56, 50, 64))
	end
	for _, x in { -72, -22, 72 } do
		f.art("S", x, 3, 4, Color3.fromRGB(70, 56, 46), { tilt = if x == -22 then -7 else 0 })
	end
end

rooms[12] = function(f) -- Nursery (36 x 20). Doors N (corridor) and S (lady's bedroom), both x 0; E (balcony, z -3) · wardrobe S (+10)
	f.wall("childBed", "W", -5.5)
	f.wall("smallTable", "W", 0)
	f.piece("candle", -15.6, 0, 0, { y = 2.6 })
	f.wall("childBed", "W", 5.5)
	f.wall("crib", "N", -11)
	f.wall("drawer", "N", 10.5)
	f.wall("cabinet", "S", -11) -- the toy cupboard
	f.piece("rockingHorse", 5, 2, 90)
	f.piece("toyBlocks", -3, -4, 0)
	f.piece("toyBlocks", 9, 5, 90)
	f.rug(-4, 0, 14, 10, Color3.fromRGB(140, 110, 100))
	f.art("E", 6.5, 3, 4, Color3.fromRGB(110, 90, 80))
	f.art("S", -4.5, 3, 4, Color3.fromRGB(110, 90, 80))
end

rooms[13] = function(f) -- Lady's Bedroom (36 x 28). Doors N (nursery, x 0), E (side gallery, z 0) · wardrobe N (+12)
	f.wall("fourPoster", "S", 0, { color = PURPLE })
	f.wall("smallTable", "S", -6.6)
	f.piece("candle", -6.6, 12, 0, { y = 2.6 })
	f.wall("fireplace", "W", -4)
	f.wall("drawer", "W", 8.5)
	f.wall("dressingTable", "N", -11)
	f.art("N", -11, 3, 4.8, nil, { kind = "mirror" })
	f.piece("chair", -11, -9.5, 180)
	f.piece("armchair", -8, -4, 90, { color = RED })
	f.rug(0, 4, 16, 14, RED)
	f.art("E", 8, 3, 4.8, nil, { kind = "mirror" })
	f.art("S", -12, 3, 4, Color3.fromRGB(90, 70, 80))
	f.art("S", 12, 3, 4, Color3.fromRGB(70, 50, 56))
end

rooms[14] = function(f) -- Bathroom. Doors N (corridor), S (guest bedroom), both x 0 · linen cupboard E (-4). The tub stands free.
	f.piece("bathtub", -8, 1, 90)
	f.wall("vanity", "W", 4)
	f.art("W", 4, 3, 4, nil, { kind = "mirror", y = 7, tilt = -4 })
	f.wall("toilet", "E", 6)
	f.wall("cabinet", "W", -5)
	f.piece("chair", 10, 5, 200)
	f.piece("foldingScreen", -3.6, 1, 90)
	f.wall("smallTable", "S", -10)
	f.piece("candle", -10, 7.9, 0, { y = 2.6 })
	f.wall("drawer", "S", 9)
	f.rug(-8, 1, 6, 10, Color3.fromRGB(120, 130, 128))
	f.piece("standingCandelabra", -12, -5, 0)
	f.piece("washtub", 6, 6, 0)
	f.wall("shelf", "N", 10, { scale = 0.7 })
	f.art("N", -10, 3.5, 4.5, Color3.fromRGB(60, 50, 46))
end

rooms[15] = function(f) -- Guest Bedroom. Doors N (bathroom, x 0), W (side gallery, z 0) · wardrobe N (-12). Twin beds on the south wall.
	f.wall("bed", "S", -6, { sheet = true })
	f.wall("bed", "S", 6, { color = GREEN })
	f.wall("smallTable", "S", 0)
	f.piece("candle", 0, 12, 0, { y = 2.6 })
	f.wall("fireplace", "E", -4)
	f.wall("drawer", "N", 10)
	f.piece("armchair", 9, -4, -90, { color = GREEN, sheet = true })
	f.rug(0, 2, 18, 12, GREEN)
	f.art("W", 8, 3, 4, Color3.fromRGB(80, 90, 70), { tilt = 6 })
end

rooms[16] = function(f) -- Master Bedroom (58 x 38), the largest room upstairs. Door S (corridor, x 0) · wardrobe W (+7)
	f.wall("fourPoster", "N", 0, { color = BLUE })
	for _, x in { -6.6, 6.6 } do
		f.wall("smallTable", "N", x)
		f.piece("candle", x, -16.9, 0, { y = 2.6 })
	end
	f.wall("fireplace", "E", 0)
	for _, z in { -4.5, 4.5 } do -- a pair of armchairs by the fire
		f.piece("armchair", 17, z, -90, { color = BLUE })
	end
	f.piece("smallTable", 17, 0, -90)
	f.wall("drawer", "W", -8)
	f.art("W", -8, 3, 4.8, nil, { kind = "mirror" })
	f.wall("dressingTable", "W", -15)
	f.wall("cabinet", "S", -14)
	f.wall("cabinet", "S", 14)
	f.wall("shelf", "S", 22, { scale = 0.7 })
	f.wall("clock", "S", -22)
	f.rug(0, -5, 24, 18, BLUE)
	f.rug(16, 0, 8, 14, RED)
	for _, z in { -11, 11 } do
		f.art("E", z, 4, 5)
	end
	for _, x in { -18, 18 } do
		f.art("N", x, 4, 5)
	end
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
	f.wall("chair", "W", -12)
	f.wall("chair", "E", -12)
	f.wall("suitOfArmor", "W", 13)
	f.wall("suitOfArmor", "E", 13)
	for _, x in { -6, 6 } do
		f.piece("standingCandelabra", x, -15, 0)
	end
	f.wall("displayCase", "W", 7.5)
	f.wall("displayCase", "E", 7.5)
end

rooms[18] = function(f) -- Maid's Room. Door S (corridor, x 0) · back stair down on the east (x +4..+13) · wardrobe W (-10). Two iron cots.
	f.wall("ironBed", "N", -15)
	f.wall("smallTable", "N", -10.5)
	f.wall("ironBed", "N", -6)
	f.wall("drawer", "N", -0.5)
	f.piece("chair", -6, 6, 20)
	f.piece("boxPile", -16, 12, 0, { seed = 18 })
	f.wall("cabinet", "S", -18)
	f.wall("dressingTable", "W", 8)
	f.wall("shelf", "S", -8, { scale = 0.7, empty = true })
	f.rug(-10, -6, 16, 12, DUSTY)
end

-- BASEMENT -------------------------------------------------------------------------------------------

rooms[19] = function(f) -- Service Tunnel (136 x 16)
	for _, x in { -64, -34, 30, 62 } do
		f.wall("barrel", "N", x)
	end
	f.wall("shelf", "S", -30, { empty = true, scale = 0.7 })
	f.wall("shelf", "S", 30, { empty = true, scale = 0.7 })
	f.piece("boxPile", -20, 5, 0, { seed = 19 })
	f.piece("boxPile", 16, -5, 0, { seed = 91 })
	f.wall("cabinet", "S", 45)
	f.wall("workbench", "N", 14)
	f.wall("cabinet", "N", -20)
	f.wall("barrel", "S", -45)
	f.wall("barrel", "S", -42.4)
end

rooms[20] = function(f) -- Boiler Room. Doors E (wine cellar, z 0), S (tunnel, x 0) · wardrobe W (+9)
	f.piece("boiler", -5, -1, 0)
	f.piece("boxPile", 8, 8, 0, { seed = 13 })
	f.piece("barrel", 19, -12, 0)
	f.piece("barrel", 19, -9.5, 0)
	f.wall("shelf", "N", 8, { empty = true })
	f.wall("shelf", "N", -14, { empty = true, scale = 0.7 })
	f.piece("boxPile", -20, 10, 0, { seed = 31 })
	f.piece("barrel", -24, -14, 0)
	f.wall("counter", "S", 16, { scale = 0.7 })
	f.wall("workbench", "E", -10)
	f.wall("workbench", "W", -8)
	f.wall("cabinet", "S", -14)
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
	f.wall("wineCask", "N", -6)
	f.wall("wineCask", "N", 6)
end

rooms[22] = function(f) -- Laundry. Doors W (wine cellar, z 0), S (tunnel, x 0) · back stair up on the east (x +16..+22) · wardrobe W (-12)
	f.piece("clothesline", -3, -6, 0)
	f.piece("clothesline", -3, 3, 0)
	f.piece("bathtub", -8, -15, 0, { scale = 0.7 })
	f.piece("boxPile", 9, 13, 0, { seed = 22 })
	f.wall("counter", "N", -19)
	f.wall("shelf", "N", 6, { empty = true, scale = 0.7 })
	f.wall("cabinet", "W", 8)
	f.piece("barrel", -24, 13, 0)
	f.piece("barrel", -21.5, 13.5, 0)
	f.piece("boxPile", -19, -11, 0, { seed = 44 })
	f.wall("washtub", "S", 8)
	f.wall("washtub", "S", 13.5)
end

rooms[23] = function(f) -- Catacombs. Measured from (-50, 38). Doors N (tunnel, x 0), E (crypt, z -8) · the secret stair comes down along x -14..+8, z -16.5..-11.5 · niche S (+10)
	f.piece("coffin", 0, -1, 0, { scale = 0.8 })
	f.wall("shelf", "W", 2, { empty = true })
	f.wall("shelf", "W", -28, { empty = true })
	f.wall("shelf", "N", -10, { empty = true, scale = 0.7 })
	f.piece("candle", 4, 3, 0)
	f.piece("coffin", 9, -28, 90, { scale = 0.8 })
	f.piece("coffin", -9, 5.5, 90, { scale = 0.7, sheet = true })
	f.piece("pedestal", -13, -30, 0)
	f.piece("candelabra", -13, -30, 0, { y = 3 })
	f.piece("sarcophagus", -12, -24, 0)
	f.piece("mourner", 13, 7, 0)
end

rooms[24] = function(f) -- Crypt (the lair). Archway N, door W (z +6) · wardrobes S (±26). The lair is in the middle.
	for _, x in { -22, 22 } do
		f.piece("coffin", x, -8, 0, { scale = 0.7 })
		f.piece("coffin", x, 10, 0, { scale = 0.7 })
	end
	f.piece("coffin", 0, 18, 90, { scale = 0.7, sheet = true })
	for _, x in { -14, 14 } do
		f.piece("standingCandelabra", x, 20, 0)
	end
	for _, x in { -28, 28 } do
		f.piece("pedestal", x, -20, 0)
		f.piece("candelabra", x, -20, 0, { y = 3 })
	end
	for _, x in { -28, 28 } do
		f.piece("pedestal", x, 16, 0)
		f.piece("candelabra", x, 16, 0, { y = 3 })
	end
	f.piece("sarcophagus", -36, -12, 0)
	f.piece("sarcophagus", 36, -12, 0)
	f.piece("sarcophagus", 36, 10, 0)
	for _, x in { -10, 10 } do
		f.piece("mourner", x, -19, 180)
	end
end

rooms[25] = function(f) -- Cold Storage. Door N (tunnel, x 0) · butcher's slab (-6, 1)
	f.wall("shelf", "E", 0, { empty = true })
	f.piece("barrel", 11.4, 7.6, 0)
	f.piece("barrel", 14.2, 7.6, 0)
	f.piece("boxPile", 10, -5, 0, { seed = 25 })
	f.piece("candle", -6, 1, 0, { y = HIDE_TABLE_TOP })
	f.wall("meatRack", "W", -4)
	f.wall("meatRack", "S", -9)
	f.wall("barrel", "N", 9)
	f.wall("barrel", "N", 11.6)
end

return { rooms = rooms, HIDE_TABLE_TOP = HIDE_TABLE_TOP }
