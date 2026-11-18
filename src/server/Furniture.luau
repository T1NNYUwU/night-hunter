--!nonstrict
-- Furniture: every piece is its OWN Model in Workspace.NightHunterHouse.Furniture/<Room>/,
-- so it can be selected, moved, rotated, resized or deleted in Studio. Nothing about a piece is
-- baked into the room, and rebuilding the house shell never touches this folder.
--
-- A piece is a rough BLOCK placeholder (position, shape, size) for now. Each Model has
--   attributes  Kind (e.g. "bed"), Room (1-25), Placeholder (true)
--   pivot       its floor centre (WorldPivot), front = -Z
-- To swap in real art later, put a model named like the Kind's `asset` in ServerStorage.AssetLibrary
-- and seed with style "assets" (see seed()), or replace pieces by hand and leave them alone.
--
-- Hiding spots (wardrobes, cloth tables) are furniture too, but they are tied to a hide node of
-- HouseGraph: keep each one inside its own room (HideService reads attributes Node and Kind).
--
-- The default layout is data: FurnitureLayout.luau.

local CollectionService = game:GetService("CollectionService")

local HouseGraph = require(game:GetService("ReplicatedStorage"):WaitForChild("NightHunter"):WaitForChild("HouseGraph"))
local HouseKit = require(script.Parent.HouseKit)
local HouseDecor = require(script.Parent.HouseDecor)
local FurnitureLayout = require(script.Parent.FurnitureLayout)

local box, placer, light = HouseKit.box, HouseKit.placer, HouseKit.light
local WOOD, WOOD_DARK, WOOD_LIGHT = HouseKit.WOOD, HouseKit.WOOD_DARK, HouseKit.WOOD_LIGHT
local DIRTY_WHITE, BRASS, METAL, WARM_LIGHT = HouseKit.DIRTY_WHITE, HouseKit.BRASS, HouseKit.METAL, HouseKit.WARM_LIGHT
local WALL_FACE, WALL_YAW = HouseKit.WALL_FACE, HouseKit.WALL_YAW

local Furniture = {}
Furniture.VERSION = 21 -- bump when FurnitureLayout changes; saved furniture is NOT rebuilt automatically
Furniture.HIDE_TAG = "NightHunterHideSpot"

local V = Vector3.new
local WALL_TRIM = 0.62 -- furniture stands this far off the wall's face, clear of the panelling and chair rail

-- Small things you should never get stuck on: no collision at all. Everything else gets ONE smooth invisible
-- box instead of colliding with its legs, cushions and knobs.
local WALK_THROUGH = {
	chair = true, standingCandelabra = true, candle = true, candelabra = true, candlesticks = true, statuette = true, barrel = true, boxPile = true,
	planter = true, toyBlocks = true, rockingHorse = true, smallTable = true, sink = true, toilet = true, clothesline = true,
	rug = true, painting = true, mirror = true, antlers = true, cobweb = true,
}

---------------------------------------------------------------- block builders
-- build(model, base, size, entry, opts) -> main part. `base` = world CFrame of the floor centre,
-- front = -Z. Offsets are from that point.

local function part(m, base, name, size, offset, color, material, collide)
	return box(m, name, size, base * CFrame.new(offset), color, material or Enum.Material.Wood, collide)
end

local function frontMark(m, base, size, y)
	part(m, base, "Front", V(size.X * 0.7, 0.12, 0.08), V(0, y or size.Y * 0.8, -size.Z / 2 - 0.04), BRASS, Enum.Material.Metal, false)
end

local function block(front: boolean?)
	return function(m, base, size, e, opts)
		local main = part(m, base, "Body", size, V(0, size.Y / 2, 0), (opts and opts.color) or e.color, e.material)
		if front then
			frontMark(m, base, size)
		end
		return main
	end
end

