--!nonstrict
-- Furniture: every piece is its OWN Model in Workspace.NightHunterHouse.Furniture/<Room>/,
-- so it can be selected, moved, rotated, resized or deleted in Studio. Nothing about a piece is
-- baked into the room, and rebuilding the house shell never touches this folder.
--
-- A piece is a rough BLOCK placeholder (position, shape, size) for now. Each Model has
--   attributes  Kind (e.g. "bed"), Room (1-17), Placeholder (true)
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
Furniture.VERSION = 3 -- bump when FurnitureLayout changes; saved furniture is NOT rebuilt automatically
Furniture.HIDE_TAG = "NightHunterHideSpot"

local V = Vector3.new

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
	local f = part(m, base, "Flame", V(0.15, 0.3, 0.15), offset, Color3.fromRGB(255, 170, 70), Enum.Material.Neon, false)
	if withLight then
		light(f, WARM_LIGHT, 11, HouseKit.CANDLE_BRIGHTNESS, true)
	end
	return f
end

local builders = {}

builders.bed = function(m, base, size, e, opts)
	local frame = part(m, base, "Frame", V(size.X, 1.4, size.Z), V(0, 0.7, 0), WOOD_DARK)
	part(m, base, "Mattress", V(size.X - 0.5, 0.9, size.Z - 1), V(0, 1.85, -0.1), (opts and opts.color) or HouseKit.CLOTH_BLUE, Enum.Material.Fabric)
	part(m, base, "Headboard", V(size.X, size.Y, 0.5), V(0, size.Y / 2, size.Z / 2 - 0.25), WOOD_DARK)
	part(m, base, "Pillow", V(2.2, 0.5, 1.2), V(0, 2.5, size.Z / 2 - 1.2), DIRTY_WHITE, Enum.Material.Fabric)
	return frame
end

builders.chair = function(m, base, size)
	local seat = part(m, base, "Seat", V(size.X, 0.4, size.Z), V(0, 2.2, 0), WOOD)
	part(m, base, "Back", V(size.X, 2.6, 0.4), V(0, 3.6, size.Z / 2 - 0.2), WOOD)
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			part(m, base, "Leg", V(0.3, 2.2, 0.3), V(sx * (size.X / 2 - 0.25), 1.1, sz * (size.Z / 2 - 0.25)), WOOD_DARK)
		end
	end
	return seat
end

builders.armchair = function(m, base, size, e, opts)
	local color = (opts and opts.color) or HouseKit.CLOTH_RED
	local seat = part(m, base, "Seat", V(size.X, 2, size.Z), V(0, 1, 0), color, Enum.Material.Fabric)
	part(m, base, "Back", V(size.X, 2.4, 0.6), V(0, 3.2, size.Z / 2 - 0.3), color, Enum.Material.Fabric)
	part(m, base, "ArmL", V(0.5, 1.2, size.Z), V(-size.X / 2 + 0.25, 2.6, 0), color, Enum.Material.Fabric)
	part(m, base, "ArmR", V(0.5, 1.2, size.Z), V(size.X / 2 - 0.25, 2.6, 0), color, Enum.Material.Fabric)
	return seat
end

builders.smallTable = function(m, base, size)
	local top = part(m, base, "Top", V(size.X, 0.3, size.Z), V(0, size.Y - 0.15, 0), WOOD)
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			part(m, base, "Leg", V(0.3, size.Y - 0.3, 0.3), V(sx * (size.X / 2 - 0.3), (size.Y - 0.3) / 2, sz * (size.Z / 2 - 0.3)), WOOD_DARK)
		end
	end
	return top
end

builders.counter = function(m, base, size)
	local body = part(m, base, "Body", V(size.X, size.Y - 0.3, size.Z), V(0, (size.Y - 0.3) / 2, 0), DIRTY_WHITE, Enum.Material.SmoothPlastic)
	part(m, base, "Top", V(size.X + 0.2, 0.3, size.Z + 0.2), V(0, size.Y - 0.15, 0), Color3.fromRGB(60, 60, 64), Enum.Material.Granite, false)
	frontMark(m, base, size, size.Y * 0.5)
	return body
