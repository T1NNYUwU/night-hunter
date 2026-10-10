--!nonstrict
-- The DEFAULT furniture layout, room by room. This is only the starting point: Furniture.seed turns
-- it into independent Models in the house, and from then on the pieces in Studio are the truth.
--
-- Each room function receives a builder `f`:
--   f.piece(kind, x, z, yaw, opts)      room-local position (room centre = 0,0), front = -Z
--   f.wall(kind, side, along, opts)     against a wall ("N" "S" "E" "W"), front into the room
--   f.art(side, along, w, h, color)     a picture or mirror hung on a wall
--   f.rug(x, z, w, d, color)
-- opts: { y = lift above the floor, scale = number, seed = number, color = Color3 }
-- Kinds are listed in Furniture.lua (CATALOG). Hiding wardrobes and tables are placed from
-- HouseGraph, not here: a candelabra on a hiding table sits at y = HIDE_TABLE_TOP.

local HouseKit = require(script.Parent.HouseKit)

local RED, GREEN, BLUE = HouseKit.CLOTH_RED, HouseKit.CLOTH_GREEN, HouseKit.CLOTH_BLUE
local HIDE_TABLE_TOP = 3.1
local MIRROR = Color3.fromRGB(150, 170, 180)

local rooms = {}

rooms[1] = function(f) -- Foyer (spawn). Doors E,S · front door on the W wall (shell)
	f.rug(0, 0, 9, 7, RED)
	f.wall("drawer", "S", -7.5)
	f.piece("candelabra", -7.5, 10.2, 0, { y = f.size("drawer").Y })
	f.art("N", -5, 3, 4, Color3.fromRGB(80, 90, 70))
	f.piece("cobweb", -8.5, -8.5, 0, { scale = 0.45, y = 10.5 })
end

rooms[2] = function(f) -- Grand Hall. Doors W,E,S
	f.wall("cabinet", "N", 6)
	f.piece("pedestal", 2.5, -10.4, 0)
	f.piece("candelabra", 2.5, -10.4, 180, { y = 3 })
	f.art("S", -7, 4, 5, Color3.fromRGB(90, 60, 50))
	f.art("S", 7, 4, 5, Color3.fromRGB(60, 60, 90))
	f.rug(0, 0, 18, 5, RED)
	f.piece("cobweb", 8.5, 8.5, 90, { scale = 0.45, y = 10.5 })
end

rooms[3] = function(f) -- Library. Doors W,E · hiding table (-6,-6)
	f.wall("shelf", "S", -5)
	f.wall("shelf", "N", 6, { scale = 0.9 })
	f.piece("chair", -6, -10.1, 180)
	f.piece("candelabra", -6, -6, 0, { y = HIDE_TABLE_TOP })
	f.rug(-5.5, -5, 9, 8, GREEN)
end

rooms[4] = function(f) -- Study. Doors W,S · hiding desk (-5.5,-8)
	f.piece("chair", -5.5, -4.2, 180)
	f.piece("candelabra", -5.5, -8, 180, { y = HIDE_TABLE_TOP })
	f.wall("shelf", "N", 6, { scale = 0.8 })
	f.wall("cabinet", "W", -7)
	f.art("W", 7, 3, 4, Color3.fromRGB(70, 50, 40))
end

rooms[5] = function(f) -- Storeroom. Doors N,E
	f.wall("shelf", "S", 2)
	f.piece("boxPile", 8, 4.5, 0, { seed = 5 })
	f.piece("boxPile", -8, 6, 0, { seed = 55 })
	f.wall("drawer", "N", 7)
	f.piece("cobweb", 8, 8, 0, { scale = 0.5, y = 10.5 })
	f.piece("cobweb", -8, -8, 180, { scale = 0.45, y = 10.5 })
end

rooms[6] = function(f) -- Living room. Doors W,N,S · fireplace on the E wall
	f.wall("fireplace", "E", 0)
	f.piece("armchair", 5.4, -5, -90, { color = RED })
	f.piece("armchair", 5.4, 5, -90, { color = RED })
	f.rug(6, 0, 6, 10, BLUE)
	f.wall("drawer", "S", -7.5)
	f.art("W", -7, 4, 3, Color3.fromRGB(120, 90, 60))
end