local function flame(m, base, offset, withLight)
	-- (offset = where the old block flame's centre was: the wick stands 0.15 below it)
	return HouseKit.flame(m, base * CFrame.new(offset - V(0, 0.15, 0)), 0.32, if withLight then 8 else 5)
end

local builders = {}

builders.armchair = function(m, base, size, e, opts)
	local color = (opts and opts.color) or HouseKit.CLOTH_RED
	local mat = (opts and opts.material) or Enum.Material.Fabric
	local dark = color:Lerp(Color3.new(0, 0, 0), 0.3)
	local w, d = size.X, size.Z
	local seat = part(m, base, "Base", V(w, 1.1, d), V(0, 1.15, 0), dark, mat)
	part(m, base, "Back", V(w, size.Y - 1.1, 0.7), V(0, (size.Y + 1.1) / 2, d / 2 - 0.35), color, mat)
	part(m, base, "BackRoll", V(w + 0.1, 0.45, 0.85), V(0, size.Y - 0.1, d / 2 - 0.35), dark, mat)
	for _, sx in { -1, 1 } do
		part(m, base, "Arm", V(0.6, 1.5, d - 0.3), V(sx * (w / 2 - 0.3), 2.4, -0.15), color, mat)
		part(m, base, "ArmRoll", V(0.8, 0.35, d - 0.2), V(sx * (w / 2 - 0.3), 3.25, -0.15), dark, mat)
		for _, sz in { -1, 1 } do
			part(m, base, "Leg", V(0.35, 0.6, 0.35), V(sx * (w / 2 - 0.4), 0.3, sz * (d / 2 - 0.4)), WOOD_DARK)
		end
	end
	local count = math.max(1, math.floor(w / 3))
	local cw = (w - 1.3) / count
	for i = 1, count do
		part(m, base, "Cushion", V(cw - 0.1, 0.5, d - 1), V(-w / 2 + 0.65 + (i - 0.5) * cw, 1.95, -0.3), color, mat)
	end
	return seat
end

builders.smallTable = function(m, base, size)
	local top = part(m, base, "Top", V(size.X, 0.22, size.Z), V(0, size.Y - 0.11, 0), WOOD)
	part(m, base, "Apron", V(size.X - 0.5, 0.5, size.Z - 0.5), V(0, size.Y - 0.47, 0), WOOD_DARK)
	part(m, base, "Drawer", V(size.X * 0.5, 0.34, 0.06), V(0, size.Y - 0.47, -size.Z / 2 + 0.23), WOOD)
	part(m, base, "Pull", V(0.3, 0.1, 0.08), V(0, size.Y - 0.47, -size.Z / 2 + 0.17), BRASS, Enum.Material.Metal)
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			local x, z = sx * (size.X / 2 - 0.32), sz * (size.Z / 2 - 0.32)
			part(m, base, "Leg", V(0.26, size.Y - 0.3, 0.26), V(x, (size.Y - 0.3) / 2, z), WOOD_DARK)
			part(m, base, "Foot", V(0.36, 0.3, 0.36), V(x, 0.15, z), WOOD)
		end
	end
	return top
end

builders.counter = function(m, base, size)
	local body = part(m, base, "Body", V(size.X, size.Y - 0.7, size.Z - 0.2), V(0, (size.Y - 0.7) / 2 + 0.4, 0.1), Color3.fromRGB(138, 130, 112), Enum.Material.Wood)
	part(m, base, "Plinth", V(size.X, 0.4, size.Z - 0.5), V(0, 0.2, 0.25), WOOD_DARK)
	part(m, base, "Top", V(size.X + 0.2, 0.3, size.Z + 0.2), V(0, size.Y - 0.15, 0), Color3.fromRGB(60, 60, 64), Enum.Material.Granite)
	local count = math.floor(size.X / 2.4)
	local w = size.X / count
	for i = 1, count do
		local x = -size.X / 2 + (i - 0.5) * w
		part(m, base, "Door", V(w - 0.3, size.Y - 1.3, 0.08), V(x, (size.Y - 0.7) / 2 + 0.4, -size.Z / 2 + 0.06), Color3.fromRGB(112, 104, 90), Enum.Material.Wood)
		part(m, base, "Pull", V(0.12, 0.6, 0.1), V(x + w / 2 - 0.45, size.Y - 1.4, -size.Z / 2 - 0.01), BRASS, Enum.Material.Metal)
	end
	return body
end

builders.sink = function(m, base, size)
	return part(m, base, "Basin", size, V(0, size.Y / 2, 0), METAL, Enum.Material.Metal, false)
end

-- Victorian wash stand: dark wood cupboard, stained marble top with a splash back, a sunken basin.
builders.vanity = function(m, base, size)
	local marble = Color3.fromRGB(150, 144, 132)
	local h = size.Y - 0.3 -- cupboard height under the top
	part(m, base, "Plinth", V(size.X - 0.2, 0.3, size.Z - 0.3), V(0, 0.15, 0.05), WOOD_DARK, Enum.Material.Wood)
	local body = part(m, base, "Body", V(size.X - 0.2, h - 0.3, size.Z - 0.2), V(0, 0.3 + (h - 0.3) / 2, 0.05), WOOD_DARK, Enum.Material.Wood)
	for _, sx in { -1, 1 } do
		local x = sx * (size.X / 4 - 0.05)
		part(m, base, "Door", V(size.X / 2 - 0.4, h - 0.9, 0.08), V(x, 0.3 + (h - 0.3) / 2, -size.Z / 2 + 0.06), WOOD, Enum.Material.Wood)
		part(m, base, "Pull", V(0.1, 0.1, 0.1), V(sx * 0.35, 0.3 + (h - 0.3) / 2, -size.Z / 2 - 0.02), BRASS, Enum.Material.Metal)
	end
	part(m, base, "Top", V(size.X, 0.25, size.Z), V(0, h + 0.125, 0), marble, Enum.Material.Marble)
	part(m, base, "Splash", V(size.X, 1, 0.2), V(0, h + 0.75, size.Z / 2 - 0.1), marble, Enum.Material.Marble)
	part(m, base, "Basin", V(1.8, 0.3, 1.2), V(0, h + 0.27, -0.1), Color3.fromRGB(176, 170, 156), Enum.Material.Marble, false)
	part(m, base, "Water", V(1.5, 0.05, 0.9), V(0, h + 0.4, -0.1), Color3.fromRGB(30, 26, 22), Enum.Material.Glass, false)
	part(m, base, "Tap", V(0.12, 0.5, 0.12), V(0, h + 0.5, 0.45), BRASS, Enum.Material.Metal, false)
	frontMark(m, base, size, size.Y * 0.5)
	return body
end

-- Dressing table: drawers either side of a knee hole, a triple mirror with a brass crest, a ring of dim warm bulbs
-- round the middle glass (they flicker with the house), and a low stool in a dull red. Front = -Z, wall at +Z.
builders.dressingTable = function(m, base, size, e, opts)
	local k = size.X / 5 -- drawn at 5 wide, then scaled to the asked size
	size = V(5, 7, 1.8)
	local wood = (opts and opts.color) or WOOD_DARK
	local cushion = Color3.fromRGB(86, 30, 32)
	local topY = 3
	local hz = size.Z / 2
	local top = part(m, base, "Top", V(size.X, 0.2, size.Z), V(0, topY - 0.1, 0), wood)
	part(m, base, "TopEdge", V(size.X + 0.06, 0.06, 0.06), V(0, topY - 0.17, -hz - 0.02), BRASS, Enum.Material.Metal, false)
	-- legs (tapered: a thick upper part, a slim lower part, a brass foot)
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			local x, z = sx * (size.X / 2 - 0.2), sz * (hz - 0.2)
			part(m, base, "Leg", V(0.3, 1.2, 0.3), V(x, topY - 0.8, z), wood)
			part(m, base, "Leg", V(0.2, 1.6, 0.2), V(x, 0.8, z), wood)
			part(m, base, "Foot", V(0.24, 0.12, 0.24), V(x, 0.06, z), BRASS, Enum.Material.Metal, false)
		end
		-- a stack of two drawers on each side
		local px = sx * (size.X / 2 - 0.85)
		part(m, base, "Pedestal", V(1.5, 1.5, size.Z - 0.3), V(px, topY - 0.95, 0), wood)
		for k = 0, 1 do
			local y = topY - 0.55 - k * 0.72
			part(m, base, "Drawer", V(1.32, 0.6, 0.06), V(px, y, -hz + 0.12), WOOD, Enum.Material.Wood, false)
			local knob = part(m, base, "Knob", V(0.12, 0.12, 0.12), V(px, y, -hz + 0.05), BRASS, Enum.Material.Metal, false)
			knob.Shape = Enum.PartType.Ball
		end
	end
	part(m, base, "Apron", V(size.X - 3.2, 0.45, 0.08), V(0, topY - 0.45, -hz + 0.12), WOOD, Enum.Material.Wood, false)
	part(m, base, "Knob", V(0.3, 0.08, 0.08), V(0, topY - 0.45, -hz + 0.05), BRASS, Enum.Material.Metal, false)

	-- triple mirror on the back of the top
	local glass = function(name, w, h, cf)
		local g = box(m, name, V(w, h, 0.05), cf, Color3.fromRGB(52, 56, 62), Enum.Material.Glass, false)
		g.Reflectance = 0.3
		return g
	end
	local mz = hz - 0.25
	local mh = 3.4
	local mid = base * CFrame.new(0, topY + 0.15 + mh / 2, mz)
	box(m, "Mirror frame", V(2.4, mh, 0.14), mid * CFrame.new(0, 0, 0.06), wood, Enum.Material.Wood, false)
	glass("Mirror", 2.0, mh - 0.4, mid * CFrame.new(0, 0, -0.04))
	local crest = box(m, "Crest", V(0.1, 0.8, 0.8), mid * CFrame.new(0, mh / 2 + 0.05, 0.04) * CFrame.Angles(0, math.pi / 2, 0), BRASS, Enum.Material.Metal, false)
	crest.Shape = Enum.PartType.Cylinder -- a brass disc half above the frame
	for _, sx in { -1, 1 } do
		local hinge = mid * CFrame.new(sx * 1.2, -0.3, 0) * CFrame.Angles(0, sx * math.rad(25), 0) -- wings fold forward, toward the stool
		local wing = hinge * CFrame.new(sx * 0.55, 0, 0)
		box(m, "Mirror frame", V(1.1, mh - 0.6, 0.12), wing * CFrame.new(0, 0, 0.06), wood, Enum.Material.Wood, false)
		glass("Mirror", 0.85, mh - 0.95, wing * CFrame.new(0, 0, -0.03))
	end
	-- bulbs round the middle glass: 4 along the top, 3 down each side
	local spots = {}
	for i = 0, 3 do
		table.insert(spots, V(-0.75 + i * 0.5, mh / 2 - 0.1, -0.1))
	end
	for _, sx in { -1, 1 } do
		for k = 0, 2 do
			table.insert(spots, V(sx * 1.08, 0.9 - k * 0.9, -0.1))
		end
	end
	for i, p in spots do
		local bulb = box(m, "Bulb", V(0.2, 0.2, 0.2), mid * CFrame.new(p), Color3.fromRGB(214, 150, 92), Enum.Material.Neon, false)
		bulb.Shape = Enum.PartType.Ball
		bulb.CastShadow = false
		if i == 2 then
			light(bulb, WARM_LIGHT, 10, 0.55, true)
		end
	end
	-- a perfume bottle and a dish on the top
	local bottle = part(m, base, "Bottle", V(0.18, 0.4, 0.18), V(-1.6, topY + 0.2, 0.2), Color3.fromRGB(70, 60, 50), Enum.Material.Glass, false)
	bottle.Shape = Enum.PartType.Cylinder
	bottle.CFrame = base * CFrame.new(-1.6, topY + 0.2, 0.2) * CFrame.Angles(0, 0, math.pi / 2)
	part(m, base, "Dish", V(0.6, 0.05, 0.4), V(1.5, topY + 0.03, 0.1), BRASS, Enum.Material.Metal, false)

	-- the stool, tucked in the knee hole
	local sy, sz0 = 1.5, -hz - 0.15
	part(m, base, "Stool seat", V(1.5, 0.3, 1.1), V(0, sy, sz0), cushion, Enum.Material.Fabric, false)
	part(m, base, "Stool rail", V(1.55, 0.14, 1.15), V(0, sy - 0.2, sz0), wood, Enum.Material.Wood, false)
	for _, sx in { -1, 1 } do
		for _, s2 in { -1, 1 } do
			part(m, base, "Stool leg", V(0.14, sy - 0.27, 0.14), V(sx * 0.62, (sy - 0.27) / 2, sz0 + s2 * 0.42), wood, Enum.Material.Wood, false)
		end
	end
	if math.abs(k - 1) > 0.01 then
		local pivot = m.WorldPivot
		m.WorldPivot = base
		m:ScaleTo(k)
		m.WorldPivot = pivot
	end
	return top
end

builders.toilet = function(m, base, size)
	local bowl = part(m, base, "Bowl", V(size.X, 1.8, size.Z), V(0, 0.9, 0), DIRTY_WHITE, Enum.Material.SmoothPlastic)
	part(m, base, "Tank", V(size.X, 1.6, 0.8), V(0, 2.6, size.Z / 2 - 0.4), DIRTY_WHITE, Enum.Material.SmoothPlastic)
	return bowl
end

builders.bathtub = function(m, base, size)
	local tub = part(m, base, "Tub", size, V(0, size.Y / 2, 0), DIRTY_WHITE, Enum.Material.SmoothPlastic)
	part(m, base, "Water", V(size.X - 0.8, 0.1, size.Z - 0.8), V(0, size.Y - 0.2, 0), Color3.fromRGB(46, 20, 16), Enum.Material.Glass, false) -- (old water, gone rusty red)
	return tub
end

builders.barrel = function(m, base, size)
	local p = box(m, "Barrel", V(size.Y, size.X, size.Z), base * CFrame.new(0, size.Y / 2, 0) * CFrame.Angles(0, 0, math.pi / 2), WOOD, Enum.Material.WoodPlanks)
	p.Shape = Enum.PartType.Cylinder
	for _, y in { 0.2, 0.5, 0.8 } do
		local hoop = box(m, "Hoop", V(0.22, size.X + 0.12, size.Z + 0.12), base * CFrame.new(0, size.Y * y, 0) * CFrame.Angles(0, 0, math.pi / 2), METAL, Enum.Material.CorrodedMetal)
		hoop.Shape = Enum.PartType.Cylinder
	end
	return p
end

builders.pedestal = function(m, base, size)
	return part(m, base, "Body", size, V(0, size.Y / 2, 0), DIRTY_WHITE, Enum.Material.Marble)
end

builders.crib = function(m, base, size)
	local frame = part(m, base, "Base", V(size.X, 1.2, size.Z), V(0, 1.8, 0), WOOD_LIGHT)
	for _, sx in { -1, 1 } do
		for i = 0, 8 do
			part(m, base, "Bar", V(0.15, 2.4, 0.15), V(sx * (size.X / 2 - 0.2), 3.6, -size.Z / 2 + 0.4 + i * (size.Z - 0.8) / 8), WOOD_LIGHT, Enum.Material.Wood, false)
		end
	end
	for _, sz in { -1, 1 } do
		part(m, base, "End", V(size.X, 2.6, 0.2), V(0, 3.4, sz * (size.Z / 2 - 0.1)), WOOD_LIGHT)
	end
	return frame
end

builders.rockingHorse = function(m, base, size)
	local paint = Color3.fromRGB(176, 150, 124)
	local body = part(m, base, "Body", V(1, 1.1, 2.4), V(0, 2.3, 0), paint)
	part(m, base, "Saddle", V(1.08, 0.3, 1), V(0, 2.9, 0.1), HouseKit.CLOTH_RED, Enum.Material.Fabric)
	box(m, "Neck", V(0.75, 1.5, 0.8), base * CFrame.new(0, 3.2, -1.15) * CFrame.Angles(math.rad(25), 0, 0), paint, Enum.Material.Wood)
	part(m, base, "Head", V(0.7, 0.75, 1.4), V(0, 3.95, -1.85), paint)
	part(m, base, "Muzzle", V(0.55, 0.5, 0.4), V(0, 3.8, -2.6), Color3.fromRGB(70, 56, 46))
	part(m, base, "Mane", V(0.2, 1.8, 0.4), V(0, 3.6, -0.8), Color3.fromRGB(30, 24, 20), Enum.Material.Fabric)
	for _, sx in { -1, 1 } do
		part(m, base, "Eye", V(0.04, 0.16, 0.16), V(sx * 0.37, 4.1, -2), Color3.new(0, 0, 0), Enum.Material.Neon)
		for _, sz in { -1, 1 } do
			box(m, "Leg", V(0.3, 1.5, 0.3), base * CFrame.new(sx * 0.36, 1.2, sz * 1) * CFrame.Angles(math.rad(sz * 16), 0, 0), paint, Enum.Material.Wood)
		end
		for i = -2, 2 do
			box(m, "Rocker", V(0.25, 0.25, 0.95), base * CFrame.new(sx * 0.42, 0.14 + i * i * 0.075, i * 0.85) * CFrame.Angles(math.rad(-i * 9), 0, 0), WOOD_DARK, Enum.Material.Wood)
		end
	end
	return body
end

builders.toyBlocks = function(m, base)
	local colors = { HouseKit.CLOTH_RED, HouseKit.CLOTH_BLUE, BRASS, HouseKit.CLOTH_GREEN }
	local first
	for i = 1, 4 do
		local b = part(m, base, "Block", V(0.8, 0.8, 0.8), V(i * 0.9 - 2.2, 0.4, (i % 2) * 0.8 - 0.4), colors[i], Enum.Material.SmoothPlastic)
		first = first or b
	end
	return first
end

builders.boxPile = function(m, base, size, e, opts)
	local rng = Random.new((opts and opts.seed) or 1)
	local first
	for i = 1, 5 do
		local s = rng:NextNumber(1.6, 3)
		local b = part(m, base, "Box", V(s, s * 0.8, s), V(rng:NextNumber(-0.8, 0.8) , s * 0.4 + (if i > 3 then 1.6 else 0), (i % 3) * 1.4 - 1.4), Color3.fromRGB(150, 120, 80), Enum.Material.Cardboard)
		b.CFrame *= CFrame.Angles(0, math.rad(rng:NextNumber(-20, 20)), 0)
		first = first or b
	end
	return first
end

builders.candle = function(m, base, size, e, opts)
	local c = part(m, base, "Candle", V(0.3, 0.8, 0.3), V(0, 0.4, 0), DIRTY_WHITE, Enum.Material.SmoothPlastic, false)
	flame(m, base, V(0, 0.95, 0), not (opts and opts.noLight))
	return c
end

builders.candelabra = function(m, base, size)
	local pole = part(m, base, "Pole", V(0.2, 2.6, 0.2), V(0, 1.3, 0), BRASS, Enum.Material.Metal, false)
	part(m, base, "Foot", V(0.8, 0.2, 0.8), V(0, 0.1, 0), BRASS, Enum.Material.Metal, false)
	part(m, base, "Arm", V(0.9, 0.15, 0.15), V(0, 2.65, 0), BRASS, Enum.Material.Metal, false)
	for i, x in { -0.35, 0, 0.35 } do
		flame(m, base, V(x, 3.0, 0), i == 2)
	end
	return pole
end

-- A big clay pot with a dead plant.
builders.planter = function(m, base, size)
	local pot = box(m, "Pot", V(size.Y * 0.5, size.X, size.X), base * CFrame.new(0, size.Y * 0.25, 0) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(112, 64, 46), Enum.Material.Slate)
	pot.Shape = Enum.PartType.Cylinder
	local rim = box(m, "Rim", V(0.3, size.X + 0.25, size.X + 0.25), base * CFrame.new(0, size.Y * 0.5, 0) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(92, 52, 38), Enum.Material.Slate)
	rim.Shape = Enum.PartType.Cylinder
	local soil = box(m, "Soil", V(0.1, size.X - 0.3, size.X - 0.3), base * CFrame.new(0, size.Y * 0.5 + 0.12, 0) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(26, 20, 16), Enum.Material.Ground)
	soil.Shape = Enum.PartType.Cylinder
	-- a dead tree: bare forked branches
	local rng = Random.new(math.floor(base.Position.X * 3 + base.Position.Z * 7))
	local wood = Color3.fromRGB(44, 34, 26)
	for i = 1, 5 do
		local yaw = (i / 5) * math.pi * 2 + rng:NextNumber(-0.4, 0.4)
		local lean = rng:NextNumber(0.25, 0.6)
		local len = size.Y * rng:NextNumber(0.5, 0.8)
		local stem = base * CFrame.new(0, size.Y * 0.5, 0) * CFrame.Angles(0, yaw, 0) * CFrame.Angles(lean, 0, 0) * CFrame.new(0, len / 2, 0)
		box(m, "Branch", V(0.14, len, 0.14), stem, wood, Enum.Material.Wood, false)
		box(m, "Twig", V(0.08, len * 0.45, 0.08), stem * CFrame.new(0, len * 0.25, 0) * CFrame.Angles(0.8, 0, 0) * CFrame.new(0, len * 0.22, 0), wood, Enum.Material.Wood, false)
	end
	return pot
end

-- A washing line between two posts, with grey sheets hanging still (front = -Z, the line runs along X).
builders.clothesline = function(m, base, size)
	local wood = Color3.fromRGB(70, 56, 44)
	for _, sx in { -1, 1 } do
		box(m, "Post", V(0.4, size.Y, 0.4), base * CFrame.new(sx * size.X / 2, size.Y / 2, 0), wood, Enum.Material.Wood)
	end
	local line = box(m, "Line", V(size.X, 0.08, 0.08), base * CFrame.new(0, size.Y - 0.3, 0), Color3.fromRGB(40, 40, 40), Enum.Material.SmoothPlastic, false)
	for i, x in { -6, -1.5, 3.5, 7.5 } do
		local h = if i % 2 == 0 then 5.5 else 6.5
		box(m, "Sheet", V(3.6, h, 0.1), base * CFrame.new(x, size.Y - 0.3 - h / 2, 0), Color3.fromRGB(150, 150, 146), Enum.Material.Fabric, false)
	end
	return line
end

builders.rug = function(m, base, size, e, opts)
	local color = (opts and opts.color) or HouseKit.CLOTH_RED
	local r = part(m, base, "Rug", size, V(0, 0.07, 0), color, Enum.Material.Fabric, false) -- (above every floor inlay)
	part(m, base, "RugBorder", V(size.X - 0.8, 0.07, size.Z - 0.8), V(0, 0.075, 0), color:Lerp(Color3.new(0, 0, 0), 0.35), Enum.Material.Fabric, false)
	return r
end

builders.stove = function(m, base, size)
	local iron = Color3.fromRGB(40, 38, 40)
	local body = part(m, base, "Body", V(size.X, size.Y - 0.5, size.Z), V(0, (size.Y - 0.5) / 2 + 0.5, 0), iron, Enum.Material.Metal)
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			part(m, base, "Foot", V(0.3, 0.5, 0.3), V(sx * (size.X / 2 - 0.3), 0.25, sz * (size.Z / 2 - 0.3)), iron, Enum.Material.Metal)
		end
		local plate = box(m, "Hob", V(0.06, 0.8, 0.8), base * CFrame.new(sx * 0.65, size.Y + 0.03, 0) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(26, 26, 28), Enum.Material.Metal)
		plate.Shape = Enum.PartType.Cylinder
	end
	part(m, base, "OvenDoor", V(size.X - 0.6, 1.3, 0.08), V(0, 1.5, -size.Z / 2 - 0.04), Color3.fromRGB(60, 56, 54), Enum.Material.Metal)
	part(m, base, "Handle", V(size.X - 1, 0.1, 0.16), V(0, 2.3, -size.Z / 2 - 0.14), BRASS, Enum.Material.Metal)
	return body
end

builders.fridge = function(m, base, size) -- an old icebox with latches
	local cream = Color3.fromRGB(176, 170, 150)
	local body = part(m, base, "Body", V(size.X, size.Y - 0.6, size.Z), V(0, (size.Y - 0.6) / 2 + 0.6, 0), cream, Enum.Material.SmoothPlastic)
	part(m, base, "Base", V(size.X - 0.4, 0.6, size.Z - 0.4), V(0, 0.3, 0), Color3.fromRGB(32, 30, 30), Enum.Material.Metal)
	for _, door in { { 0.6 + size.Y * 0.28, size.Y * 0.5 }, { size.Y * 0.8, size.Y * 0.36 } } do
		part(m, base, "Door", V(size.X - 0.2, door[2], 0.1), V(0, door[1], -size.Z / 2 - 0.05), cream:Lerp(Color3.new(0, 0, 0), 0.1), Enum.Material.SmoothPlastic)
		part(m, base, "Latch", V(0.22, 0.9, 0.2), V(size.X / 2 - 0.4, door[1], -size.Z / 2 - 0.18), Color3.fromRGB(150, 150, 150), Enum.Material.Metal)
	end
	return body
end

builders.wineRack = function(m, base, size)
	local dark = WOOD_DARK
	local body = part(m, base, "Back", V(size.X, size.Y, 0.2), V(0, size.Y / 2, size.Z / 2 - 0.1), dark)
	for _, x in { -size.X / 2 + 0.2, -size.X / 6, size.X / 6, size.X / 2 - 0.2 } do
		part(m, base, "Post", V(0.3, size.Y, size.Z), V(x, size.Y / 2, 0), dark)
	end
	local glass = { Color3.fromRGB(20, 40, 26), Color3.fromRGB(44, 14, 18), Color3.fromRGB(16, 22, 18) }
	local rng = Random.new(math.floor(base.Position.X * 11 + base.Position.Z * 5))
	for row = 0, 3 do
		local y = 0.15 + row * 1.7
		part(m, base, "Shelf", V(size.X, 0.14, size.Z), V(0, y, 0), WOOD)
		for i = 1, 11 do
			if rng:NextNumber() > 0.18 then
				local x = -size.X / 2 + 0.2 + i * (size.X - 0.4) / 12
				local bottle = box(m, "Bottle", V(1.3, 0.48, 0.48), base * CFrame.new(x, y + 0.34, 0) * CFrame.Angles(0, math.pi / 2, 0), glass[rng:NextInteger(1, 3)], Enum.Material.Glass, false)
				bottle.Shape = Enum.PartType.Cylinder
				bottle.CastShadow = false
			end
		end
	end
	return body
end

builders.boiler = function(m, base, size)
	local iron = Color3.fromRGB(72, 62, 54)
	local tank = box(m, "Tank", V(size.Y - 1.4, size.X, size.Z), base * CFrame.new(0, 1.4 + (size.Y - 1.4) / 2, 0) * CFrame.Angles(0, 0, math.pi / 2), iron, Enum.Material.CorrodedMetal)
	tank.Shape = Enum.PartType.Cylinder
	part(m, base, "Firebox", V(size.X, 1.4, size.Z), V(0, 0.7, 0), Color3.fromRGB(40, 36, 34), Enum.Material.Brick)
	for _, y in { 0.3, 0.55, 0.8 } do
		local band = box(m, "Band", V(0.3, size.X + 0.2, size.Z + 0.2), base * CFrame.new(0, size.Y * y, 0) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(46, 40, 36), Enum.Material.Metal)
		band.Shape = Enum.PartType.Cylinder
	end
	local door = part(m, base, "FurnaceGlow", V(2, 0.9, 0.08), V(0, 0.75, -size.Z / 2 - 0.02), Color3.fromRGB(255, 96, 30), Enum.Material.Neon)
	light(door, Color3.fromRGB(255, 110, 50), 22, 1.1, true)
	for i = -2, 2 do
		part(m, base, "Grate", V(0.1, 1, 0.1), V(i * 0.4, 0.75, -size.Z / 2 - 0.08), Color3.new(0, 0, 0), Enum.Material.Metal)
	end
	local gauge = box(m, "Gauge", V(0.15, 1.1, 1.1), base * CFrame.new(1.3, 5.8, -size.Z / 2 + 0.2) * CFrame.Angles(0, math.pi / 2, 0), BRASS, Enum.Material.Metal)
	gauge.Shape = Enum.PartType.Cylinder
	part(m, base, "Pipe", V(0.8, 7.5, 0.8), V(0, size.Y + 3.2, 0), Color3.fromRGB(58, 52, 48), Enum.Material.CorrodedMetal)
	part(m, base, "SidePipe", V(size.X + 7, 0.6, 0.6), V(3.5, 5, size.Z / 2 + 0.5), Color3.fromRGB(58, 52, 48), Enum.Material.CorrodedMetal)
	return tank
end

builders.slab = function(m, base, size)
	local steel = Color3.fromRGB(120, 124, 122)
	local top = part(m, base, "Top", V(size.X, 0.3, size.Z), V(0, size.Y - 0.15, 0), steel, Enum.Material.DiamondPlate)
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			part(m, base, "Leg", V(0.3, size.Y - 0.3, 0.3), V(sx * (size.X / 2 - 0.3), (size.Y - 0.3) / 2, sz * (size.Z / 2 - 0.3)), METAL, Enum.Material.CorrodedMetal)
		end
	end
	part(m, base, "Stain", V(size.X * 0.6, 0.02, size.Z * 0.5), V(0.2, size.Y + 0.01, 0.4), Color3.fromRGB(60, 10, 10), Enum.Material.SmoothPlastic)
	return top
end

-- A funeral urn in old bronze: foot, swelling body, narrow neck, lid and finial.
builders.statuette = function(m, base, size)
	local bronze = Color3.fromRGB(62, 54, 40)
	local dark = Color3.fromRGB(38, 34, 28)
	local h, w = size.Y, size.X
	local function disc(name, height, diameter, y, color)
		local p = box(m, name, V(height, diameter, diameter), base * CFrame.new(0, y, 0) * CFrame.Angles(0, 0, math.pi / 2), color, Enum.Material.Metal, false)
		p.Shape = Enum.PartType.Cylinder
		return p
	end
	local foot = disc("Foot", h * 0.05, w * 0.62, h * 0.025, dark)
	disc("Stem", h * 0.12, w * 0.26, h * 0.11, bronze)
	disc("Collar", h * 0.03, w * 0.42, h * 0.18, dark)
	local body = box(m, "Body", V(w, h * 0.5, w), base * CFrame.new(0, h * 0.44, 0), bronze, Enum.Material.Metal, false)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = body
	disc("Band", h * 0.03, w * 0.99, h * 0.46, dark)
	disc("Neck", h * 0.1, w * 0.36, h * 0.73, bronze)
	disc("Lip", h * 0.03, w * 0.56, h * 0.79, dark)
	disc("Lid", h * 0.05, w * 0.48, h * 0.83, bronze)
	disc("Spire", h * 0.06, w * 0.12, h * 0.89, dark)
	local finial = box(m, "Finial", V(w * 0.2, w * 0.2, w * 0.2), base * CFrame.new(0, h * 0.95, 0), bronze, Enum.Material.Metal, false)
	finial.Shape = Enum.PartType.Ball
	return foot
end

---------------------------------------------------------------- the mansion's own furniture
-- Everything below is built from parts, so its front is always -Z and it stands exactly on its footprint.

local LACQUER = Color3.fromRGB(44, 26, 18)
local GILT = Color3.fromRGB(128, 98, 50) -- old gilt, dulled by years of candle smoke
local GILT_DARK = Color3.fromRGB(78, 58, 30)
local M_WOOD, M_METAL, M_FABRIC = Enum.Material.Wood, Enum.Material.Metal, Enum.Material.Fabric

local function cyl(m, base, name, height, dia, offset, color, material) -- an upright cylinder centred on offset
	local p = box(m, name, V(height, dia, dia), base * CFrame.new(offset) * CFrame.Angles(0, 0, math.pi / 2), color, material or M_WOOD, false)
	p.Shape = Enum.PartType.Cylinder
	return p
end

local function ball(m, base, name, dia, offset, color, material)
	local p = box(m, name, V(dia, dia, dia), base * CFrame.new(offset), color, material or M_WOOD, false)
	p.Shape = Enum.PartType.Ball
	return p
end

local function dial(m, base, name, dia, offset, color, material) -- a disc facing -Z
	local p = box(m, name, V(0.08, dia, dia), base * CFrame.new(offset) * CFrame.Angles(0, math.pi / 2, 0), color, material or M_METAL, false)
	p.Shape = Enum.PartType.Cylinder
	return p
end

-- A turned post from y0 up `h`: square foot, slim shaft, collars, a ball on top.
local function turnedLeg(m, base, x, z, y0, h, d, color)
	part(m, base, "PostFoot", V(d * 1.3, h * 0.08, d * 1.3), V(x, y0 + h * 0.04, z), color)
	cyl(m, base, "PostShaft", h * 0.84, d * 0.72, V(x, y0 + h * 0.5, z), color)
	cyl(m, base, "PostCollar", h * 0.03, d * 1.1, V(x, y0 + h * 0.2, z), color)
	cyl(m, base, "PostBulge", h * 0.1, d * 1.05, V(x, y0 + h * 0.32, z), color)
	cyl(m, base, "PostCollar", h * 0.03, d * 1.1, V(x, y0 + h * 0.82, z), color)
	ball(m, base, "PostBall", d * 1.05, V(x, y0 + h * 0.95, z), color)
end

-- Mattress, coverlet falling over the sides, turned-back linen and pillows. Head at +Z.
local function bedding(m, base, w, d, top, cloth, pillows)
	local dark = cloth:Lerp(Color3.new(0, 0, 0), 0.3)
	part(m, base, "Mattress", V(w - 0.3, 0.9, d - 0.3), V(0, top - 0.45, 0), DIRTY_WHITE, M_FABRIC)
	part(m, base, "Coverlet", V(w + 0.12, 0.34, d * 0.72), V(0, top + 0.03, -d * 0.14), cloth, M_FABRIC)
	for _, sx in { -1, 1 } do
		part(m, base, "CoverDrop", V(0.1, 1.4, d * 0.72), V(sx * (w / 2 + 0.11), top - 0.65, -d * 0.14), cloth, M_FABRIC)
		part(m, base, "CoverHem", V(0.13, 0.22, d * 0.72), V(sx * (w / 2 + 0.11), top - 1.3, -d * 0.14), dark, M_FABRIC)
	end
	part(m, base, "CoverFoot", V(w + 0.3, 1.4, 0.1), V(0, top - 0.65, -d / 2 - 0.02), cloth, M_FABRIC)
	part(m, base, "Linen", V(w + 0.14, 0.38, d * 0.13), V(0, top + 0.06, d * 0.27), Color3.fromRGB(214, 206, 188), M_FABRIC)
	part(m, base, "Quilting", V(w * 0.72, 0.03, d * 0.5), V(0, top + 0.21, -d * 0.16), dark, M_FABRIC)
	local count = pillows or 2
	for i = 1, count do
		local x = (i - (count + 1) / 2) * (w / count)
		box(m, "Pillow", V(w / count - 0.35, 0.62, 1.6), base * CFrame.new(x, top + 0.34, d / 2 - 1.1) * CFrame.Angles(math.rad(-12), 0, 0), Color3.fromRGB(206, 198, 180), M_FABRIC, false)
	end
end

-- A heavy carved headboard: rails, panels, an arched crest.
local function headboard(m, base, w, h, z, color)
	part(m, base, "HeadPanel", V(w, h - 1.2, 0.35), V(0, (h - 1.2) / 2 + 0.2, z), color)
	for i = -1, 1 do
		part(m, base, "HeadInset", V(w / 3 - 0.55, h * 0.36, 0.08), V(i * w / 3, h * 0.55, z - 0.2), color:Lerp(Color3.new(1, 0.7, 0.45), 0.1))
	end
	part(m, base, "HeadRail", V(w + 0.4, 0.3, 0.55), V(0, h - 1, z), LACQUER)
	part(m, base, "CrestLow", V(w * 0.62, 0.45, 0.4), V(0, h - 0.65, z), color)
	part(m, base, "CrestHigh", V(w * 0.36, 0.42, 0.4), V(0, h - 0.22, z), color)
	ball(m, base, "CrestBoss", 0.55, V(0, h - 0.5, z - 0.22), GILT, M_METAL)
end

local function bedFrame(m, base, w, d, color)
	local rail = part(m, base, "SideRail", V(0.32, 0.9, d), V(-w / 2 + 0.16, 1.05, 0), color)
	part(m, base, "SideRail", V(0.32, 0.9, d), V(w / 2 - 0.16, 1.05, 0), color)
	part(m, base, "FootRail", V(w, 0.9, 0.32), V(0, 1.05, -d / 2 + 0.16), color)
	part(m, base, "Slats", V(w - 0.3, 0.3, d - 0.3), V(0, 1.2, 0), LACQUER)
	return rail
end

-- A four-poster with tester, valance and tied-back drapes.
builders.fourPoster = function(m, base, size, e, opts)
	local w, h, d = size.X, size.Y, size.Z
	local cloth = (opts and opts.color) or HouseKit.CLOTH_RED
	local dark = cloth:Lerp(Color3.new(0, 0, 0), 0.32)
	local frame = bedFrame(m, base, w - 0.9, d - 0.9, LACQUER)
	bedding(m, base, w - 1.5, d - 1.5, 2.7, cloth)
	headboard(m, base, w - 0.8, 6.8, d / 2 - 0.55, WOOD_DARK)
	part(m, base, "Footboard", V(w - 0.8, 2.6, 0.3), V(0, 1.9, -d / 2 + 0.5), WOOD_DARK)
	part(m, base, "FootCap", V(w - 0.5, 0.25, 0.48), V(0, 3.3, -d / 2 + 0.5), LACQUER)
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			local x, z = sx * (w / 2 - 0.45), sz * (d / 2 - 0.45)
			turnedLeg(m, base, x, z, 0, h - 0.5, 0.75, LACQUER)
			-- a drape gathered and tied to each post
			part(m, base, "Drape", V(1.1, h - 4.2, 0.22), V(x - sx * 0.55, h - 1.5 - (h - 4.2) / 2, z - sz * 0.3), dark, M_FABRIC)
			part(m, base, "DrapeTie", V(1.2, 0.26, 0.3), V(x - sx * 0.55, h * 0.5, z - sz * 0.3), GILT, M_FABRIC)
			part(m, base, "DrapeSkirt", V(1.5, 2.6, 0.26), V(x - sx * 0.7, 1.9, z - sz * 0.3), dark, M_FABRIC)
		end
		part(m, base, "TesterSide", V(0.4, 0.55, d), V(sx * (w / 2 - 0.3), h - 0.4, 0), LACQUER)
		part(m, base, "ValanceSide", V(0.14, 1.25, d - 0.2), V(sx * (w / 2 - 0.02), h - 1.25, 0), cloth, M_FABRIC)
		part(m, base, "ValanceFringe", V(0.17, 0.18, d - 0.2), V(sx * (w / 2 - 0.02), h - 1.9, 0), GILT, M_FABRIC)
	end
	part(m, base, "TesterEnd", V(w, 0.55, 0.4), V(0, h - 0.4, -d / 2 + 0.3), LACQUER)
	part(m, base, "TesterEnd", V(w, 0.55, 0.4), V(0, h - 0.4, d / 2 - 0.3), LACQUER)
	part(m, base, "ValanceFront", V(w - 0.2, 1.25, 0.14), V(0, h - 1.25, -d / 2 + 0.02), cloth, M_FABRIC)
	part(m, base, "ValanceFringe", V(w - 0.2, 0.18, 0.17), V(0, h - 1.9, -d / 2 + 0.02), GILT, M_FABRIC)
	part(m, base, "Canopy", V(w - 0.3, 0.16, d - 0.3), V(0, h - 0.65, 0), dark, M_FABRIC)
	part(m, base, "BackDrape", V(w - 1.6, h - 7.4, 0.14), V(0, h - 1 - (h - 7.4) / 2, d / 2 - 0.55), dark, M_FABRIC)
	return frame
end

-- A carved wooden bed with a tall headboard.
builders.bed = function(m, base, size, e, opts)
	local w, h, d = size.X, size.Y, size.Z
	local frame = bedFrame(m, base, w - 0.4, d - 0.5, WOOD_DARK)
	bedding(m, base, w - 0.9, d - 1.1, 2.6, (opts and opts.color) or HouseKit.CLOTH_GREEN)
	headboard(m, base, w, h, d / 2 - 0.2, WOOD_DARK)
	part(m, base, "Footboard", V(w - 0.3, 2.9, 0.3), V(0, 1.75, -d / 2 + 0.25), WOOD_DARK)
	part(m, base, "FootCap", V(w, 0.26, 0.48), V(0, 3.3, -d / 2 + 0.25), LACQUER)
	for _, sx in { -1, 1 } do
		turnedLeg(m, base, sx * (w / 2 - 0.25), -d / 2 + 0.25, 0, 4.1, 0.5, LACQUER)
		turnedLeg(m, base, sx * (w / 2 - 0.25), d / 2 - 0.25, 0, h + 0.2, 0.55, LACQUER)
	end
	return frame
end

-- A servant's iron cot.
builders.ironBed = function(m, base, size, e, opts)
	local w, h, d = size.X, size.Y, size.Z
	local iron = Color3.fromRGB(38, 38, 40)
	local frame = part(m, base, "Frame", V(w, 0.2, d), V(0, 1.2, 0), iron, M_METAL)
	bedding(m, base, w - 0.35, d - 0.7, 2.15, (opts and opts.color) or Color3.fromRGB(96, 92, 82), 1)
	for _, e2 in { { d / 2 - 0.1, h }, { -d / 2 + 0.1, h - 1 } } do
		local z, top = e2[1], e2[2]
		for _, sx in { -1, 1 } do
			cyl(m, base, "IronPost", top, 0.22, V(sx * (w / 2 - 0.1), top / 2, z), iron, M_METAL)
			ball(m, base, "IronKnob", 0.34, V(sx * (w / 2 - 0.1), top + 0.1, z), GILT_DARK, M_METAL)
		end
		box(m, "IronRail", V(0.14, w - 0.2, 0.14), base * CFrame.new(0, top - 0.3, z) * CFrame.Angles(0, 0, math.pi / 2), iron, M_METAL, false)
		box(m, "IronRail", V(0.14, w - 0.2, 0.14), base * CFrame.new(0, 2, z) * CFrame.Angles(0, 0, math.pi / 2), iron, M_METAL, false)
		for i = -2, 2 do
			cyl(m, base, "IronBar", top - 2.3, 0.1, V(i * w / 6, (top + 2) / 2 - 0.15, z), iron, M_METAL)
		end
	end
	return frame
end

-- A child's bed, painted white long ago, with spindled sides and a rag doll left on it.
builders.childBed = function(m, base, size, e, opts)
	local w, h, d = size.X, size.Y, size.Z
	local paint = Color3.fromRGB(176, 166, 150)
	local frame = bedFrame(m, base, w - 0.3, d - 0.3, paint)
	bedding(m, base, w - 0.75, d - 0.9, 2.2, (opts and opts.color) or Color3.fromRGB(128, 84, 92), 1)
	headboard(m, base, w, h, d / 2 - 0.15, paint)
	part(m, base, "Footboard", V(w, 2.8, 0.26), V(0, 1.6, -d / 2 + 0.13), paint)
	for _, sx in { -1, 1 } do
		part(m, base, "GuardRail", V(0.16, 0.16, d * 0.55), V(sx * (w / 2 - 0.05), 3.5, d * 0.1), paint)
		for i = -2, 2 do
			cyl(m, base, "Spindle", 1.3, 0.12, V(sx * (w / 2 - 0.05), 2.85, d * 0.1 + i * d * 0.1), paint)
		end
		for _, sz in { -1, 1 } do
			ball(m, base, "Knob", 0.4, V(sx * (w / 2 - 0.1), (if sz > 0 then h else 3) + 0.15, sz * (d / 2 - 0.13)), paint)
		end
	end
	-- the doll
	local rag, skin = Color3.fromRGB(96, 60, 68), Color3.fromRGB(184, 164, 140)
	part(m, base, "DollBody", V(0.6, 0.3, 0.8), V(0.2, 2.7, 0.3), rag, M_FABRIC)
	ball(m, base, "DollHead", 0.5, V(0.2, 2.75, 0.95), skin, M_FABRIC)
	for _, sx in { -1, 1 } do
		ball(m, base, "DollEye", 0.07, V(0.2 + sx * 0.1, 3, 0.95), Color3.new(0, 0, 0), Enum.Material.SmoothPlastic)
		box(m, "DollLeg", V(0.18, 0.16, 0.7), base * CFrame.new(0.2 + sx * 0.2, 2.65, -0.42), skin, M_FABRIC, false)
	end
	return frame
end

builders.chair = function(m, base, size, e, opts)
	local w, h, d = size.X, size.Y, size.Z
	local cloth = (opts and opts.color) or HouseKit.CLOTH_RED
	local seat = part(m, base, "SeatFrame", V(w, 0.32, d), V(0, 2.2, 0), WOOD_DARK)
	part(m, base, "SeatPad", V(w - 0.3, 0.26, d - 0.3), V(0, 2.48, -0.03), cloth, M_FABRIC)
	for _, sx in { -1, 1 } do
		turnedLeg(m, base, sx * (w / 2 - 0.2), -d / 2 + 0.2, 0, 2.1, 0.36, WOOD_DARK)
		part(m, base, "RearLeg", V(0.28, 2.1, 0.28), V(sx * (w / 2 - 0.18), 1.05, d / 2 - 0.16), WOOD_DARK)
		part(m, base, "BackStile", V(0.3, h - 2.3, 0.26), V(sx * (w / 2 - 0.18), 2.3 + (h - 2.3) / 2, d / 2 - 0.16), WOOD_DARK)
		ball(m, base, "StileKnob", 0.4, V(sx * (w / 2 - 0.18), h + 0.04, d / 2 - 0.16), WOOD_DARK)
		part(m, base, "Stretcher", V(0.14, 0.14, d - 0.5), V(sx * (w / 2 - 0.18), 0.9, 0), WOOD_DARK)
	end
	part(m, base, "BackTop", V(w - 0.3, 0.42, 0.24), V(0, h - 0.3, d / 2 - 0.16), WOOD_DARK)
	part(m, base, "BackCrest", V(w * 0.44, 0.3, 0.22), V(0, h, d / 2 - 0.16), WOOD_DARK)
	part(m, base, "BackLow", V(w - 0.3, 0.26, 0.2), V(0, 3, d / 2 - 0.16), WOOD_DARK)
	part(m, base, "BackPad", V(w - 0.78, h - 3.8, 0.12), V(0, 3.15 + (h - 3.8) / 2, d / 2 - 0.2), cloth, M_FABRIC)
	return seat
end

-- A refectory table on turned legs.
builders.longTable = function(m, base, size)
	local w, h, d = size.X, size.Y, size.Z
	local top = part(m, base, "Top", V(w, 0.22, d), V(0, h - 0.11, 0), WOOD)
	part(m, base, "TopEdge", V(w + 0.14, 0.1, d + 0.14), V(0, h - 0.27, 0), WOOD_DARK)
	part(m, base, "Apron", V(w - 0.7, 0.55, d - 0.7), V(0, h - 0.6, 0), WOOD_DARK)
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			turnedLeg(m, base, sx * (w / 2 - 0.45), sz * (d / 2 - 0.45), 0, h - 0.5, 0.62, WOOD_DARK)
		end
	end
	part(m, base, "Stretcher", V(0.26, 0.26, d - 1), V(0, 0.65, 0), WOOD_DARK)
	return top
end

-- A chest of drawers with a marble top and brass swan-neck pulls.
builders.drawer = function(m, base, size)
	local w, h, d = size.X, size.Y, size.Z
	local body = part(m, base, "Carcass", V(w - 0.3, h - 0.9, d - 0.2), V(0, (h - 0.9) / 2 + 0.55, 0.05), WOOD_DARK)
	part(m, base, "MarbleTop", V(w + 0.1, 0.18, d + 0.1), V(0, h - 0.09, 0), Color3.fromRGB(120, 112, 106), Enum.Material.Marble)
	part(m, base, "TopMould", V(w, 0.1, d), V(0, h - 0.23, 0), LACQUER)
	part(m, base, "BaseMould", V(w, 0.24, d), V(0, 0.62, 0), LACQUER)
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			part(m, base, "BracketFoot", V(0.75, 0.52, 0.75), V(sx * (w / 2 - 0.4), 0.26, sz * (d / 2 - 0.4)), LACQUER)
		end
		part(m, base, "CornerFlute", V(0.2, h - 1.1, 0.1), V(sx * (w / 2 - 0.25), h / 2 + 0.15, -d / 2 + 0.04), LACQUER)
	end
	local rows = 3
	local rowH = (h - 1.15) / rows
	for r = 1, rows do
		local y = 0.76 + (r - 0.5) * rowH
		part(m, base, "DrawerFront", V(w - 0.8, rowH - 0.12, 0.1), V(0, y, -d / 2 + 0.02), WOOD)
		part(m, base, "DrawerInset", V(w - 1.3, rowH - 0.36, 0.04), V(0, y, -d / 2 - 0.05), WOOD_DARK)
		for _, sx in { -1, 1 } do
			local x = sx * w * 0.24
			dial(m, base, "PullPlate", 0.32, V(x, y + 0.04, -d / 2 - 0.09), GILT)
			part(m, base, "Pull", V(0.42, 0.06, 0.09), V(x, y - 0.06, -d / 2 - 0.15), GILT, M_METAL)
		end
	end
	return body
end

-- A china cabinet: cupboard below, glazed doors above with plates and cups behind them.
builders.cabinet = function(m, base, size)
	local w, h, d = size.X, size.Y, size.Z
	local body = part(m, base, "Lower", V(w, 3, d), V(0, 1.75, 0), WOOD_DARK)
	part(m, base, "Plinth", V(w + 0.2, 0.3, d + 0.15), V(0, 0.15, 0), LACQUER)
	part(m, base, "Waist", V(w + 0.2, 0.2, d + 0.1), V(0, 3.3, 0), WOOD)
	local upperD = d * 0.6
	local upperZ = (d - upperD) / 2
	part(m, base, "Back", V(w, h - 4.5, 0.1), V(0, 3.4 + (h - 4.5) / 2, d / 2 - 0.05), Color3.fromRGB(70, 40, 40))
	for _, sx in { -1, 1 } do
		part(m, base, "Side", V(0.15, h - 4.5, upperD), V(sx * (w / 2 - 0.08), 3.4 + (h - 4.5) / 2, upperZ), WOOD_DARK)
		-- lower doors
		part(m, base, "LowerDoor", V(w / 2 - 0.25, 2.5, 0.08), V(sx * w / 4, 1.75, -d / 2 - 0.02), WOOD)
		part(m, base, "LowerInset", V(w / 2 - 0.85, 1.85, 0.04), V(sx * w / 4, 1.75, -d / 2 - 0.08), WOOD_DARK)
		cyl(m, base, "Knob", 0.1, 0.1, V(sx * 0.22, 2, -d / 2 - 0.1), GILT, M_METAL)
		-- glazed doors
		local gz = upperZ - upperD / 2 - 0.02
		local gx = sx * w / 4
		for _, y in { 3.45, 3.4 + (h - 4.5) } do
			part(m, base, "GlazeRail", V(w / 2 - 0.1, 0.18, 0.1), V(gx, y, gz), WOOD_DARK)
		end
		for _, x in { gx - (w / 4 - 0.1), gx, gx + (w / 4 - 0.1) } do
			part(m, base, "Muntin", V(if x == gx then 0.06 else 0.16, h - 4.5, 0.1), V(x, 3.4 + (h - 4.5) / 2, gz), WOOD_DARK)
		end
		for i = 1, 2 do
			part(m, base, "Muntin", V(w / 2 - 0.2, 0.06, 0.1), V(gx, 3.4 + i * (h - 4.5) / 3, gz), WOOD_DARK)
		end
		local pane = part(m, base, "Pane", V(w / 2 - 0.2, h - 4.6, 0.03), V(gx, 3.4 + (h - 4.5) / 2, gz), Color3.fromRGB(90, 110, 110), Enum.Material.Glass)
		pane.Transparency = 0.7
	end
	-- shelves of china
	for s = 0, 2 do
		local y = 3.45 + s * (h - 4.5) / 3
		part(m, base, "Shelf", V(w - 0.3, 0.08, upperD - 0.2), V(0, y, upperZ), WOOD_DARK)
		for i = -2, 2 do
			if (i + s) % 3 ~= 0 then
				dial(m, base, "Plate", 0.82, V(i * w / 5.4, y + 0.5, upperZ + 0.25), DIRTY_WHITE, Enum.Material.SmoothPlastic)
			else
				cyl(m, base, "Cup", 0.42, 0.34, V(i * w / 5.4, y + 0.26, upperZ), DIRTY_WHITE, Enum.Material.SmoothPlastic)
			end
		end
	end
	part(m, base, "Cornice", V(w + 0.3, 0.24, upperD + 0.4), V(0, h - 0.95, upperZ), WOOD)
	part(m, base, "Cornice2", V(w + 0.5, 0.2, upperD + 0.55), V(0, h - 0.75, upperZ), WOOD_DARK)
	part(m, base, "Crest", V(w * 0.5, 0.42, 0.25), V(0, h - 0.44, upperZ), WOOD_DARK)
	part(m, base, "Crest2", V(w * 0.22, 0.28, 0.25), V(0, h - 0.1, upperZ), WOOD_DARK)
	return body
end

-- A tall library bookcase: bays between fluted pilasters, a frieze and a stepped cornice. With opts.empty, a
-- plain store-room rack with a few jars and crates.
builders.shelf = function(m, base, size, e, opts)
	local w, h, d = size.X, size.Y, size.Z
	local rng = Random.new((opts and opts.seed) or math.floor(base.Position.X * 13 + base.Position.Z * 7))
	if opts and opts.empty then
		local rough = Color3.fromRGB(74, 56, 40)
		local first = part(m, base, "Rack", V(w, 0.16, d), V(0, 0.5, 0), rough, Enum.Material.WoodPlanks)
		for _, x in { -w / 2 + 0.15, 0, w / 2 - 0.15 } do
			for _, sz in { -1, 1 } do
				part(m, base, "Upright", V(0.3, h, 0.3), V(x, h / 2, sz * (d / 2 - 0.15)), rough)
			end
		end
		for level = 0, 3 do
			local y = 0.5 + level * (h - 1) / 3.2
			part(m, base, "Rack", V(w, 0.16, d), V(0, y, 0), rough, Enum.Material.WoodPlanks)
			local x = -w / 2 + 1
			while x < w / 2 - 1 do
				local r = rng:NextNumber()
				if r < 0.35 then
					cyl(m, base, "Jar", 0.9, 0.6, V(x, y + 0.53, rng:NextNumber(-0.3, 0.3)), Color3.fromRGB(70, 90, 74), Enum.Material.Glass)
				elseif r < 0.6 then
					part(m, base, "Crate", V(1.2, 0.9, 1.1), V(x, y + 0.53, 0), Color3.fromRGB(116, 92, 62), Enum.Material.WoodPlanks)
				end
				x += rng:NextNumber(1.1, 2.2)
			end
		end
		return first
	end
	local colors = { Color3.fromRGB(84, 24, 24), Color3.fromRGB(32, 50, 34), Color3.fromRGB(70, 48, 28), Color3.fromRGB(28, 34, 58), Color3.fromRGB(24, 20, 18), Color3.fromRGB(110, 90, 58), Color3.fromRGB(62, 22, 50) }
	local plinthH, topH = 1 , 1.7
	local bodyH = h - plinthH - topH
	local back = part(m, base, "Back", V(w, bodyH, 0.14), V(0, plinthH + bodyH / 2, d / 2 - 0.07), LACQUER)
	part(m, base, "Plinth", V(w + 0.2, 0.3, d + 0.12), V(0, 0.15, 0), LACQUER)
	part(m, base, "Base", V(w, plinthH - 0.3, d), V(0, 0.3 + (plinthH - 0.3) / 2, 0), WOOD_DARK)
	part(m, base, "Frieze", V(w, 0.8, d), V(0, h - topH + 0.4, 0), WOOD_DARK)
	part(m, base, "FriezeInset", V(w - 1, 0.42, 0.05), V(0, h - topH + 0.4, -d / 2 - 0.02), WOOD)
	part(m, base, "Cornice", V(w + 0.3, 0.26, d + 0.25), V(0, h - topH + 0.93, 0), WOOD)
	part(m, base, "Cornice2", V(w + 0.6, 0.3, d + 0.45), V(0, h - topH + 1.21, 0), WOOD_DARK)
	part(m, base, "CrestLow", V(w * 0.4, 0.28, 0.4), V(0, h - 0.2, d * 0.1), WOOD_DARK)
	local bays = math.max(2, math.floor(w / 3.2))
	local post = 0.42
	local bayW = (w - post) / bays
	for i = 0, bays do
		local x = -w / 2 + post / 2 + i * bayW
		part(m, base, "Pilaster", V(post, bodyH, d), V(x, plinthH + bodyH / 2, 0), WOOD_DARK)
		part(m, base, "Flute", V(post * 0.34, bodyH - 0.5, 0.04), V(x, plinthH + bodyH / 2, -d / 2 - 0.02), LACQUER)
		part(m, base, "PilasterCap", V(post + 0.12, 0.18, 0.1), V(x, plinthH + bodyH - 0.1, -d / 2 - 0.03), GILT_DARK, M_METAL)
	end
	local levels = math.max(3, math.floor(bodyH / 1.55))
	local levelH = bodyH / levels
	for level = 0, levels - 1 do
		local y = plinthH + level * levelH
		if level > 0 then
			part(m, base, "ShelfBoard", V(w - post, 0.12, d - 0.1), V(0, y, 0), WOOD)
		end
		for bay = 0, bays - 1 do
			local left = -w / 2 + post + bay * bayW + 0.04
			local right = left + bayW - post - 0.08
			local x = left
			if rng:NextNumber() < 0.1 then
				-- an ornament instead of books
				local mid = (left + right) / 2
				if rng:NextNumber() < 0.5 then
					ball(m, base, "Globe", 0.85, V(mid, y + 0.72, 0), Color3.fromRGB(100, 84, 54), Enum.Material.SmoothPlastic)
					cyl(m, base, "GlobeStand", 0.3, 0.5, V(mid, y + 0.2, 0), GILT_DARK, M_METAL)
				else
					cyl(m, base, "Vase", 0.8, 0.5, V(mid, y + 0.46, 0), GILT_DARK, M_METAL)
				end
			else
				while x < right - 0.3 do
					if rng:NextNumber() < 0.09 then
						x += rng:NextNumber(0.3, 0.75)
					else
						local bw = rng:NextNumber(0.24, 0.46)
						local bh = levelH * rng:NextNumber(0.64, 0.88)
						local lean = if rng:NextNumber() < 0.06 then math.rad(rng:NextNumber(8, 18)) else 0
						local book = box(m, "Book", V(bw, bh, d - 0.7), base * CFrame.new(x + bw / 2, y + 0.06 + bh / 2, 0.1) * CFrame.Angles(0, 0, lean), colors[rng:NextInteger(1, #colors)], M_FABRIC, false)
						book.CastShadow = false
						x += bw + 0.015
					end
				end
			end
		end
	end
	return back
end

-- A longcase clock: stepped plinth, glazed waist door with pendulum and weights, hood with columns, and a
-- brass dial with Roman chapter marks under a painted moon arch.
builders.clock = function(m, base, size)
	local w, h, d = size.X, size.Y, size.Z
	local front = -d / 2
	local body = part(m, base, "Plinth", V(w, 1.4, d), V(0, 0.9, 0), WOOD_DARK)
	part(m, base, "Foot", V(w + 0.25, 0.2, d + 0.2), V(0, 0.1, 0), LACQUER)
	part(m, base, "PlinthPanel", V(w - 0.7, 0.9, 0.05), V(0, 0.9, front - 0.02), WOOD)
	part(m, base, "PlinthCap", V(w + 0.1, 0.16, d + 0.1), V(0, 1.68, 0), LACQUER)
	local waistH = h - 5.2
	local waistY = 1.76 + waistH / 2
	part(m, base, "Waist", V(w - 0.5, waistH, d - 0.3), V(0, waistY, 0), WOOD)
	for _, sx in { -1, 1 } do
		part(m, base, "WaistQuoin", V(0.16, waistH, d - 0.15), V(sx * (w / 2 - 0.3), waistY, 0), LACQUER)
	end
	local doorZ = front + 0.12
	part(m, base, "CaseInside", V(w - 1, waistH - 0.8, 0.05), V(0, waistY, doorZ + 0.05), Color3.fromRGB(14, 11, 10))
	part(m, base, "DoorTop", V(w - 0.75, 0.2, 0.08), V(0, waistY + waistH / 2 - 0.3, doorZ - 0.03), LACQUER)
	part(m, base, "DoorBottom", V(w - 0.75, 0.2, 0.08), V(0, waistY - waistH / 2 + 0.3, doorZ - 0.03), LACQUER)
	for _, sx in { -1, 1 } do
		part(m, base, "DoorStile", V(0.14, waistH - 0.6, 0.08), V(sx * (w / 2 - 0.5), waistY, doorZ - 0.03), LACQUER)
	end
	local glass = part(m, base, "DoorGlass", V(w - 1, waistH - 0.8, 0.03), V(0, waistY, doorZ - 0.06), Color3.fromRGB(70, 90, 96), Enum.Material.Glass)
	glass.Transparency = 0.72
	local rodTop = waistY + waistH / 2 - 0.5
	part(m, base, "Pendulum", V(0.07, waistH - 2.2, 0.03), V(0, rodTop - (waistH - 2.2) / 2, doorZ + 0.01), GILT, M_METAL)
	dial(m, base, "Bob", 0.7, V(0, rodTop - (waistH - 2.2), doorZ), GILT)
	for _, sx in { -1, 1 } do
		part(m, base, "WeightChain", V(0.04, 1.3, 0.04), V(sx * 0.42, rodTop - 0.65, doorZ + 0.03), GILT_DARK, M_METAL)
		cyl(m, base, "Weight", 0.9, 0.28, V(sx * 0.42, rodTop - 1.7, doorZ + 0.03), GILT_DARK, M_METAL)
	end
	-- the hood
	local hoodY = h - 2.05
	part(m, base, "HoodBase", V(w + 0.2, 0.2, d + 0.1), V(0, h - 3.35, 0), LACQUER)
	part(m, base, "Hood", V(w - 0.1, 2.3, d - 0.1), V(0, hoodY, 0.03), WOOD_DARK)
	for _, sx in { -1, 1 } do
		cyl(m, base, "HoodColumn", 2.2, 0.22, V(sx * (w / 2 - 0.14), hoodY, front - 0.04), LACQUER)
		cyl(m, base, "ColumnCap", 0.1, 0.3, V(sx * (w / 2 - 0.14), hoodY + 1.08, front - 0.04), GILT, M_METAL)
		cyl(m, base, "ColumnCap", 0.1, 0.3, V(sx * (w / 2 - 0.14), hoodY - 1.08, front - 0.04), GILT, M_METAL)
	end
	local dialY = hoodY - 0.14
	local dialZ = front - 0.04
	part(m, base, "DialPlate", V(w - 0.56, w - 0.56, 0.06), V(0, dialY, dialZ), GILT_DARK, M_METAL)
	dial(m, base, "ChapterRing", w - 0.72, V(0, dialY, dialZ - 0.04), Color3.fromRGB(210, 202, 180), Enum.Material.SmoothPlastic)
	dial(m, base, "DialCentre", (w - 0.72) * 0.54, V(0, dialY, dialZ - 0.08), GILT, M_METAL)
	local radius = (w - 0.72) * 0.39
	for i = 1, 12 do
		local a = i / 12 * math.pi * 2
		local major = i % 3 == 0
		box(m, "Chapter", V(if major then 0.1 else 0.05, 0.24, 0.02), base * CFrame.new(math.sin(a) * radius, dialY + math.cos(a) * radius, dialZ - 0.1) * CFrame.Angles(0, 0, -a), Color3.fromRGB(14, 12, 12), Enum.Material.SmoothPlastic, false)
	end
	local function hand(name, len, thick, deg)
		local a = math.rad(deg)
		box(m, name, V(thick, len, 0.02), base * CFrame.new(math.sin(a) * len / 2, dialY + math.cos(a) * len / 2, dialZ - 0.13) * CFrame.Angles(0, 0, -a), Color3.fromRGB(10, 8, 8), Enum.Material.Metal, false)
	end
	hand("HandHour", radius * 0.62, 0.09, 112)
	hand("HandMinute", radius * 0.95, 0.055, 342)
	ball(m, base, "HandBoss", 0.13, V(0, dialY, dialZ - 0.13), GILT, M_METAL)
	-- moon arch above the dial, then the broken pediment and three finials
	dial(m, base, "MoonDisc", w - 1.1, V(0, h - 0.82, dialZ + 0.02), Color3.fromRGB(26, 34, 70), Enum.Material.SmoothPlastic)
	ball(m, base, "Moon", 0.34, V(0.14, h - 0.72, dialZ - 0.04), Color3.fromRGB(214, 206, 178), Enum.Material.SmoothPlastic)
	part(m, base, "HoodCap", V(w + 0.22, 0.14, d + 0.14), V(0, h - 0.87, 0.03), LACQUER)
	part(m, base, "Arch", V(w - 0.1, 0.5, d - 0.4), V(0, h - 0.55, 0.15), WOOD_DARK)
	part(m, base, "Crown", V(w + 0.28, 0.14, d + 0.05), V(0, h - 0.24, 0.1), WOOD)
	for _, x in { -w / 2 + 0.2, 0, w / 2 - 0.2 } do
		cyl(m, base, "FinialStem", 0.12, 0.14, V(x, h - 0.12, 0.1), GILT, M_METAL)
		ball(m, base, "Finial", 0.26, V(x, h + 0.05, 0.1), GILT, M_METAL)
	end
	return body
end

-- A heavy old frame of near-black carved wood: a raised bead round the outside, square carved corner blocks and a
-- thin slip of tarnished gilt next to the picture (docs/theme.md: nothing bright).
local function frameFor(m, base, w, h, depth)
	local back = part(m, base, "FrameBack", V(w, h, depth * 0.5), V(0, 0, depth * 0.25), LACQUER, M_WOOD)
	local band, bead = 0.34, 0.1
	local ebony = Color3.fromRGB(28, 19, 14)
	local slip = Color3.fromRGB(84, 64, 34)
	for _, bar in { { w, band, 0, h / 2 - band / 2 }, { w, band, 0, -h / 2 + band / 2 }, { band, h, -w / 2 + band / 2, 0 }, { band, h, w / 2 - band / 2, 0 } } do
		part(m, base, "Frame", V(bar[1], bar[2], depth * 0.75), V(bar[3], bar[4], -depth * 0.12), ebony, M_WOOD)
	end
	for _, bar in { { w + 0.1, bead, 0, h / 2 }, { w + 0.1, bead, 0, -h / 2 }, { bead, h + 0.1, -w / 2, 0 }, { bead, h + 0.1, w / 2, 0 } } do
		part(m, base, "FrameBead", V(bar[1], bar[2], depth * 0.9), V(bar[3], bar[4], -depth * 0.12), LACQUER, M_WOOD)
	end
	local inner, step = 0.1, band + 0.05
	for _, bar in { { w - band * 2, inner, 0, h / 2 - step }, { w - band * 2, inner, 0, -h / 2 + step }, { inner, h - band * 2, -w / 2 + step, 0 }, { inner, h - band * 2, w / 2 - step, 0 } } do
		part(m, base, "FrameLip", V(bar[1], bar[2], depth * 0.55), V(bar[3], bar[4], -depth * 0.1), slip, M_METAL)
	end
	for _, sx in { -1, 1 } do
		for _, sy in { -1, 1 } do
			part(m, base, "FrameCorner", V(band + 0.14, band + 0.14, depth * 0.95), V(sx * (w / 2 - band / 2), sy * (h / 2 - band / 2), -depth * 0.12), LACQUER, M_WOOD)
			part(m, base, "FrameBoss", V(0.16, 0.16, 0.06), V(sx * (w / 2 - band / 2), sy * (h / 2 - band / 2), -depth * 0.62), slip, M_METAL)
		end
	end
	return back
end

-- Real oil paintings. Square images, so a slightly tall or wide frame only stretches them a little; the "framed"
-- ones carry their own painted frame on a transparent ground and go on wide canvases.
local PICTURES_TALL = { 9651067222, 17626107124, 17626206195, 10331040354, 18280006281, 8821938291, 6966413603 }
local PICTURES_DARK = { 12218923137, 5813636417, 3551664826 }
local PICTURES_FRAMED = { 135679236928925, 115456434549831, 83700677839081, 126453805427116, 76205136965438 }
local pictureTurn = 0

builders.painting = function(m, base, size, e, opts)
	local w, h, depth = size.X, size.Y, size.Z
	local back = frameFor(m, base, w, h, depth)
	local canvasZ = -depth * 0.02
	part(m, base, "Canvas", V(w - 0.75, h - 0.75, 0.06), V(0, 0, canvasZ), Color3.fromRGB(26, 20, 16), Enum.Material.SmoothPlastic)
	pictureTurn += 1
	local list = if w / h > 1.15 then (if pictureTurn % 3 == 0 then PICTURES_DARK else PICTURES_FRAMED) else PICTURES_TALL
	local id = (opts and opts.image) or list[(pictureTurn % #list) + 1]
	local framed = table.find(PICTURES_FRAMED, id) ~= nil
	local side = w - 0.75
	local picture = part(m, base, "Picture", V(side, if framed then side else h - 0.75, 0.04), V(0, 0, canvasZ - 0.06), Color3.new(0, 0, 0), Enum.Material.SmoothPlastic)
	picture.Transparency = 1
	picture.CastShadow = false
	local decal = Instance.new("Decal")
	decal.Texture = "rbxassetid://" .. id
	decal.Face = Enum.NormalId.Front
	decal.Parent = picture
	return back
end

-- An old looking-glass in a gilt frame with a crest.
builders.mirror = function(m, base, size)
	local w, h, depth = size.X, size.Y, size.Z
	local back = frameFor(m, base, w, h, depth)
	local gw, gh = w - 0.75, h - 0.75
	local gz = -depth * 0.05
	-- a game mirror has no room to reflect, so it is painted: pale silver with diagonal sheens and a tarnished edge
	local glass = part(m, base, "Glass", V(gw, gh, 0.05), V(0, 0, gz), Color3.fromRGB(150, 170, 182), Enum.Material.Glass)
	glass.Reflectance = 0.25
	for i, sheen in { { -0.22, 0.34, 0.5 }, { 0.02, 0.16, 0.65 }, { 0.26, 0.08, 0.75 } } do
		local len = math.min(gw, gh) * (1.15 - i * 0.12)
		local bar = part(m, base, "Sheen", V(gw * sheen[2], len, 0.012), V(gw * sheen[1], gh * 0.06, gz - 0.032), Color3.fromRGB(226, 236, 240), Enum.Material.SmoothPlastic)
		bar.CFrame *= CFrame.Angles(0, 0, math.rad(32))
		bar.Transparency = sheen[3]
		bar.CastShadow = false
	end
	local rust = Color3.fromRGB(62, 54, 44)
	part(m, base, "Tarnish", V(gw * 0.34, gh * 0.12, 0.014), V(-gw * 0.33, -gh * 0.44, gz - 0.034), rust)
	part(m, base, "Tarnish", V(gw * 0.12, gh * 0.3, 0.014), V(gw * 0.44, gh * 0.35, gz - 0.034), rust)
	part(m, base, "CrestLow", V(w * 0.56, 0.3, depth * 0.5), V(0, h / 2 + 0.15, 0), GILT, M_METAL)
	part(m, base, "CrestHigh", V(w * 0.28, 0.28, depth * 0.45), V(0, h / 2 + 0.43, 0), GILT, M_METAL)
	ball(m, base, "CrestBall", 0.36, V(0, h / 2 + 0.72, 0), GILT, M_METAL)
	return back
end

-- A marble-mantled fireplace: a brick breast built round a real hollow firebox (logs on the hearth inside, a fire
-- burning over them), panelled overmantel.
builders.fireplace = function(m, base, size)
	local w, h, d = size.X, size.Y, size.Z
	local front = -d / 2
	local brick = Color3.fromRGB(92, 50, 42)
	local marble = Color3.fromRGB(150, 142, 132)
	local soot = Color3.fromRGB(14, 11, 10)
	local ow, oh = 4.6, 3.85 -- the opening (from the floor)
	local depth, bz = d - 0.2, 0.1
	local cheek = (w - 1 - ow) / 2
	local body = part(m, base, "Breast", V(w - 1, h - oh, depth), V(0, (h + oh) / 2, bz), brick, Enum.Material.Brick)
	for _, sx in { -1, 1 } do
		part(m, base, "BreastSide", V(cheek, oh, depth), V(sx * (ow / 2 + cheek / 2), oh / 2, bz), brick, Enum.Material.Brick)
		part(m, base, "FireCheek", V(0.08, oh, depth - 0.5), V(sx * (ow / 2 - 0.05), oh / 2, bz + 0.1), soot, Enum.Material.Slate)
	end
	part(m, base, "FireBack", V(ow, oh, 0.3), V(0, oh / 2, bz + depth / 2 - 0.15), soot, Enum.Material.Slate)
	part(m, base, "FireRoof", V(ow, 0.08, depth - 0.5), V(0, oh - 0.05, bz + 0.1), soot, Enum.Material.Slate)
	part(m, base, "Hearth", V(w + 1.2, 0.25, d + 1.6), V(0, 0.12, -0.8), Color3.fromRGB(46, 42, 42), Enum.Material.Slate)
	local inside = front + 1.5 -- (the middle of the firebox)
	for _, sx in { -1, 1 } do
		part(m, base, "Jamb", V(1.3, 4.4, 0.7), V(sx * 3.1, 2.4, front - 0.05), marble, Enum.Material.Marble)
		part(m, base, "JambFlute", V(0.4, 3.6, 0.05), V(sx * 3.1, 2.4, front - 0.42), marble:Lerp(Color3.new(0, 0, 0), 0.3), Enum.Material.Marble)
		cyl(m, base, "Firedog", 1, 0.2, V(sx * 1.6, 0.75, front + 0.55), GILT_DARK, M_METAL)
		ball(m, base, "FiredogKnob", 0.3, V(sx * 1.6, 1.35, front + 0.55), GILT, M_METAL)
		box(m, "Grate", V(0.12, 0.12, 1.9), base * CFrame.new(sx * 1.2, 0.5, inside), soot, M_METAL, false)
	end
	part(m, base, "Lintel", V(7.5, 0.9, 0.7), V(0, 4.3, front - 0.05), marble, Enum.Material.Marble)
	part(m, base, "Keystone", V(1.2, 0.9, 0.82), V(0, 4.3, front - 0.1), marble:Lerp(Color3.new(1, 1, 1), 0.2), Enum.Material.Marble)
	part(m, base, "MantelShelf", V(w + 0.2, 0.3, d * 0.7 + 0.9), V(0, 4.9, front + 0.35), marble, Enum.Material.Marble)
	part(m, base, "MantelMould", V(w - 0.3, 0.16, d * 0.7 + 0.55), V(0, 4.68, front + 0.35), marble:Lerp(Color3.new(0, 0, 0), 0.25), Enum.Material.Marble)
	-- firewood: two logs on the grate, one across them, charred
	for i, log in { { -0.5, 0.78, 8 }, { 0.55, 0.78, -10 }, { 0, 1.2, 96 } } do
		local l = box(m, "Log", V(3 - i * 0.3, 0.46, 0.46), base * CFrame.new(log[1] * 0.4, log[2], inside + log[1] * 0.5) * CFrame.Angles(0, math.rad(log[3]), 0), Color3.fromRGB(44, 30, 22), M_WOOD, false)
		l.Shape = Enum.PartType.Cylinder
	end
	local embers = part(m, base, "Embers", V(2.6, 0.2, 1.3), V(0, 0.4, inside), Color3.fromRGB(255, 84, 24), Enum.Material.Neon, false)
	embers.CastShadow = false
	light(embers, Color3.fromRGB(255, 120, 60), 15, 0.6, true)
	local fire = Instance.new("ParticleEmitter")
	fire.Texture = "rbxasset://textures/particles/fire_main.dds"
	fire.Color = ColorSequence.new(Color3.fromRGB(255, 190, 110), Color3.fromRGB(255, 70, 20))
	fire.LightEmission = 0.9
	fire.LightInfluence = 0
	fire.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.3), NumberSequenceKeypoint.new(1, 0.25) })
	fire.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 1) })
	fire.Lifetime = NumberRange.new(0.45, 0.8)
	fire.Rate = 26
	fire.Speed = NumberRange.new(1.5, 2.6)
	fire.SpreadAngle = Vector2.new(10, 10)
	fire.Rotation = NumberRange.new(-30, 30)
	fire.EmissionDirection = Enum.NormalId.Top
	fire.Parent = embers
	-- the overmantel, panelled in dark wood to the cornice
	local panelY, panelH = (5.05 + h - 0.6) / 2, h - 0.6 - 5.05
	part(m, base, "Overmantel", V(w - 1.4, panelH, 0.2), V(0, panelY, front - 0.02), WOOD_DARK)
	part(m, base, "OvermantelTop", V(w - 0.8, 0.5, 0.5), V(0, h - 0.5, front), LACQUER)
	for _, sx in { -1, 1 } do
		part(m, base, "OverPilaster", V(0.5, panelH, 0.34), V(sx * (w / 2 - 1.05), panelY, front - 0.06), WOOD)
	end
	return body