end

builders.sink = function(m, base, size)
	return part(m, base, "Basin", size, V(0, size.Y / 2, 0), METAL, Enum.Material.Metal, false)
end

builders.vanity = function(m, base, size)
	local body = part(m, base, "Body", size, V(0, size.Y / 2, 0), DIRTY_WHITE, Enum.Material.SmoothPlastic)
	part(m, base, "Basin", V(2, 0.3, 1.4), V(0, size.Y + 0.15, 0), Color3.fromRGB(220, 220, 215), Enum.Material.SmoothPlastic, false)
	frontMark(m, base, size, size.Y * 0.5)
	return body
end

builders.toilet = function(m, base, size)
	local bowl = part(m, base, "Bowl", V(size.X, 1.8, size.Z), V(0, 0.9, 0), DIRTY_WHITE, Enum.Material.SmoothPlastic)
	part(m, base, "Tank", V(size.X, 1.6, 0.8), V(0, 2.6, size.Z / 2 - 0.4), DIRTY_WHITE, Enum.Material.SmoothPlastic)
	return bowl
end

builders.bathtub = function(m, base, size)
	local tub = part(m, base, "Tub", size, V(0, size.Y / 2, 0), DIRTY_WHITE, Enum.Material.SmoothPlastic)
	part(m, base, "Water", V(size.X - 0.8, 0.1, size.Z - 0.8), V(0, size.Y - 0.2, 0), Color3.fromRGB(34, 44, 40), Enum.Material.Glass, false)
	return tub
end

builders.barrel = function(m, base, size)
	local p = box(m, "Barrel", V(size.Y, size.X, size.Z), base * CFrame.new(0, size.Y / 2, 0) * CFrame.Angles(0, 0, math.pi / 2), WOOD, Enum.Material.Wood)
	p.Shape = Enum.PartType.Cylinder
	return p
end

builders.pedestal = function(m, base, size)
	return part(m, base, "Body", size, V(0, size.Y / 2, 0), DIRTY_WHITE, Enum.Material.Marble)
end

builders.clock = function(m, base, size)
	local body = part(m, base, "Body", size, V(0, size.Y / 2, 0), WOOD_DARK)
	part(m, base, "Face", V(1.5, 1.5, 0.2), V(0, 6.6, -size.Z / 2 - 0.05), DIRTY_WHITE, Enum.Material.SmoothPlastic, false)
	part(m, base, "Pendulum", V(0.2, 2.5, 0.1), V(0, 3.5, -size.Z / 2 - 0.05), BRASS, Enum.Material.Metal, false)
	return body
end

builders.fireplace = function(m, base, size)
	local body = part(m, base, "Body", size, V(0, size.Y / 2, 0), Color3.fromRGB(110, 100, 96), Enum.Material.Brick)
	part(m, base, "FireHole", V(3.6, 2.6, 0.4), V(0, 1.4, -size.Z / 2 + 0.05), Color3.fromRGB(20, 16, 14), Enum.Material.SmoothPlastic, false)
	local embers = part(m, base, "Embers", V(3, 0.5, 0.6), V(0, 0.4, -size.Z / 2 - 0.1), Color3.fromRGB(255, 90, 30), Enum.Material.Neon, false)
	light(embers, Color3.fromRGB(255, 120, 60), 15, 0.9, true)
	part(m, base, "Mantel", V(8, 0.4, 2.4), V(0, 7.1, -0.5), WOOD_DARK)
	return body
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
	local body = part(m, base, "Body", V(1, 1.4, 2.8), V(0, 2.2, 0), Color3.fromRGB(180, 150, 120))
	part(m, base, "Head", V(0.9, 1.6, 1), V(0, 3.4, -1.1), Color3.fromRGB(180, 150, 120))
	part(m, base, "Rocker", V(0.4, 0.5, size.Z), V(0, 0.25, 0), WOOD_DARK)
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