rooms[7] = function(f) -- Gallery. Doors E,S
	f.art("N", -6, 4, 5, Color3.fromRGB(70, 40, 40))
	f.art("N", 1, 3, 4, Color3.fromRGB(40, 50, 70))
	f.art("N", 7.5, 3.5, 5, Color3.fromRGB(80, 70, 40))
	f.art("W", -6, 4, 5, Color3.fromRGB(60, 30, 60))
	for _, z in { -7, 7 } do
		f.piece("pedestal", -5, z, 0)
		f.piece("candelabra", -5, z, 0, { y = 3 })
	end
	f.rug(0, 0, 6, 16, RED)
end

rooms[8] = function(f) -- Bedroom. Doors W,N,S
	f.wall("bed", "S", 6.5)
	f.wall("drawer", "N", -7)
	f.piece("chair", -8.5, 6, 90)
	f.piece("candle", -7, -10.3, 0, { y = 3.6 })
	f.art("W", -7, 3, 3, Color3.fromRGB(90, 70, 80))
end

rooms[9] = function(f) -- Kitchen. Doors E,S · hiding table (7,6)
	f.wall("counter", "N", 1)
	f.piece("sink", 3, -10.2, 0, { y = 3.5 })
	f.piece("stove", -8, -10.25, 180)
	f.piece("fridge", 10, -10, 180)
	f.piece("chair", 3.2, 6, -90)
	f.piece("chair", 10.8, 6, 90)
end

rooms[10] = function(f) -- Dining room. Doors W,E,N,S · hiding table (-6.5,-6.5)
	f.piece("chair", -10, -6.5, -90)
	f.piece("chair", -2.7, -6.5, 90)
	f.piece("candelabra", -6.5, -6.5, 0, { y = HIDE_TABLE_TOP })
	f.wall("cabinet", "E", -7)
	f.art("W", 7, 3, 3, Color3.fromRGB(70, 60, 50))
end

rooms[11] = function(f) -- Hallway. Doors W,E,N,S
	f.piece("clock", -9.5, -10.2, 180)
	f.art("N", 7, 3, 4, Color3.fromRGB(80, 60, 50))
	f.art("W", 7, 3, 4, Color3.fromRGB(50, 60, 80))
	f.rug(0, 0, 20, 4, RED)
	f.rug(0, 0, 4, 20, RED)
	f.piece("cobweb", -8.5, 8.5, 270, { scale = 0.45, y = 10.5 })
end

rooms[12] = function(f) -- Master bedroom. Doors W,N,S
	f.wall("bed", "S", 6.5, { scale = 1.1 })
	f.wall("drawer", "N", -7)
	f.wall("cabinet", "W", 7)
	f.art("N", -7, 3, 3.5, MIRROR, { y = 6, material = Enum.Material.Glass })
	f.piece("candelabra", -9, -10.3, 180, { y = f.size("drawer").Y })
	f.rug(6.5, 2, 7, 6, BLUE)
end

rooms[13] = function(f) -- Pantry. Doors N,E
	f.wall("shelf", "W", -5, { scale = 0.9 })
	f.wall("shelf", "S", 5, { scale = 0.9 })
	for _, x in { 5.5, 8, 10.2 } do
		f.piece("barrel", x, -10, 0)
	end
	f.piece("boxPile", 6, 4.5, 0, { seed = 13 })
	f.piece("cobweb", 8, 8, 0, { scale = 0.5, y = 10.5 })
end

rooms[14] = function(f) -- Servants' room. Doors N,W
	f.wall("bed", "E", -5)
	f.piece("chair", -8.5, -8, 90)
	f.piece("smallTable", -6, -9.8, 0)
	f.piece("candle", -6, -9.8, 0, { y = 2.6 })
	f.piece("cobweb", -8.5, 8.5, 0, { scale = 0.45, y = 10.5 })
end

rooms[15] = function(f) -- Nursery. Doors N,E
	f.piece("crib", -10, -6, 0)
	f.piece("rockingHorse", 6, -6, 0)
	f.piece("toyBlocks", 5.5, 7.5, 0)
	f.wall("drawer", "W", 4.5)
end

rooms[16] = function(f) -- Bathroom. Doors W,N
	f.wall("bathtub", "S", -6.5)
	f.piece("vanity", -7, -10.4, 180)
	f.art("N", -7, 3, 3.5, MIRROR, { y = 6, material = Enum.Material.Glass })
	f.piece("toilet", 9.8, 10.2, 0)
end

return { rooms = rooms, HIDE_TABLE_TOP = HIDE_TABLE_TOP }