end

-- A tiered stone fountain: round basin, dark still water, a stem, an upper bowl and a finial.
builders.fountain = function(m, base, size)
	local stone = Color3.fromRGB(120, 116, 108)
	local dark = stone:Lerp(Color3.new(0, 0, 0), 0.3)
	local basin = cyl(m, base, "Basin", 1.6, size.X, V(0, 0.8, 0), stone, Enum.Material.Limestone)
	cyl(m, base, "BasinLip", 0.28, size.X + 0.5, V(0, 1.62, 0), dark, Enum.Material.Limestone)
	cyl(m, base, "BasinFoot", 0.3, size.X + 0.7, V(0, 0.15, 0), dark, Enum.Material.Limestone)
	local water = cyl(m, base, "Water", 0.08, size.X - 0.9, V(0, 1.68, 0), Color3.fromRGB(20, 30, 28), Enum.Material.Glass)
	water.Transparency = 0.15
	cyl(m, base, "Stem", size.Y - 2.4, 0.95, V(0, 1.7 + (size.Y - 2.4) / 2, 0), stone, Enum.Material.Limestone)
	cyl(m, base, "StemCollar", 0.3, 1.5, V(0, 2.2, 0), dark, Enum.Material.Limestone)
	cyl(m, base, "Bowl", 0.34, 3.6, V(0, size.Y - 0.55, 0), stone, Enum.Material.Limestone)
	cyl(m, base, "BowlLip", 0.14, 3.9, V(0, size.Y - 0.32, 0), dark, Enum.Material.Limestone)
	cyl(m, base, "BowlFoot", 0.3, 2.2, V(0, size.Y - 0.86, 0), dark, Enum.Material.Limestone)
	cyl(m, base, "Spout", 0.7, 0.45, V(0, size.Y, 0), stone, Enum.Material.Limestone)
	ball(m, base, "Finial", 0.7, V(0, size.Y + 0.6, 0), stone, Enum.Material.Limestone)
	return basin