builders.painting = function(m, base, size, e, opts)
	local w, h = size.X, size.Y
	local frameP = part(m, base, "Frame", V(w, h, 0.2), V(0, 0, 0), BRASS, Enum.Material.Metal, false)
	part(m, base, "Canvas", V(w - 0.5, h - 0.5, 0.22), V(0, 0, 0), (opts and opts.color) or Color3.fromRGB(80, 70, 60), (opts and opts.material) or Enum.Material.SmoothPlastic, false)
	return frameP
end

builders.rug = function(m, base, size, e, opts)
	local color = (opts and opts.color) or HouseKit.CLOTH_RED
	local r = part(m, base, "Rug", size, V(0, 0.03, 0), color, Enum.Material.Fabric, false)
	part(m, base, "RugBorder", V(size.X - 0.8, 0.07, size.Z - 0.8), V(0, 0.035, 0), color:Lerp(Color3.new(0, 0, 0), 0.35), Enum.Material.Fabric, false)
	return r
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
	bed = item(V(5.8, 3.5, 9), WOOD_DARK, Enum.Material.Wood, builders.bed, "Furniture_Bed"),
	shelf = item(V(10.9, 8.6, 3.4), WOOD_DARK, Enum.Material.Wood, block(true), "Furniture_Shelf"),
	cabinet = item(V(4.2, 7.6, 2.5), WOOD, Enum.Material.Wood, block(true), "Furniture_Cabinet"),
	drawer = item(V(6.6, 3.6, 3.1), WOOD, Enum.Material.Wood, block(true), "Furniture_Drawer"),
	chair = item(V(2.9, 4.9, 3), WOOD, Enum.Material.Wood, builders.chair, "Furniture_Chair"),
	armchair = item(V(2.8, 4.4, 2.8), HouseKit.CLOTH_RED, Enum.Material.Fabric, builders.armchair),
	smallTable = item(V(3, 2.6, 2), WOOD, Enum.Material.Wood, builders.smallTable),
	counter = item(V(14, 3.5, 2.4), DIRTY_WHITE, Enum.Material.SmoothPlastic, builders.counter),
	sink = item(V(2.2, 0.2, 1.6), METAL, Enum.Material.Metal, builders.sink),
	stove = item(V(2.6, 3.2, 2.4), METAL, Enum.Material.Metal, block(true)),
	fridge = item(V(3, 7, 2.6), Color3.fromRGB(200, 205, 200), Enum.Material.SmoothPlastic, block(true)),
	vanity = item(V(4, 3.2, 2), DIRTY_WHITE, Enum.Material.SmoothPlastic, builders.vanity),
	toilet = item(V(1.8, 1.8, 2.4), DIRTY_WHITE, Enum.Material.SmoothPlastic, builders.toilet),
	bathtub = item(V(7, 2.6, 3.8), DIRTY_WHITE, Enum.Material.SmoothPlastic, builders.bathtub, "Bathtub"),
	barrel = item(V(2.4, 3, 2.4), WOOD, Enum.Material.Wood, builders.barrel),
	pedestal = item(V(1.4, 3, 1.4), DIRTY_WHITE, Enum.Material.Marble, builders.pedestal),
	clock = item(V(2, 8, 1.6), WOOD_DARK, Enum.Material.Wood, builders.clock),
	fireplace = item(V(7, 7, 1.6), Color3.fromRGB(110, 100, 96), Enum.Material.Brick, builders.fireplace),
	crib = item(V(2.6, 4.7, 4.2), WOOD_LIGHT, Enum.Material.Wood, builders.crib),
	rockingHorse = item(V(1, 3.4, 4), Color3.fromRGB(180, 150, 120), Enum.Material.Wood, builders.rockingHorse),
	toyBlocks = item(V(3.6, 0.8, 1.6), BRASS, Enum.Material.SmoothPlastic, builders.toyBlocks),
	boxPile = item(V(3, 3.4, 4), Color3.fromRGB(150, 120, 80), Enum.Material.Cardboard, builders.boxPile),
	candle = item(V(0.3, 1.2, 0.3), DIRTY_WHITE, Enum.Material.SmoothPlastic, builders.candle),
	candelabra = item(V(0.9, 3.2, 0.9), BRASS, Enum.Material.Metal, builders.candelabra, "Candelabra"),
	painting = item(V(3, 4, 0.2), BRASS, Enum.Material.Metal, builders.painting, "Decor_Frame", { wallHung = true }),
	mirror = item(V(3, 4.8, 0.2), BRASS, Enum.Material.Metal, builders.painting, "Decor_Mirror", { wallHung = true }),
	candlesticks = item(V(1.4, 2.1, 0.5), BRASS, Enum.Material.Metal, builders.candle, "Decor_Candlesticks"),
	rug = item(V(8, 0.07, 6), HouseKit.CLOTH_RED, Enum.Material.Fabric, builders.rug),
	sofa = item(V(8, 4, 3), HouseKit.CLOTH_RED, Enum.Material.Fabric, builders.armchair),
	piano = item(V(7, 4.6, 3), Color3.fromRGB(22, 20, 22), Enum.Material.Wood, block(true)),
	wineRack = item(V(9, 7, 2), WOOD_DARK, Enum.Material.Wood, block(true)),
	boiler = item(V(6, 9, 6), Color3.fromRGB(70, 64, 60), Enum.Material.CorrodedMetal, block(false)),
	coffin = item(V(3, 2.6, 7.5), WOOD_DARK, Enum.Material.Wood, block(true)),
	slab = item(V(4, 3.2, 8), Color3.fromRGB(150, 154, 152), Enum.Material.Metal, block(false)),
	longTable = item(V(4.5, 3.3, 6.7), WOOD_DARK, Enum.Material.Wood, builders.smallTable, "Furniture_Table"),
	-- Library art only (nothing is drawn in "blocks" style):
	cobweb = item(V(15.2, 2.8, 15.7), DIRTY_WHITE, Enum.Material.Fabric, nil, "Cobwebs", { assetOnly = true }),
	antlers = item(V(2.8, 3.9, 1.8), BRASS, Enum.Material.Metal, nil, "Decor_Antlers", { assetOnly = true, wallHung = true }),
	statuette = item(V(1.1, 2.2, 1), DIRTY_WHITE, Enum.Material.Marble, nil, "Decor_Statuette", { assetOnly = true }),
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