end

-- A suit of armour on its stand, after a late gothic harness: armet with a visor slit and plume, rounded breastplate
-- with a ridge, laminated fauld and tassets, layered pauldrons, elbow and knee fans, a sword at the hip and a halberd.
builders.suitOfArmor = function(m, base, size)
	local iron, dark, edge = Color3.fromRGB(78, 78, 84), Color3.fromRGB(40, 40, 46), Color3.fromRGB(104, 104, 110)
	local IRON = Enum.Material.Metal
	local function blob(name, s, offset, color, rot)
		local p = box(m, name, s, base * CFrame.new(offset) * (rot or CFrame.new()), color, IRON, false)
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = p
		return p
	end
	local function fan(name, d, offset)
		local p = box(m, name, V(0.06, d, d), base * CFrame.new(offset), edge, IRON, false) -- a disc facing sideways
		p.Shape = Enum.PartType.Cylinder
	end
	local stand = cyl(m, base, "Stand", 0.4, 2.3, V(0, 0.2, 0), WOOD_DARK)
	cyl(m, base, "StandRim", 0.12, 2.45, V(0, 0.42, 0), GILT_DARK, IRON)
	for _, sx in { -1, 1 } do
		local x = sx * 0.36
		blob("Sabaton", V(0.55, 0.38, 1.05), V(x, 0.62, -0.22), dark)
		cyl(m, base, "Greave", 1.45, 0.5, V(x, 1.5, 0), iron, IRON)
		blob("Poleyn", V(0.6, 0.6, 0.55), V(x, 2.25, -0.08), edge)
		fan("PoleynFan", 0.7, V(x + sx * 0.3, 2.25, 0))
		cyl(m, base, "Cuisse", 1.25, 0.62, V(x, 2.95, 0), iron, IRON)
		blob("Tasset", V(0.72, 0.5, 0.45), V(sx * 0.42, 3.5, -0.24), iron, CFrame.Angles(math.rad(-12), 0, 0))
		blob("Tasset", V(0.68, 0.45, 0.42), V(sx * 0.42, 3.2, -0.28), dark, CFrame.Angles(math.rad(-12), 0, 0))
		-- shoulders and arms
		blob("Pauldron", V(1.05, 0.8, 1.05), V(sx * 0.98, 5.62, 0), iron)
		blob("PauldronLame", V(0.95, 0.42, 1), V(sx * 1.03, 5.2, 0), dark)
		blob("Besagew", V(0.12, 0.5, 0.5), V(sx * 0.72, 5.15, -0.5), edge)
		cyl(m, base, "Rerebrace", 0.85, 0.44, V(sx * 1.05, 4.75, 0), iron, IRON)
		blob("Couter", V(0.55, 0.5, 0.55), V(sx * 1.07, 4.25, 0.08), edge)
		fan("CouterFan", 0.65, V(sx * 1.36, 4.25, 0.05))
		cyl(m, base, "Vambrace", 0.85, 0.4, V(sx * 1.05, 3.72, -0.05), iron, IRON)
		blob("Gauntlet", V(0.45, 0.6, 0.52), V(sx * 1.05, 3.05, -0.12), dark)
	end
	for k, d in { 1.55, 1.5, 1.45 } do -- the fauld: overlapping hoops below the breastplate
		cyl(m, base, "Fauld", 0.24, d, V(0, 3.62 + k * 0.22, 0), if k % 2 == 0 then dark else iron, IRON)
	end
	cyl(m, base, "Belt", 0.16, 1.62, V(0, 3.72, 0), Color3.fromRGB(56, 34, 22), Enum.Material.Leather)
	blob("Breastplate", V(1.65, 1.95, 1.2), V(0, 4.95, 0), iron)
	part(m, base, "Ridge", V(0.08, 1.4, 0.06), V(0, 5, -0.6), edge, IRON)
	cyl(m, base, "Gorget", 0.36, 0.98, V(0, 5.95, 0), dark, IRON)
	-- the armet
	blob("Helm", V(0.98, 1.12, 1.08), V(0, 6.6, 0), iron)
	blob("Visor", V(0.86, 0.58, 0.62), V(0, 6.5, -0.32), dark)
	part(m, base, "EyeSlit", V(0.62, 0.06, 0.05), V(0, 6.62, -0.63), Color3.new(0, 0, 0), Enum.Material.SmoothPlastic)
	part(m, base, "Comb", V(0.08, 0.28, 0.95), V(0, 7.2, 0.02), edge, IRON)
	for k = 0, 2 do
		blob("Plume", V(0.4 - k * 0.05, 0.42, 0.85), V(0, 7.38 + k * 0.08, 0.28 + k * 0.32), Color3.fromRGB(96, 16, 20), CFrame.Angles(math.rad(-20 - k * 15), 0, 0)).Material = Enum.Material.Fabric
	end
	-- a sword sheathed at the left hip, a halberd grounded in the right hand
	box(m, "Scabbard", V(0.14, 2.3, 0.26), base * CFrame.new(-0.88, 2.55, 0.15) * CFrame.Angles(math.rad(12), 0, math.rad(-6)), Color3.fromRGB(30, 22, 18), Enum.Material.Leather, false)
	part(m, base, "Crossguard", V(0.1, 0.1, 0.7), V(-0.88, 3.75, 0.05), edge, IRON)
	blob("Pommel", V(0.2, 0.2, 0.2), V(-0.88, 4.2, 0.02), edge)
	cyl(m, base, "HalberdShaft", 7.6, 0.14, V(1.05, 3.9, -0.45), WOOD_DARK)
	part(m, base, "HalberdAxe", V(0.05, 1.05, 0.95), V(1.05, 7.05, -0.95), edge, IRON)
	part(m, base, "HalberdBack", V(0.05, 0.25, 0.55), V(1.05, 7.15, -0.05), edge, IRON)
	part(m, base, "HalberdSpike", V(0.07, 1, 0.07), V(1.05, 8.1, -0.45), edge, IRON)
	return stand