local function makePiece(folder, kind: string, room: number, base: CFrame, style: string, opts)
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
		local glow = box(model, "CandleGlow", V(0.2, 0.2, 0.2), base * CFrame.new(0, entry.size.Y + 0.3, 0), WARM_LIGHT, Enum.Material.Neon, false)
		glow.Transparency = 1
		light(glow, WARM_LIGHT, 11, HouseKit.CANDLE_BRIGHTNESS, true)
	end
	model.WorldPivot = base
	-- Shelves are full of old books (a few gaps, a few leaning), whatever the shelf is made of.
	if kind == "shelf" and not opts.empty then
		local rng = Random.new(opts.seed or math.floor(base.Position.X * 13 + base.Position.Z * 7))
		local colors = { Color3.fromRGB(70, 20, 20), Color3.fromRGB(30, 44, 30), Color3.fromRGB(60, 42, 26), Color3.fromRGB(26, 30, 50), Color3.fromRGB(22, 18, 16), Color3.fromRGB(96, 80, 54) }
		local width = entry.size.X * scale - 1.2
		for level = 0, 3 do
			local x = -width / 2
			local y = (0.55 + level * 2.1) * scale
			while x < width / 2 - 0.5 do
				if rng:NextNumber() < 0.12 then
					x += rng:NextNumber(0.8, 2) -- a gap
				else
					local w, h = rng:NextNumber(0.3, 0.6), rng:NextNumber(1.1, 1.7) * scale
					local lean = if rng:NextNumber() < 0.08 then math.rad(rng:NextNumber(10, 25)) else 0
					local book = box(model, "Book", V(w, h, 1.5), base * CFrame.new(x + w / 2, y + h / 2, 0.1) * CFrame.Angles(0, 0, lean), colors[rng:NextInteger(1, #colors)], Enum.Material.Fabric, false)
					book.CastShadow = false
					x += w + 0.02
				end
			end
		end
	end
	-- Neglect: a dust sheet thrown over it, knocked onto its back, or hanging crooked.
	if opts.sheet then
		local cf, size = model:GetBoundingBox()
		local cloth = Color3.fromRGB(128, 124, 116)
		local sheet = box(model, "DustSheet", size + V(0.3, 0.15, 0.3), cf * CFrame.new(0, 0.08, 0), cloth, Enum.Material.Fabric)
		sheet.CastShadow = true
		-- the cloth sags over the top and spreads at the floor
		box(model, "SheetTop", V(size.X * 0.8, 0.5, size.Z * 0.8), cf * CFrame.new(0, size.Y / 2 + 0.25, 0), cloth, Enum.Material.Fabric, false)
		box(model, "SheetHem", V(size.X + 1, 0.7, size.Z + 1), cf * CFrame.new(0, -size.Y / 2 + 0.35, 0), cloth:Lerp(Color3.new(0, 0, 0), 0.12), Enum.Material.Fabric, false)
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") and d ~= sheet and d.Name ~= "SheetHem" and d.Name ~= "SheetTop" then
				d.Transparency = 1 -- only the sheet shows; the shape under it is what it was
				d.CanCollide = false
			end
		end
	end
	if opts.tipped then
		model:PivotTo(base * CFrame.new(0, 0.5, 0) * CFrame.Angles(math.rad(-82), 0, 0))
		model.WorldPivot = base
	end
	if opts.tilt then
		local cf = model:GetBoundingBox()
		model:PivotTo(cf * CFrame.Angles(0, 0, math.rad(opts.tilt)) * cf:ToObjectSpace(model:GetPivot()))
	end
	model:SetAttribute("Kind", kind)
	model:SetAttribute("Room", room)
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
	local base, yawSide
	if kind == "table" then
		base = base0(rel.X, 0, rel.Z, 0)
	else
		local side = node.wall or "N"
		local d = faceDist(room, side) - depth / 2 - 0.05
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
			return makePiece(roomFolder, kind, roomId, at(x, opts.y or 0, z, yaw), style, opts)
		end
		-- Against wall `side` (N/S/E/W), `along` = position along that wall; front faces into the room.
		function ctx.wall(kind, side, along, opts)
			opts = opts or {}
			local depth = CATALOG[kind].size.Z * (opts.scale or 1)
			local d = faceDist(room, side) - depth / 2 - 0.05
			local x = if side == "W" then -d elseif side == "E" then d else along
			local z = if side == "N" then -d elseif side == "S" then d else along
			return makePiece(roomFolder, kind, roomId, at(x, opts.y or 0, z, WALL_YAW[side]), style, opts)
		end
		-- A picture or mirror hung on the wall.
		function ctx.art(side, along, w, h, color, opts)
			opts = opts or {}
			opts.color = color
			opts.size = V(w, h, 0.2)
			local entry = CATALOG[opts.kind or "painting"]
			local template = style == "assets" and entry.asset and HouseKit.libraryModel(entry.asset)
			local assetSize = template and template:GetAttribute("Size")
			local depth = if assetSize then assetSize.Z * h / assetSize.Y else 0.4
			local d = faceDist(room, side) - depth / 2 - 0.05
			local x = if side == "W" then -d elseif side == "E" then d else along
			local z = if side == "N" then -d elseif side == "S" then d else along
			return makePiece(roomFolder, opts.kind or "painting", roomId, at(x, opts.y or 8, z, WALL_YAW[side]), style, opts)
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

	for _, node in graph.nodes do
		if node.kind == "hide" then
			makeHideSpot(folder:FindFirstChild(HouseDecor.THEMES[node.room].name), node, origin, graph.rooms[node.room])
		end
	end

	folder.Parent = root
	return folder
end

return Furniture