end

-- A tall standing candelabrum in old brass: a heavy foot, a turned stem and seven candles.
builders.standingCandelabra = function(m, base, size)
	local brass = Color3.fromRGB(34, 32, 32) -- black wrought iron (docs/theme.md)
	local h = size.Y
	-- three legs sweeping out from the stem down to small feet
	local foot = cyl(m, base, "Hub", 0.3, 0.5, V(0, 1.15, 0), brass, M_METAL)
	for i = 0, 2 do
		local turn = CFrame.Angles(0, i * math.pi * 2 / 3, 0)
		box(m, "Leg", V(0.13, 0.13, 0.75), base * turn * CFrame.new(0, 0.95, 0.38) * CFrame.Angles(math.rad(35), 0, 0), brass, M_METAL, false)
		box(m, "Leg", V(0.13, 0.13, 0.7), base * turn * CFrame.new(0, 0.5, 0.82) * CFrame.Angles(math.rad(62), 0, 0), brass, M_METAL, false)
		box(m, "Leg", V(0.13, 0.13, 0.42), base * turn * CFrame.new(0, 0.14, 1.1) * CFrame.Angles(math.rad(15), 0, 0), brass, M_METAL, false)
		ball(m, base, "Toe", 0.26, (turn * CFrame.new(0, 0.13, 1.32)).Position, brass, M_METAL)
	end
	cyl(m, base, "Stem", h - 1.85, 0.16, V(0, 1.1 + (h - 1.85) / 2, 0), brass, M_METAL) -- (up to the middle cup)
	for _, y in { 1.5, h * 0.5, h - 1.5 } do
		ball(m, base, "Knop", 0.34, V(0, y, 0), brass, M_METAL)
		cyl(m, base, "Collar", 0.08, 0.3, V(0, y - 0.22, 0), brass, M_METAL)
		cyl(m, base, "Collar", 0.08, 0.3, V(0, y + 0.22, 0), brass, M_METAL)
	end
	-- arms: each dips out from the stem and curls up to its cup
	for _, arm in { { 0, 1.25, h - 1.2 }, { 180, 1.25, h - 1.2 }, { 0, 0.62, h - 0.95 }, { 180, 0.62, h - 0.95 }, { 90, 0.75, h - 1 }, { 270, 0.75, h - 1 } } do
		local turn = base * CFrame.Angles(0, math.rad(arm[1]), 0)
		local r, top = arm[2], arm[3]
		box(m, "Arm", V(r * 0.62, 0.1, 0.1), turn * CFrame.new(r * 0.3, h - 1.62, 0) * CFrame.Angles(0, 0, math.rad(-14)), brass, M_METAL, false)
		local rise, run = (top - 0.1) - (h - 1.69), r * 0.42
		box(m, "Arm", V(math.sqrt(rise * rise + run * run) + 0.06, 0.1, 0.1), turn * CFrame.new(r * 0.79, h - 1.69 + rise / 2, 0) * CFrame.Angles(0, 0, math.atan2(rise, run)), brass, M_METAL, false)
		box(m, "Arm", V(0.1, 0.22, 0.1), turn * CFrame.new(r, top - 0.12, 0), brass, M_METAL, false)
	end
	local spots = { { -1.25, 0, h - 1.2 }, { 1.25, 0, h - 1.2 }, { -0.62, 0, h - 0.95 }, { 0.62, 0, h - 0.95 }, { 0, -0.75, h - 1 }, { 0, 0.75, h - 1 }, { 0, 0, h - 0.7 } }
	for i, sp in spots do
		cyl(m, base, "Cup", 0.1, 0.4, V(sp[1], sp[3], sp[2]), brass, M_METAL)
		cyl(m, base, "CupFoot", 0.1, 0.2, V(sp[1], sp[3] - 0.08, sp[2]), brass, M_METAL)
		local len = 0.7 + (i % 3) * 0.2
		cyl(m, base, "Candle", len, 0.2, V(sp[1], sp[3] + 0.06 + len / 2, sp[2]), DIRTY_WHITE, Enum.Material.SmoothPlastic)
		flame(m, base, V(sp[1], sp[3] + 0.2 + len, sp[2]), i == #spots)
	end
	return foot
end

---------------------------------------------------------------- catalog
-- size = X (width), Y (height), Z (depth); front faces -Z. `asset` = AssetLibrary model for style "assets".

local function item(size, color, material, build, asset, extra)
	local e = { size = size, color = color, material = material, build = build, asset = asset }
	for k, v in extra or {} do
		e[k] = v
	end
	return e
end

local CATALOG = {
	bed = item(V(5.5, 5.6, 8.1), WOOD_DARK, Enum.Material.Wood, builders.bed, "Asset_Bed"),
	fourPoster = item(V(8.4, 12.5, 11.4), WOOD_DARK, Enum.Material.Wood, builders.fourPoster),
	ironBed = item(V(3.8, 4.6, 8), METAL, Enum.Material.Metal, builders.ironBed),
	childBed = item(V(3.4, 3.8, 4.7), WOOD_LIGHT, Enum.Material.Wood, builders.childBed, "Asset_ChildBed"),
	shelf = item(V(11, 11.5, 2.6), WOOD_DARK, Enum.Material.Wood, builders.shelf),
	cabinet = item(V(4.6, 9, 2.4), WOOD, Enum.Material.Wood, builders.cabinet),
	drawer = item(V(6.6, 4, 3), WOOD, Enum.Material.Wood, builders.drawer),
	chair = item(V(2.7, 5.6, 2.8), WOOD, Enum.Material.Wood, builders.chair),
	armchair = item(V(3.2, 4.4, 3.2), HouseKit.CLOTH_RED, Enum.Material.Fabric, builders.armchair, "Asset_Armchair"),
	smallTable = item(V(3, 2.6, 2), WOOD, Enum.Material.Wood, builders.smallTable),
	counter = item(V(14, 3.5, 2.4), DIRTY_WHITE, Enum.Material.SmoothPlastic, builders.counter),
	sink = item(V(2.2, 0.2, 1.6), METAL, Enum.Material.Metal, builders.sink),
	stove = item(V(2.6, 3.2, 2.4), METAL, Enum.Material.Metal, builders.stove),
	fridge = item(V(3, 7, 2.6), Color3.fromRGB(200, 205, 200), Enum.Material.SmoothPlastic, builders.fridge),
	vanity = item(V(4, 3.2, 2), WOOD_DARK, Enum.Material.Wood, builders.vanity),
	dressingTable = item(V(6.5, 9.1, 2.34), WOOD_DARK, Enum.Material.Wood, builders.dressingTable),
	toilet = item(V(1.8, 1.8, 2.4), DIRTY_WHITE, Enum.Material.SmoothPlastic, builders.toilet),
	bathtub = item(V(7, 2.6, 3.8), DIRTY_WHITE, Enum.Material.SmoothPlastic, builders.bathtub, "Bathtub"),
	barrel = item(V(2.4, 3, 2.4), WOOD, Enum.Material.Wood, builders.barrel),
	pedestal = item(V(1.4, 3, 1.4), DIRTY_WHITE, Enum.Material.Marble, builders.pedestal),
	clock = item(V(2.7, 10, 1.8), WOOD_DARK, Enum.Material.Wood, builders.clock),
	fireplace = item(V(9.4, 15, 3.4), Color3.fromRGB(110, 100, 96), Enum.Material.Brick, builders.fireplace),
	crib = item(V(4.1, 3.4, 2.7), WOOD_LIGHT, Enum.Material.Wood, builders.crib, "Asset_Crib"),
	rockingHorse = item(V(1, 3.4, 4), Color3.fromRGB(180, 150, 120), Enum.Material.Wood, builders.rockingHorse),
	toyBlocks = item(V(3.6, 0.8, 1.6), BRASS, Enum.Material.SmoothPlastic, builders.toyBlocks),
	boxPile = item(V(3, 3.4, 4), Color3.fromRGB(150, 120, 80), Enum.Material.Cardboard, builders.boxPile),
	candle = item(V(0.3, 1.2, 0.3), DIRTY_WHITE, Enum.Material.SmoothPlastic, builders.candle),
	candelabra = item(V(0.9, 3.2, 0.9), BRASS, Enum.Material.Metal, builders.candelabra, "Candelabra"),
	painting = item(V(3, 4, 0.6), BRASS, Enum.Material.Metal, builders.painting, nil, { wallHung = true }),
	mirror = item(V(3, 4.8, 0.6), BRASS, Enum.Material.Metal, builders.mirror, nil, { wallHung = true }),
	candlesticks = item(V(1.4, 2.1, 0.5), BRASS, Enum.Material.Metal, builders.candle, "Decor_Candlesticks"),
	rug = item(V(8, 0.07, 6), HouseKit.CLOTH_RED, Enum.Material.Fabric, builders.rug),
	sofa = item(V(8, 4, 3), HouseKit.CLOTH_RED, Enum.Material.Fabric, builders.armchair),
	piano = item(V(12.4, 7.9, 12.7), Color3.fromRGB(22, 20, 22), Enum.Material.Wood, block(true), "Asset_Piano"),
	wineRack = item(V(9, 7, 2), WOOD_DARK, Enum.Material.Wood, builders.wineRack),
	boiler = item(V(6, 9, 6), Color3.fromRGB(70, 64, 60), Enum.Material.CorrodedMetal, builders.boiler),
	coffin = item(V(4.5, 2, 12), WOOD_DARK, Enum.Material.Wood, block(true), "Asset_Coffin"),
	slab = item(V(4, 3.2, 8), Color3.fromRGB(150, 154, 152), Enum.Material.Metal, builders.slab),
	fountain = item(V(9, 5, 9), Color3.fromRGB(120, 116, 108), Enum.Material.Limestone, builders.fountain),
	planter = item(V(2.4, 4, 2.4), Color3.fromRGB(112, 64, 46), Enum.Material.Slate, builders.planter),
	clothesline = item(V(20, 8, 1), Color3.fromRGB(150, 150, 146), Enum.Material.Fabric, builders.clothesline),
	longTable = item(V(4.5, 3.3, 6.7), WOOD_DARK, Enum.Material.Wood, builders.longTable),
	-- Library art only (nothing is drawn in "blocks" style):
	cobweb = item(V(15.2, 2.8, 15.7), DIRTY_WHITE, Enum.Material.Fabric, nil, "Cobwebs", { assetOnly = true }),
	antlers = item(V(2.8, 3.9, 1.8), BRASS, Enum.Material.Metal, nil, "Decor_Antlers", { assetOnly = true, wallHung = true }),
	suitOfArmor = item(V(3.1, 7.2, 2.5), METAL, Enum.Material.Metal, builders.suitOfArmor, "Asset_ArmorBust"), -- (the generated fluted armour on its stand; parts if missing)
	standingCandelabra = item(V(2.6, 7, 1.6), BRASS, Enum.Material.Metal, builders.standingCandelabra),
	statuette = item(V(1.7, 3.4, 1.7), DIRTY_WHITE, Enum.Material.Marble, builders.statuette),
	-- generated library pieces (AssetLibrary): no block version
	gardenBench = item(V(6, 3.6, 2.4), METAL, Enum.Material.Metal, nil, "Asset_GardenBench", { assetOnly = true }),
	displayCase = item(V(4, 7, 2.2), WOOD_DARK, Enum.Material.Wood, nil, "Asset_DisplayCase", { assetOnly = true }),
	foldingScreen = item(V(6, 6.5, 1.4), WOOD_DARK, Enum.Material.Wood, nil, "Asset_FoldingScreen", { assetOnly = true }),
	wineCask = item(V(5, 5.6, 6), WOOD, Enum.Material.Wood, nil, "Asset_WineCask", { assetOnly = true }),
	sarcophagus = item(V(4, 3.8, 9), DIRTY_WHITE, Enum.Material.Slate, nil, "Asset_Sarcophagus", { assetOnly = true }),
	workbench = item(V(7, 4.2, 3), WOOD, Enum.Material.Wood, nil, "Asset_Workbench", { assetOnly = true }),
	washtub = item(V(4.4, 4, 3), WOOD, Enum.Material.Wood, nil, "Asset_Washtub", { assetOnly = true }),
	meatRack = item(V(6, 7.5, 2.2), METAL, Enum.Material.Metal, nil, "Asset_MeatRack", { assetOnly = true }),
	mourner = item(V(2.6, 7, 2.6), DIRTY_WHITE, Enum.Material.Slate, nil, "Asset_Mourner", { assetOnly = true }),
}

function Furniture.size(kind: string): Vector3
	return CATALOG[kind].size
end

function Furniture.kinds(): { string }
	local list = {}
	for kind in CATALOG do
		table.insert(list, kind)
	end
	table.sort(list)
	return list
end

---------------------------------------------------------------- placing

-- Pictures come in many sizes and shapes: a stable choice per spot, so the walls do not look stamped out.
local ART_SHAPES = { { 1, 1 }, { 0.75, 0.72 }, { 1.45, 1.35 }, { 1.9, 0.95 }, { 1.05, 1.5 }, { 0.62, 0.62 }, { 2.2, 1.2 } }
local function artSize(roomId: number, side: string, along: number, w: number, h: number, kind: string?): (number, number)
	if kind then
		return w, h
	end
	local shape = ART_SHAPES[(roomId * 3 + side:byte() + math.floor(math.abs(along))) % #ART_SHAPES + 1]
	return math.min(w * shape[1], 9), math.min(h * shape[2], 7.4)
end

-- Library models are normalised: bottom-centre Root, front -Z, Size attribute. Measured exception:
-- none needed for the pieces above.
local function placeAsset(model, entry, base, scale)
	local template = HouseKit.libraryModel(entry.asset)
	if not template then
		return false
	end
	local c = template:Clone()
	if scale ~= 1 then
		c:ScaleTo(c:GetScale() * scale)
	end
	c:PivotTo(base)
	for _, child in c:GetChildren() do
		child.Parent = model
	end
	c:Destroy()
	return true
end

local allow = nil -- (Furniture.topUp: which pieces of the layout to build)

local function makePiece(folder, kind: string, room: number, base: CFrame, style: string, opts)
	if allow and not allow(kind, room) then
		return nil
	end
	local entry = CATALOG[kind]
	opts = opts or {}
	local scale = opts.scale or 1
	if entry.assetOnly and style ~= "assets" then
		return nil
	end
	local model = Instance.new("Model")
	model.Name = (opts.name or kind:sub(1, 1):upper() .. kind:sub(2))
	local usedAsset = false
	if style == "assets" and entry.asset then
		local template = HouseKit.libraryModel(entry.asset)
		local assetSize = template and template:GetAttribute("Size")
		if entry.wallHung and opts.size and assetSize then
			scale = opts.size.Y / assetSize.Y -- a picture asked for at this height
		end
		usedAsset = placeAsset(model, entry, base, scale)
	end
	if not usedAsset then
		if not entry.build then
			model:Destroy()
			return nil
		end
		local size = opts.size or entry.size * scale
		entry.build(model, base, size, entry, opts)
	end
	-- Lights on art pieces still need the candle glow when an asset replaced the builder.
	if usedAsset and kind == "candelabra" then
		-- a flame on each of the asset's candles (their tips were measured into the FlameTips attribute)
		local template = HouseKit.libraryModel(entry.asset)
		local tips = template and template:GetAttribute("FlameTips") or "0,3.2,0"
		for i, tip in string.split(tips, ";") do
			local c = string.split(tip, ",")
			HouseKit.flame(model, base * CFrame.new(tonumber(c[1]) * scale, tonumber(c[2]) * scale, tonumber(c[3]) * scale), 0.34, if i == 1 then 9 else 3)
		end
	end
	model.WorldPivot = base
	-- Collision: nothing to snag on (see WALK_THROUGH).
	do
		local cf, size = model:GetBoundingBox()
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") then
				d.CanCollide = false
			end
		end
		if not WALK_THROUGH[kind] then
			local collider = box(model, "Collider", size - V(0.1, 0, 0.1), cf, Color3.new(1, 1, 1), Enum.Material.SmoothPlastic, true)
			collider.Transparency = 1
			collider.CastShadow = false
			collider.CanQuery = false
			collider.CanTouch = false
		end
	end
	-- Neglect: a dust sheet thrown over it, knocked onto its back, or hanging crooked.
	if opts.tipped then
		model:PivotTo(base * CFrame.new(0, 0.5, 0) * CFrame.Angles(math.rad(-82), 0, 0))
		model.WorldPivot = base
	end
	model:SetAttribute("Kind", kind)
	model:SetAttribute("Room", room)
	model:SetAttribute("New", if allow then true else nil)
	model:SetAttribute("Placeholder", not usedAsset)
	model.Parent = folder
	return model
end

-- Hiding spot models (they have doors / a cloth that HideService animates). Library art; a plain
-- box stands in if the library is missing (then it cannot be used to hide).
-- Distance from a room's centre point to the inner face of its wall on `side`.
local function faceDist(room, side: string): number
	local c = room.center
	if side == "W" then
		return c.X - room.x0 - WALL_FACE
	elseif side == "E" then
		return room.x1 - c.X - WALL_FACE
	elseif side == "N" then
		return c.Z - room.z0 - WALL_FACE
	end
	return room.z1 - c.Z - WALL_FACE
end

local function makeHideSpot(folder, node, origin, room)
	local base0 = placer(origin + room.center)
	local rel = node.pos - room.center
	local kind = node.spot or "wardrobe"
	local name = if kind == "table" then "HideTable" else "HideWardrobe"
	local template = HouseKit.libraryModel(name)
	local depth = if template then (template:GetAttribute("Size") or V(5, 8, 2.6)).Z else 2.6
	-- how far the model reaches behind its pivot (the wardrobe's body sits toward its back): it must clear the wall
	local reach = depth / 2
	if template then
		local cf, bounds = template:GetBoundingBox()
		reach = template:GetPivot():PointToObjectSpace(cf.Position).Z + bounds.Z / 2
	end
	local base, yawSide
	if kind == "table" then
		base = base0(rel.X, 0, rel.Z, 0)
	else
		local side = node.wall or "N"
		local d = faceDist(room, side) - reach - WALL_TRIM
		local x = if side == "W" then -d elseif side == "E" then d else rel.X
		local z = if side == "N" then -d elseif side == "S" then d else rel.Z
		base = base0(x, 0, z, WALL_YAW[side])
	end
	local spot
	if template then
		spot = template:Clone()
		spot:PivotTo(base)
	else
		spot = Instance.new("Model")
		box(spot, "Placeholder", V(5, 7, 2.5), base * CFrame.new(0, 3.5, 0), WOOD, Enum.Material.Wood)
		spot.WorldPivot = base
		warn("[NightHunter] AssetLibrary." .. name .. " is missing: this hiding spot cannot be used.")
	end
	local pivot = spot:GetPivot()
	-- the library wardrobe's handles are boxes sticking straight out: replace them with slim brass pulls on the doors
	for _, doorName in { "DoorL", "DoorR" } do
		local door = spot:FindFirstChild(doorName)
		local panel = door and door:FindFirstChild("Panel")
		if panel then
			for _, child in door:GetChildren() do
				if child.Name == "Handle" then
					child:Destroy()
				end
			end
			local toSeam = if doorName == "DoorL" then 1 else -1
			local cf = panel.CFrame * CFrame.new(toSeam * (panel.Size.X / 2 - 0.3), 0.55, -panel.Size.Z / 2 - 0.06)
			box(door, "Pull", V(0.12, 1.3, 0.12), cf, BRASS, Enum.Material.Metal, false)
			box(door, "PullPlate", V(0.26, 1.7, 0.04), cf * CFrame.new(0, 0, 0.05), HouseKit.BRASS:Lerp(Color3.new(0, 0, 0), 0.3), Enum.Material.Metal, false)
		end
	end
	local function marker(markerName, cf)
		local p = box(spot, markerName, V(0.4, 0.4, 0.4), cf, Color3.new(1, 1, 1), Enum.Material.SmoothPlastic, false)
		p.Transparency = 1
		p.CanQuery = false
		p.CanTouch = false
	end
	if kind == "table" then
		marker("PromptPart", pivot * CFrame.new(0, 2, 0))
		marker("Inside", pivot * CFrame.new(0, 1, 0))
		marker("Eye", pivot * CFrame.new(0, 0.55, -3.35)) -- low, at the cloth's edge, looking out under it
	else
		marker("PromptPart", pivot * CFrame.new(0, 3.5, -depth / 2 - 0.6))
		marker("Inside", pivot * CFrame.new(0, 3, 0))
		marker("Eye", pivot * CFrame.new(0, 5.2, -depth / 2 - 0.12)) -- the gap between the doors
	end
	spot.Name = if kind == "table" then "Hiding table" else "Hiding wardrobe"
	spot:SetAttribute("Node", node.id)
	spot:SetAttribute("Kind", kind)
	spot:SetAttribute("Room", node.room)
	spot:SetAttribute("Placeholder", false)
	spot.Parent = folder
	CollectionService:AddTag(spot, Furniture.HIDE_TAG)
	return spot
end

-- What stands against each wall in the default layout: spans["<room><side>"] = { { from, to }, ... } in house
-- coordinates. The shell uses it to keep windows and sconces clear of fireplaces, wardrobes and pictures.
-- Rebuild one placed piece from the current builders, where it stands (after a builder changed: no reseed needed).
function Furniture.remake(model: Model, style: string?): Model?
	local new = makePiece(model.Parent, model:GetAttribute("Kind"), model:GetAttribute("Room"), model:GetPivot(), style or "assets", { name = model.Name })
	if new then
		model:Destroy()
	end
	return new
end

-- Adds only what the default layout has MORE of than the house has (counted per room and kind): the new pieces
-- of a changed layout arrive, and everything already placed stays exactly where it is. Rooms listed in `relay`
-- ({ [roomId] = true }) are emptied and laid out afresh instead. Returns what was added.
-- `only` ({ [roomId] = true }), if given, limits the additions to those rooms.
function Furniture.topUp(root: Instance, graph, origin: Vector3, relay: { [number]: boolean }?, only: { [number]: boolean }?): { string }
	relay = relay or {}
	local furniture = root:FindFirstChild("Furniture")
	local relayName = {}
	for roomId in relay do
		relayName[HouseDecor.THEMES[roomId].name] = true
	end
	local have, seen, added = {}, {}, {}
	for _, folder in furniture:GetChildren() do
		for _, m in folder:GetChildren() do
			local key = folder.Name .. "/" .. tostring(m:GetAttribute("Kind"))
			have[key] = (have[key] or 0) + 1
		end
	end
	allow = function(kind, roomId)
		if relay[roomId] then
			return true
		end
		if only and not only[roomId] then
			return false
		end
		local key = HouseDecor.THEMES[roomId].name .. "/" .. kind
		seen[key] = (seen[key] or 0) + 1
		return seen[key] > (have[key] or 0)
	end
	local scratch = Instance.new("Folder")
	local ok, err = pcall(Furniture.seed, scratch, graph, origin, "assets")
	allow = nil
	if not ok then
		error(err)
	end
	for _, folder in scratch.Furniture:GetChildren() do
		local target = furniture:FindFirstChild(folder.Name)
		if relayName[folder.Name] then
			if target then
				target:Destroy()
			end
			for _, m in folder:GetChildren() do
				m:SetAttribute("New", nil)
			end
			folder.Parent = furniture
			table.insert(added, folder.Name .. " (whole room)")
		else
			for _, m in folder:GetChildren() do
				if m:GetAttribute("New") then
					m:SetAttribute("New", nil)
					table.insert(added, folder.Name .. "/" .. m.Name)
					m.Parent = target
				end
			end
		end
	end
	scratch:Destroy()
	return added
end

function Furniture.wallSpans(graph)
	local spans = {}
	local function add(room, side: string, along: number, half: number)
		local key = room.id .. side
		spans[key] = spans[key] or {}
		local c = if side == "N" or side == "S" then room.center.X else room.center.Z
		table.insert(spans[key], { c + along - half, c + along + half })
	end
	for roomId = 1, graph.roomCount do
		local room = graph.rooms[roomId]
		FurnitureLayout.rooms[roomId]({
			piece = function() end,
			rug = function() end,
			size = Furniture.size,
			dist = function(side)
				return faceDist(room, side)
			end,
			wall = function(kind, side, along, opts)
				if kind ~= "planter" and kind ~= "barrel" then
					add(room, side, along, CATALOG[kind].size.X * ((opts and opts.scale) or 1) / 2)
				end
			end,
			art = function(side, along, w, h, _color, opts)
				add(room, side, along, artSize(roomId, side, along, w, h, opts and opts.kind) / 2)
			end,
		})
	end
	for _, node in graph.nodes do
		if node.kind == "hide" and node.wall then
			local room = graph.rooms[node.room]
			local along = if node.wall == "N" or node.wall == "S" then node.pos.X - room.center.X else node.pos.Z - room.center.Z
			add(room, node.wall, along, 3)
		end
	end
	return spans
end

---------------------------------------------------------------- seeding

-- Builds root.Furniture from the default layout. Replaces any existing Furniture folder, so hand
-- edits are lost: only call it on purpose (HouseBuilder.build(graph, { furniture = "reseed" })).
-- style: "blocks" (default) = rough placeholders, "assets" = library models where one exists.
function Furniture.seed(root: Instance, graph, origin: Vector3, style: string?)
	style = if style == "blocks" then "blocks" else "assets" -- real models where the library has one
	local old = root:FindFirstChild("Furniture")
	if old then
		old:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "Furniture"
	folder:SetAttribute("Version", Furniture.VERSION)
	folder:SetAttribute("Style", style)

	for roomId = 1, graph.roomCount do
		local room = graph.rooms[roomId]
		local roomFolder = Instance.new("Folder")
		roomFolder.Name = HouseDecor.THEMES[roomId].name
		local at = placer(origin + room.center)

		-- The builder context handed to FurnitureLayout.rooms[roomId]. Positions are measured from the
		-- room's centre point; `dist(side)` = how far that wall's inner face is from it.
		local ctx = {}
		function ctx.piece(kind, x, z, yaw, opts)
			opts = opts or {}
			return makePiece(roomFolder, kind, roomId, at(x, opts.y or 0, z, math.round((yaw or 0) / 90) * 90), style, opts) -- (square to the walls)
		end
		-- Against wall `side` (N/S/E/W), `along` = position along that wall; front faces into the room.
		function ctx.wall(kind, side, along, opts)
			opts = opts or {}
			local depth = CATALOG[kind].size.Z * (opts.scale or 1)
			local d = faceDist(room, side) - depth / 2 - WALL_TRIM
			local x = if side == "W" then -d elseif side == "E" then d else along
			local z = if side == "N" then -d elseif side == "S" then d else along
			return makePiece(roomFolder, kind, roomId, at(x, opts.y or 0, z, WALL_YAW[side]), style, opts)
		end
		-- A picture or mirror hung on the wall.
		function ctx.art(side, along, w, h, color, opts)
			opts = opts or {}
			opts.color = color
			w, h = artSize(roomId, side, along, w, h, opts.kind)
			opts.size = V(w, h, 0.6)
			local entry = CATALOG[opts.kind or "painting"]
			local template = style == "assets" and entry.asset and HouseKit.libraryModel(entry.asset)
			local assetSize = template and template:GetAttribute("Size")
			local depth = if assetSize then assetSize.Z * h / assetSize.Y else 0.6
			local d = faceDist(room, side) - depth / 2 - 0.12 -- (clear of the 0.1-thick wallpaper)
			local x = if side == "W" then -d elseif side == "E" then d else along
			local z = if side == "N" then -d elseif side == "S" then d else along
			return makePiece(roomFolder, opts.kind or "painting", roomId, at(x, opts.y or 9.3, z, WALL_YAW[side]), style, opts)
		end
		function ctx.rug(x, z, w, d, color)
			return makePiece(roomFolder, "rug", roomId, at(x, 0, z, 0), style, { size = V(w, 0.07, d), color = color })
		end
		ctx.size = Furniture.size
		ctx.dist = function(side)
			return faceDist(room, side)
		end

		FurnitureLayout.rooms[roomId](ctx)
		roomFolder.Parent = folder
	end

	-- windows, hanging lights and the hall's posts: built by HouseDecor, kept here so they can be moved
	local fixtures = HouseDecor.fixtures(graph, origin, require(script.Parent.HouseGeometry).segments(graph), Furniture.wallSpans(graph))
	local KIND_OF = { Window = "window", ["Ceiling light"] = "ceilingLight", ["Gallery post"] = "post", ["Landing post"] = "post", ["Gallery arch"] = "arch", Monument = "monument", ["Wall sconce"] = "sconce" }
	for roomId, holder in fixtures do
		local roomFolder = folder:FindFirstChild(HouseDecor.THEMES[roomId].name)
		for _, model in holder:GetChildren() do
			local kind = KIND_OF[model.Name] or "fixture"
			if kind == "ceilingLight" and model:FindFirstChild("Chandelier") then
				kind = "chandelier"
				model.Name = "Chandelier"
			end
			model:SetAttribute("Kind", kind)
			model:SetAttribute("Room", roomId)
			model:SetAttribute("Placeholder", false)
			model.Parent = roomFolder
		end
		holder:Destroy()
	end

	for _, node in graph.nodes do
		if node.kind == "hide" then
			makeHideSpot(folder:FindFirstChild(HouseDecor.THEMES[node.room].name), node, origin, graph.rooms[node.room])
		end
	end

	folder.Parent = root
	return folder
end

return Furniture
