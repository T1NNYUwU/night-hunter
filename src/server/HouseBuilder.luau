--!nonstrict
-- Builds the playable mansion from the HouseGraph. It has THREE separate layers:
--
--   Shell      floors and ceilings (with stairwells cut out), walls with doorways, door frames + doors,
--              the two hall staircases and the two service stairs, railings, wallpaper, windows, ceiling
--              lights, the front door and the hall pillar (HouseDecor). Generated from code; rebuilt
--              whenever the graph changes.
--   Furniture  every piece an independent Model you can move in Studio (Furniture.lua). Seeded once,
--              then it is YOURS: rebuilding the shell never touches it.
--   (root)     the spawn pad, one belief marker per node, and runtime things (lair, objectives).
--
-- The house is saved in the place (so it shows in Edit mode). Build or rebuild it from the command bar:
--   local HB = require(game.ServerScriptService.NightHunter.HouseBuilder)
--   local graph = require(game.ReplicatedStorage.NightHunter.HouseGraph).build()
--   HB.build(graph)                                 -- rebuild walls/doors/lights, KEEP the furniture
--   HB.build(graph, { furniture = "reseed" })       -- also put the furniture back to the default layout
--   HB.build(graph, { furniture = "reseed", style = "assets" })  -- default layout with library models
-- (In Edit mode, clone the folders before require so an old cached module is not used; see handoff.md.)
-- At runtime ensure() reuses the saved house, or rebuilds the shell if the graph has changed since.

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local ServerStorage = game:GetService("ServerStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local HouseGraph = require(game:GetService("ReplicatedStorage"):WaitForChild("NightHunter"):WaitForChild("HouseGraph"))
local HouseDecor = require(script.Parent.HouseDecor)
local HouseKit = require(script.Parent.HouseKit)
local HouseGeometry = require(script.Parent.HouseGeometry)
local Furniture = require(script.Parent.Furniture)

local HOUSE_NAME = "NightHunterHouse"
local LAYOUT = 6 -- house structure version: 6 = 16-wide corridors and real doors (older houses are rebuilt whole)
local ORIGIN = Vector3.new(0, 50, 0)
local LEVEL = HouseGraph.LEVEL_HEIGHT
local CLEAR = HouseGraph.CLEAR
local STEP = HouseGraph.STEP_RISE
local THICK = HouseGeometry.WALL_THICK

local WALL_COLOR = Color3.fromRGB(62, 46, 38) -- shows only as door jambs and lintels
local TRIM_COLOR = Color3.fromRGB(44, 31, 24)
local CEILING_COLOR = Color3.fromRGB(40, 36, 34)
local STAIR_COLOR = Color3.fromRGB(70, 52, 42)
local CARPET_COLOR = Color3.fromRGB(110, 36, 42)
local V = Vector3.new

-- Railings around stairwells: { x1, z1, x2, z2, floorY } (house-local). The openings stay open where
-- the stairs arrive.
local RAILS = {
	-- the rear balcony, open between the flights where the bowed landing joins it
	{ -34, 12, -7.3, 12, LEVEL },
	{ 7.3, 12, 34, 12, LEVEL },
	-- the galleries round the hall: both sides and across the front
	{ -34, 12, -34, 84, LEVEL },
	{ 34, 12, 34, 84, LEVEL },
	{ -34, 84, 34, 84, LEVEL },
	-- the servants' back stair: the hole in the servants' hall (top reached from the north end) ...
	{ 70, -45, 70, -25, 0 },
	{ 70, -25, 79, -25, 0 },
	-- ... and the hole in the maid's room (top reached from the south end)
	{ 61, -45, 61, -25, LEVEL },
	{ 70, -45, 70, -25, LEVEL },
	{ 61, -45, 70, -45, LEVEL },
	-- the secret stair in the library (reached from the west end, by the bookcases)
	{ -72, 29, -52, 29, 0 },
	{ -52, 21, -52, 29, 0 },
}

local HouseBuilder = {}

local function part(parent, name, size, position, color, material, transparency)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.Position = position
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Transparency = transparency or 0
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- A doorway's frame (jambs + header, a little proud of the wall) and a door standing open; a wide
-- doorway is an open archway instead: heavy pilasters and a deep header, no door.
-- wallCF: the doorway's floor centre, local X along the wall, local Z through it.
local function doorway(parent, wallCF: CFrame, seed: number, width: number, height: number, arch: boolean)
	local m = Instance.new("Model")
	m.Name = if arch then "Archway" else "Doorway"
	local function trim(name, size, offset, color, material)
		local p = part(m, name, size, Vector3.zero, color or TRIM_COLOR, material or Enum.Material.Wood)
		p.CFrame = wallCF * CFrame.new(offset)
		p.CanCollide = false
		return p
	end
	if arch then
		for _, sx in { -1, 1 } do
			trim("Pilaster", V(1.2, height, 1.8), V(sx * (width / 2 + 0.4), height / 2, 0))
			trim("PilasterBase", V(1.5, 1, 2.2), V(sx * (width / 2 + 0.4), 0.5, 0))
			trim("PilasterCap", V(1.5, 0.6, 2.3), V(sx * (width / 2 + 0.4), height - 0.3, 0))
			-- the corners of the arch step down from the header
			trim("Spandrel", V(1.4, 1, 1.6), V(sx * (width / 2 - 0.7), height - 0.5, 0))
			if width >= 10 then
				trim("Spandrel", V(1, 0.6, 1.6), V(sx * (width / 2 - 1.9), height - 0.3, 0))
			end
		end
		trim("Header", V(width + 2, 1, 2), V(0, height + 0.5, 0))
		trim("Pediment", V(width + 3, 0.4, 2.3), V(0, height + 1.2, 0))
		trim("Keystone", V(1.2, 1.8, 2.3), V(0, height + 0.3, 0), HouseKit.WOOD, Enum.Material.Wood)
		m.Parent = parent
		return m
	end
	-- the frame fills the wall's whole thickness and stands proud of it on both sides
	for _, sx in { -1, 1 } do
		trim("Architrave", V(1, height + 1, 1.9), V(sx * (width / 2 + 0.5), (height + 1) / 2, 0))
		trim("Jamb", V(0.5, height, 1.5), V(sx * (width / 2 - 0.25), height / 2, 0))
		trim("Plinth", V(1.2, 0.9, 2.1), V(sx * (width / 2 + 0.5), 0.45, 0), Color3.fromRGB(34, 24, 18))
	end
	trim("HeadJamb", V(width, 0.5, 1.5), V(0, height - 0.25, 0))
	trim("Header", V(width + 2, 1, 1.9), V(0, height + 0.5, 0))
	trim("Pediment", V(width + 3, 0.4, 2.3), V(0, height + 1.2, 0))

	-- The door itself: a Model "Leaf" pivoting on its hinge, shut. DoorService swings it (tag NightHunterDoor).
	local rng = Random.new(seed)
	local side = if rng:NextNumber() < 0.5 then -1 else 1 -- which jamb
	local leafW, leafH = width - 0.96, height - 0.5 -- the clear opening, and a hair into the frame all round: no slit of light
	local hinge = wallCF * CFrame.new(side * (width / 2 - 0.48), 0, 0)
	local leaf = Instance.new("Model")
	leaf.Name = "Leaf"
	local function onLeaf(name, size, offset, color, material)
		local p = part(leaf, name, size, Vector3.zero, color, material)
		p.CFrame = hinge * CFrame.new(-side * leafW / 2, 0, 0) * CFrame.new(offset)
		p.CanCollide = false
		return p
	end
	local slab = onLeaf("Slab", V(leafW, leafH, 0.72), V(0, leafH / 2 + 0.02, 0), HouseKit.WOOD, Enum.Material.Wood)
	slab.CanCollide = true
	local stile = 0.62
	local rows = { { leafH * 0.25, leafH * 0.3 }, { leafH * 0.68, leafH * 0.42 } } -- { centre, height } of the two panels
	for _, sz in { -1, 1 } do
		for _, row in rows do
			local inset = onLeaf("Panel", V(leafW - stile * 2, row[2], 0.03), V(0, row[1], sz * 0.36), HouseKit.WOOD_DARK, Enum.Material.Wood)
			inset.CanCollide = false
			onLeaf("PanelRaise", V(leafW - stile * 2 - 0.7, row[2] - 0.7, 0.08), V(0, row[1], sz * 0.4), HouseKit.WOOD, Enum.Material.Wood)
		end
		local kx, ky = -side * (leafW / 2 - 0.42), 4.6 -- (the knob on the free edge, away from the hinge)
		onLeaf("KnobPlate", V(0.34, 1.1, 0.04), V(kx, ky, sz * 0.38), HouseKit.BRASS, Enum.Material.Metal)
		local knob = onLeaf("Knob", V(0.34, 0.34, 0.34), V(kx, ky + 0.18, sz * 0.56), HouseKit.BRASS, Enum.Material.Metal)
		knob.Shape = Enum.PartType.Ball
		onLeaf("KnobNeck", V(0.14, 0.14, 0.2), V(kx, ky + 0.18, sz * 0.46), HouseKit.BRASS, Enum.Material.Metal)
	end
	for _, y in { leafH * 0.14, leafH * 0.5, leafH * 0.86 } do
		onLeaf("Hinge", V(0.14, 0.6, 0.8), V(side * (leafW / 2 - 0.02), y, 0), HouseKit.BRASS, Enum.Material.Metal)
	end
	if rng:NextNumber() < 0.3 then -- something has been at this one
		for k = -1, 1 do
			local mark = onLeaf("Scratch", V(0.07, 2.4 - math.abs(k) * 0.5, 0.02), V(k * 0.28, 6.4, 0.372), Color3.fromRGB(12, 9, 8), Enum.Material.SmoothPlastic)
			mark.CFrame *= CFrame.Angles(0, 0, math.rad(16))
		end
	end
	leaf.WorldPivot = hinge
	leaf:SetAttribute("Side", side)
	leaf.Parent = m
	CollectionService:AddTag(leaf, "NightHunterDoor")
	local prompt = part(m, "DoorPrompt", V(0.4, 0.4, 0.4), Vector3.zero, TRIM_COLOR, Enum.Material.SmoothPlastic, 1)
	prompt.CFrame = wallCF * CFrame.new(0, 4.6, 0)
	prompt.CanCollide = false
	prompt.CanQuery = false
	prompt.CanTouch = false
	m.Parent = parent
	return m
end

-- One wall segment (HouseGeometry): solid, or with a doorway / the front door gap.
local function buildWall(walls, doors, seg, seed: number)
	local bottom, top = seg.floorY - 1, seg.floorY + LEVEL
	local function piece(name, from, to, y0, y1)
		if to - from <= 0.05 or y1 - y0 <= 0.05 then
			return
		end
		local mid, cy = (from + to) / 2, (y0 + y1) / 2
		local size = if seg.axisX then V(to - from, y1 - y0, THICK) else V(THICK, y1 - y0, to - from)
		local pos = if seg.axisX then V(mid, cy, seg.line) else V(seg.line, cy, mid)
		part(walls, "Wall", size, ORIGIN + pos, WALL_COLOR, Enum.Material.Wood)
	end
	if not seg.doorAt then
		piece("Wall", seg.lo, seg.hi, bottom, top)
		return
	end
	local width, height = HouseGeometry.doorSize(seg)
	piece("Wall", seg.lo, seg.doorAt - width / 2, bottom, top)
	piece("Wall", seg.doorAt + width / 2, seg.hi, bottom, top)
	piece("Lintel", seg.doorAt - width / 2, seg.doorAt + width / 2, seg.floorY + height, top)
	if not seg.entrance then
		local at = if seg.axisX then V(seg.doorAt, seg.floorY, seg.line) else V(seg.line, seg.floorY, seg.doorAt)
		local wallCF = CFrame.new(ORIGIN + at) * (if seg.axisX then CFrame.new() else CFrame.Angles(0, math.pi / 2, 0))
		doorway(doors, wallCF, seed, width, height, HouseGeometry.isArch(seg))
	end
end

-- Floors (with the stairwell holes) and ceilings. A room's ceiling is the floor of the room above;
-- a room with nothing above gets a roof.
local function buildSlabs(floors, graph)
	for _, room in graph.rooms do
		local theme = HouseDecor.THEMES[room.id]
		for _, r in HouseGeometry.floorPieces(room) do
			local w, d = r.x1 - r.x0, r.z1 - r.z0
			local cx, cz = (r.x0 + r.x1) / 2, (r.z0 + r.z1) / 2
			part(floors, "Floor" .. room.id, V(w, 0.5, d), ORIGIN + V(cx, room.floorY - 0.25, cz), theme.floor, theme.floorMat)
			part(floors, "FloorUnder", V(w, 0.5, d), ORIGIN + V(cx, room.floorY - 0.75, cz), CEILING_COLOR, Enum.Material.Plaster)
		end
		if not HouseGeometry.hasRoomAbove(graph, room) then
			local w, d = room.x1 - room.x0, room.z1 - room.z0
			local cx, cz = (room.x0 + room.x1) / 2, (room.z0 + room.z1) / 2
			part(floors, "Ceiling" .. room.id, V(w, 1, d), ORIGIN + V(cx, room.floorY + CLEAR + 0.5, cz), CEILING_COLOR, Enum.Material.Plaster)
		end
	end
end

local RAIL_WOOD = Color3.fromRGB(58, 28, 18)
-- The great hall is an old gothic hall of dark carved wood with tarnished brass; the rest of the house has plain
-- turned rails.
local CASTLE_STONE = Color3.fromRGB(62, 38, 26) -- (the hall's polished dark wood)
local CASTLE_STONE_DARK = Color3.fromRGB(38, 24, 17)
local CASTLE_GOLD = Color3.fromRGB(88, 68, 38)
local RAIL = { color = RAIL_WOOD, material = Enum.Material.Wood, stone = false, iron = false }
-- iron: the hall's galleries get wrought-iron panels (AssetLibrary.Asset_IronPanel) under a dark wooden handrail
local function railStyle(stone: boolean, iron: boolean?)
	RAIL.stone = stone
	RAIL.iron = iron == true
	RAIL.color = if stone then CASTLE_STONE else RAIL_WOOD
	RAIL.material = if stone then Enum.Material.Wood else Enum.Material.Wood
end

-- One round bar along a rail (Roblox cylinders run along X).
local function railBar(parent, name, cf: CFrame, length: number, diameter: number)
	local bar = part(parent, name, V(length, diameter, diameter), Vector3.zero, if RAIL.stone and name == "HandrailBead" then CASTLE_GOLD else RAIL.color, if RAIL.stone and name == "HandrailBead" then Enum.Material.Metal else RAIL.material)
	bar.Shape = Enum.PartType.Cylinder
	bar.CFrame = cf * CFrame.Angles(0, math.pi / 2, 0)
	bar.CanCollide = false
	return bar
end

-- A turned post from the library (one solid piece each), or a plain one if the library is missing.
local function turnedPost(parent, newel: boolean, foot: Vector3, height: number)
	local template = HouseKit.libraryModel(if newel then "Asset_Newel" else "Asset_Baluster")
	local natural = template and template:GetAttribute("Size") or V(if newel then 1.5 else 0.6, height, if newel then 1.5 else 0.6)
	local size = V(natural.X, height, natural.Z)
	local post
	if template then
		post = template:FindFirstChildWhichIsA("BasePart"):Clone()
		post.Size = size
		post.Parent = parent
	else
		post = part(parent, if newel then "Newel" else "Baluster", size, Vector3.zero, HouseKit.WOOD, Enum.Material.Wood)
	end
	post.Name = if newel then "Newel" else "Baluster"
	if RAIL.stone then
		post.Color = CASTLE_STONE
		post.Material = Enum.Material.Wood
	end
	post.CFrame = CFrame.new(foot + V(0, height / 2, 0))
	post.CanCollide = false
end

-- A balustrade between two points (house-local), `y` = the lower end's floor, tilted if the ends differ in
-- height: a round moulded handrail on turned posts, with carved newels at the ends.
-- continuing: part of a longer curved rail. noPost: this short piece carries no post of its own.
local function balustrade(parent, a: Vector3, b: Vector3, height: number, newelStart: boolean?, newelEnd: boolean?, noPost: boolean?)
	local mid = (a + b) / 2
	local length = (b - a).Magnitude
	local cf = if length < 0.01 then CFrame.new(ORIGIN + mid) else CFrame.lookAt(ORIGIN + mid, ORIGIN + b)
	-- an invisible panel stops anyone falling; what you see is an open row of turned posts
	local guard = part(parent, "RailGuard", V(0.4, height + 0.8, length), Vector3.zero, WALL_COLOR, Enum.Material.Wood, 1)
	guard.CFrame = cf + V(0, (height + 0.8) / 2, 0) -- (straight up: on a slope the part's own up axis leans back)
	guard.CastShadow = false
	railBar(parent, "Handrail", cf + V(0, height + 0.28, 0), length + 0.14, 0.62)
	railBar(parent, "HandrailBead", cf + V(0, height - 0.08, 0), length + 0.14, 0.32)
	if noPost then
		return -- (a piece of a curved rail: its posts stand on the treads, one a step)
	end
	local ironPanel = RAIL.iron and HouseKit.libraryModel("Asset_IronPanel")
	if ironPanel then
		-- wrought-iron panels, one every ~5 studs, stretched to fill the run exactly, with an iron post at each joint
		local panelPart = ironPanel:FindFirstChildWhichIsA("BasePart", true)
		local count = math.max(1, math.floor(length / 5 + 0.5))
		local each = length / count
		for i = 1, count do
			local t = length / 2 - (i - 0.5) * each
			local panel = panelPart:Clone()
			panel.Size = V(each - 0.12, height + 0.1, 0.3)
			panel.CFrame = (cf * CFrame.new(0, 0, t)) * CFrame.Angles(0, math.pi / 2, 0) + V(0, (height + 0.1) / 2, 0)
			panel.Name = "IronPanel"
			panel.Parent = parent
		end
		for i = 0, count do
			local t = length / 2 - i * each
			local endPost = (i == 0 and newelStart ~= false) or (i == count and newelEnd ~= false)
			if endPost then
				turnedPost(parent, true, (cf * CFrame.new(0, 0, t)).Position, height + 1.8)
			else
				local bar = part(parent, "IronPost", V(0.22, height + 0.2, 0.22), (cf * CFrame.new(0, 0, t)).Position + V(0, (height + 0.2) / 2, 0), Color3.fromRGB(26, 26, 28), Enum.Material.Metal)
				bar.CanCollide = false
			end
		end
		return
	end
	railBar(parent, "RailBase", cf + V(0, 0.18, 0), length + 0.14, 0.42)
	local count = math.max(1, math.floor(length / 1.4))
	for i = if newelStart == false then 1 else 0, count do -- (a continuing rail: the last post of the previous piece stands here)
		local t = length / 2 - i * length / count -- (i = 0 is end a; a CFrame looks along -Z)
		local newel = (i == 0 and newelStart ~= false) or (i == count and newelEnd ~= false)
		-- upright even on a sloping rail: place by position along the rail, then stand it straight
		turnedPost(parent, newel, (cf * CFrame.new(0, 0, t)).Position, if newel then height + 1.8 else height)
	end
end

-- A right-triangle prism standing upright (WedgePart: right angle at local -Y/+Z, legs along +Y and -Z, extruded along X).
local function wedgeColumn(parent, name, corner: Vector3, along: Vector3, lengthAlong: number, out: Vector3, lengthOut: number, y0: number, y1: number, color, material)
	local w = Instance.new("WedgePart")
	w.Name = name
	w.Anchored = true
	w.Size = V(y1 - y0, lengthAlong, lengthOut)
	w.CFrame = CFrame.fromMatrix(corner + along * lengthAlong / 2 - out * lengthOut / 2 + V(0, (y0 + y1) / 2, 0), along:Cross(out), along, out)
	w.Color = color
	w.Material = material
	w.TopSurface = Enum.SurfaceType.Smooth
	w.BottomSurface = Enum.SurfaceType.Smooth
	w.Parent = parent
	return w
end

-- One fan-shaped slice of a ring between radii ri and ro, across `halfAngle` either side of angle `a`, y0..y1.
local function fanSlice(parent, name, centre: Vector3, a: number, halfAngle: number, ri: number, ro: number, y0: number, y1: number, color, material, collide)
	local u, t = V(math.cos(a), 0, math.sin(a)), V(-math.sin(a), 0, math.cos(a))
	local sh, ch = math.sin(halfAngle), math.cos(halfAngle)
	local hi, ho, ra, rb = ri * sh, ro * sh, ri * ch, ro * ch
	local mid = centre + u * (ra + rb) / 2 + V(0, (y0 + y1) / 2, 0)
	local pieces = { part(parent, name, V(hi * 2, y1 - y0, rb - ra), Vector3.zero, color, material) }
	pieces[1].CFrame = CFrame.lookAt(mid, mid + u)
	for _, s in { -1, 1 } do
		table.insert(pieces, wedgeColumn(parent, name, centre + u * rb + t * s * hi, t * s, ho - hi, u, rb - ra, y0, y1, color, material))
	end
	if collide == false then
		for _, p in pieces do
			p.CanCollide = false
		end
	end
end

-- One flight of the imperial stair: a short straight run, then fan-shaped treads round a quarter circle, with a carpet
-- up the middle and over each riser, a brass rod on every step, panelled sides, and one turned baluster per step.
local function buildArcStairs(parent, s, yLow: number, yHigh: number, n: number)
	local centre, radius, a0, a1 = HouseGraph.stairArc(s)
	centre += ORIGIN
	local half = s.width / 2
	local ri, ro = radius - half, radius + half
	local arcSteps = n - s.footSteps
	local da = (a1 - a0) / arcSteps
	local RAIL_H = 4.4
	railStyle(true)
	local function edge(o, t)
		return HouseGraph.arcEdge(s, o, t)
	end
	for i = 1, n do
		local top = yLow + i
		local capped = if i == n then top - 0.03 else top
		if i <= s.footSteps then
			local p, q = edge(0, i - 1), edge(0, i)
			local mid = ORIGIN + (p + q) / 2
			local tread = (q - p).Magnitude
			local bottom = yLow - 0.5
			part(parent, "Step", V(s.width, capped - bottom, tread + 0.02), mid + V(0, (bottom + capped) / 2, 0), CASTLE_STONE, Enum.Material.Wood)
			local carpet = part(parent, "Carpet", V(s.width - 2.6, 0.06, tread + 0.02), mid + V(0, capped + 0.03, 0), CARPET_COLOR, Enum.Material.Fabric)
			carpet.CanCollide = false
		else
			local a = a0 + (i - s.footSteps - 0.5) * da
			fanSlice(parent, "Step", centre, a, math.abs(da) / 2, ri, ro, yLow - 0.5, capped, CASTLE_STONE, Enum.Material.Wood)
			fanSlice(parent, "Carpet", centre, a, math.abs(da) / 2, ri + 1.3, ro - 1.3, capped, capped + 0.06, CARPET_COLOR, Enum.Material.Fabric, false)
		end
		-- the riser at the step's front edge, and its brass rod
		local a, b = edge(-half + 1.3, i - 1), edge(half - 1.3, i - 1)
		local up = (edge(0, i) - edge(0, i - 1)).Unit
		local at = ORIGIN + (a + b) / 2 + V(0, yLow + i - 0.5, 0)
		local across = (b - a).Unit
		local riser = part(parent, "CarpetRiser", V(0.06, 1, (b - a).Magnitude), Vector3.zero, CARPET_COLOR, Enum.Material.Fabric)
		riser.CFrame = CFrame.lookAt(at - up * 0.03, at - up * 0.03 + across)
		riser.CanCollide = false
		local rodAt = at - V(0, 0.38, 0) - up * 0.16
		local rod = part(parent, "StairRod", V((b - a).Magnitude + 0.4, 0.14, 0.14), Vector3.zero, CASTLE_GOLD, Enum.Material.Metal)
		rod.Shape = Enum.PartType.Cylinder
		rod.CFrame = CFrame.lookAt(rodAt, rodAt + across) * CFrame.Angles(0, math.pi / 2, 0)
		rod.CanCollide = false
	end
	-- panelled side walls following each edge
	local samples = n * 2
	for _, o in { -half - 0.05, half + 0.05 } do
		for k = 1, samples do
			local p, q = ORIGIN + edge(o, (k - 1) / 2), ORIGIN + edge(o, k / 2)
			local yp, yq = yLow + (k - 1) / 2, yLow + k / 2
			local midP = (p + q) / 2
			local h = (yp + yq) / 2 + 0.5 - yLow
			local panel = part(parent, "Stringer", V(0.5, h, (q - p).Magnitude + 0.12), Vector3.zero, CASTLE_STONE_DARK, Enum.Material.Wood)
			panel.CFrame = CFrame.lookAt(midP + V(0, yLow + h / 2, 0), q + V(0, yLow + h / 2, 0))
			panel.CanCollide = false
			local from, to = p + V(0, yp + 0.62, 0), q + V(0, yq + 0.62, 0)
			local cap = part(parent, "StringerCap", V(0.62, 0.26, (to - from).Magnitude + 0.1), Vector3.zero, CASTLE_GOLD, Enum.Material.Metal)
			cap.CFrame = CFrame.lookAt((from + to) / 2, to)
			cap.CanCollide = false
		end
	end
	for _, o in { -half + 0.3, half - 0.3 } do
		for k = 1, samples do
			balustrade(parent, edge(o, (k - 1) / 2) + V(0, yLow + (k - 1) / 2, 0), edge(o, k / 2) + V(0, yLow + k / 2, 0), RAIL_H, false, false, true)
		end
		for i = 1, n do
			turnedPost(parent, false, ORIGIN + edge(o, i - 0.5) + V(0, yLow + i, 0), RAIL_H - 0.4)
		end
		turnedPost(parent, true, ORIGIN + edge(o, 0) + V(0, yLow, 0), RAIL_H + 1.8)
		turnedPost(parent, true, ORIGIN + edge(o, n) + V(0, yHigh, 0), RAIL_H + 1.8)
	end
	railStyle(false)
end

-- The bowed landing where the two flights meet: a square bay off the rear balcony and a half-round front, carried on a
-- pair of columns over the way through to the corridor.
local function buildBowLanding(parent)
	local top = LEVEL - 0.03
	local centre = ORIGIN + V(0, 0, 24)
	local function disc(name, height, diameter, y, color, material)
		local p = part(parent, name, V(height, diameter, diameter), Vector3.zero, color, material)
		p.Shape = Enum.PartType.Cylinder
		p.CFrame = CFrame.new(centre + V(0, y, 0)) * CFrame.Angles(0, 0, math.pi / 2)
		return p
	end
	railStyle(true)
	part(parent, "Landing", V(14, 1.2, 12), ORIGIN + V(0, top - 0.6, 18), CASTLE_STONE, Enum.Material.Wood)
	disc("Landing", 1.2, 14, top - 0.62, CASTLE_STONE, Enum.Material.Wood)
	disc("LandingBand", 0.5, 14.5, top - 1, CASTLE_STONE_DARK, Enum.Material.Wood).CanCollide = false
	disc("LandingBand", 0.2, 15, top - 1.35, CASTLE_GOLD, Enum.Material.Metal).CanCollide = false
	local rug = part(parent, "Carpet", V(11.4, 0.06, 12), ORIGIN + V(0, top + 0.03, 18), CARPET_COLOR, Enum.Material.Fabric)
	rug.CanCollide = false
	disc("Carpet", 0.06, 11.4, top + 0.02, CARPET_COLOR, Enum.Material.Fabric).CanCollide = false
	railStyle(true, true)
	local r, pieces = 6.7, 7
	for j = 1, pieces do
		local a0, a1 = math.pi * (j - 1) / pieces, math.pi * j / pieces
		local p = V(math.cos(a0) * r, LEVEL, 24 + math.sin(a0) * r)
		local q = V(math.cos(a1) * r, LEVEL, 24 + math.sin(a1) * r)
		balustrade(parent, p, q, 4.4, false, false)
	end
	railStyle(false)
end

-- One staircase: solid steps (1 stud rise each) along its centre line from the foot up to the top, and
-- balustrades on the open sides. The grand flights are arcs (buildArcStairs).
local function buildStairs(parent, graph, s)
	local low, high = graph.rooms[s.low], graph.rooms[s.high]
	local yLow, yHigh = low.floorY, high.floorY
	local n = math.floor((yHigh - yLow) / STEP + 0.5)
	if s.arc then
		buildArcStairs(parent, s, yLow, yHigh, n)
		return
	end
	-- A closed-string flight: treads between two deep side boards (the strings), a boarded soffit beneath, and a
	-- balustrade standing on each string. Nothing solid under it: the room stays open below the stair.
	local path = HouseGraph.stairPath(s, n)
	local first, last = V(path[1].X, 0, path[1].Z), V(path[#path].X, 0, path[#path].Z)
	local run = (last - first).Magnitude
	local runDir = (last - first).Unit
	local perp = V(-runDir.Z, 0, runDir.X)
	local tread = run / n
	local cos = tread / math.sqrt(tread * tread + STEP * STEP)
	local slope = (runDir * tread + V(0, STEP, 0)).Unit
	for i = 1, n do
		local mid = first + runDir * ((i - 0.5) * tread)
		local centre = ORIGIN + V(mid.X, yLow + i * STEP - 0.55, mid.Z)
		local step = part(parent, "Step", V(s.width, 1.1, tread + 0.02), Vector3.zero, STAIR_COLOR, Enum.Material.Wood)
		step.CFrame = CFrame.lookAt(centre, centre + runDir)
	end
	-- A board along the flight. `top`, `bottom`: how far below the line of the steps' nosings it reaches (straight
	-- down); `across`: its offset from the centre line; it starts `x0` along the run (clear of the floor at the foot).
	local dark = STAIR_COLOR:Lerp(Color3.new(0, 0, 0), 0.3)
	local function board(name, across, thick, top, bottom, x0, collide)
		local xm = (x0 + run) / 2
		local centre = ORIGIN + first + runDir * xm + perp * across + V(0, yLow + (xm / tread + 1) * STEP - (top + bottom) / 2, 0)
		local p = part(parent, name, V(thick, (bottom - top) * cos, (run - x0) / cos), Vector3.zero, dark, Enum.Material.Wood)
		p.CFrame = CFrame.lookAt(centre, centre + slope)
		p.CanCollide = collide
	end
	board("Soffit", 0, s.width - 0.5, 1.05, 2.2, 0.3 * tread, false)
	local segments = 4
	local railPath = HouseGraph.stairPath(s, segments)
	local upTo = math.max(1, math.floor(segments * (s.railTo or 1) + 0.5))
	for _, side in { -1, 1 } do
		local out = perp * side * (s.width / 2 + 0.1)
		board("Stringer", side * (s.width / 2 + 0.1), 0.4, -0.2, 2.3, 0.25 * tread, true)
		local base = part(parent, "NewelBase", V(1.5, STEP + 0.3, 1.5), ORIGIN + first + out + V(0, yLow + (STEP + 0.3) / 2, 0), RAIL_WOOD, Enum.Material.Wood)
		base.CanCollide = false
		for k = 1, upTo do
			local ya = yLow + (yHigh - yLow) * (k - 1) / segments + STEP + 0.2 -- (on top of the string)
			local yb = yLow + (yHigh - yLow) * k / segments + STEP + 0.2
			local a, b = railPath[k], railPath[k + 1]
			balustrade(parent, V(a.X, ya, a.Z) + out, V(b.X, yb, b.Z) + out, 4.4, k == 1, k == upTo)
		end
	end
end

local function effect(className, name, props)
	local e = Lighting:FindFirstChild(name) or Instance.new(className)
	e.Name = name
	for k, v in props do
		e[k] = v
	end
	e.Parent = Lighting
end

-- An old mansion at night: pools of amber lamp light, deep brown shadow between them, a faint film over
-- everything. You can make out the room, but the corners belong to the dark.
local function applyLighting()
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
	atmosphere.Density = 0.26 -- (thin enough that a lit doorway at the far end of a corridor still shows: lights are landmarks)
	atmosphere.Offset = 0
	atmosphere.Color = Color3.fromRGB(26, 32, 40) -- a cold blue-grey haze, the candles the only warm light
	atmosphere.Decay = Color3.fromRGB(10, 12, 16)
	atmosphere.Glare = 0
	atmosphere.Haze = 0.6
	atmosphere.Parent = Lighting
	Lighting.ClockTime = 0
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = 0.2
	Lighting.EnvironmentDiffuseScale = 0.15
	Lighting.EnvironmentSpecularScale = 0.2
	-- The place template's own "Bloom" (intensity 1, size 24) ran on top of ours: every bulb became a ball of fog.
	for _, child in Lighting:GetChildren() do
		if child:IsA("PostEffect") and not child.Name:match("^NightHunter") then
			child.Enabled = false
		end
	end
	effect("ColorCorrectionEffect", "NightHunterGrade", { Saturation = -0.12, Contrast = 0.1, Brightness = 0, TintColor = Color3.fromRGB(226, 234, 255) })
	-- (Contrast was 0.22: it crushed every shadow to pure black. Dark should still show the shape of the room.)
	-- Bloom: a small tight glow on flames and bulbs only. A wide one turned each lamp into a ball of fog.
	effect("BloomEffect", "NightHunterBloom", { Intensity = 0.25, Size = 10, Threshold = 1.3 })
end

-- Turns a house folder (freshly built or saved in the place) into the table the game uses.
local function wrap(root: Folder, graph)
	local markers = {}
	for _, node in graph.nodes do
		markers[node.id] = root:FindFirstChild("Belief" .. node.id)
	end

	local function ping(room: number, color: Color3)
		local p = part(root, "Ping", V(2, 2, 2), ORIGIN + HouseGraph.roomCenter(room) + V(0, 7, 0), color, Enum.Material.Neon, 0.3)
		p.Shape = Enum.PartType.Ball
		p.CanCollide = false
		p.CanQuery = false
		local tween = TweenService:Create(p, TweenInfo.new(0.8), { Size = V(10, 10, 10), Transparency = 1 })
		tween.Completed:Once(function()
			p:Destroy()
		end)
		tween:Play()
	end

	-- Where the hunter sleeps tonight (nil clears it). Visible during the day, so players can plan.
	local function setLair(room: number?)
		local old = root:FindFirstChild("Lair")
		if old then
			old:Destroy()
		end
		if room then
			HouseDecor.lair(root, ORIGIN, room)
		end
	end

	return {
		origin = ORIGIN,
		root = root,
		spawn = root:FindFirstChild("NightHunterSpawn"),
		markers = markers,
		ping = ping,
		setLair = setLair,
		segments = HouseGeometry.segments(graph),
	}
end

local function folder(parent, name)
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

-- Creates (or rebuilds) the house in Workspace. Works in Edit mode and at runtime.
-- opts.furniture = "reseed" puts the furniture back to the default layout; opts.style = "blocks" | "assets".
function HouseBuilder.build(graph, opts)
	opts = opts or {}
	local root = Workspace:FindFirstChild(HOUSE_NAME)
	if root and not (root:GetAttribute("Layout") == LAYOUT and root:FindFirstChild("Furniture")) then
		root:Destroy() -- an older house (another floor plan): start over
		root = nil
	end
	if root then
		for _, child in root:GetChildren() do
			if child.Name ~= "Furniture" then
				child:Destroy() -- the shell, markers and spawn: rebuilt below. Furniture stays.
			end
		end
	else
		root = Instance.new("Folder")
		root.Name = HOUSE_NAME
	end
	root:SetAttribute("Layout", LAYOUT)
	root:SetAttribute("Signature", HouseGraph.signature(graph))
	root:SetAttribute("ShellVersion", HouseDecor.VERSION)
	root:SetAttribute("Origin", ORIGIN) -- the HUD works out which floor/room you are in from this
	-- No applyLighting() here: building in Edit mode must not darken the editor.
	-- ensure() applies the night look when the game actually runs.

	local shell = folder(root, "Shell")
	local floors, walls, doors, stairs = folder(shell, "Floors"), folder(shell, "Walls"), folder(shell, "Doors"), folder(shell, "Stairs")

	buildSlabs(floors, graph)

	local segments = HouseGeometry.segments(graph)
	for i, seg in segments do
		buildWall(walls, doors, seg, i)
	end

	for _, s in HouseGraph.STAIRS do
		buildStairs(stairs, graph, s)
	end
	buildBowLanding(stairs)
	for _, r in RAILS do
		local hallGallery = r[5] == LEVEL and math.max(math.abs(r[1]), math.abs(r[3])) <= 44 and math.min(r[2], r[4]) >= 0
		railStyle(hallGallery, hallGallery) -- the hall's galleries: wrought iron
		balustrade(stairs, V(r[1], r[5], r[2]), V(r[3], r[5], r[4]), 4.4)
	end

	railStyle(false)
	for _, node in graph.nodes do
		local marker = part(root, "Belief" .. node.id, V(1, 1, 1), ORIGIN + node.pos + V(0, 0.6, 0), Color3.fromRGB(255, 40, 60), Enum.Material.Neon, 1)
		marker.Shape = Enum.PartType.Ball
		marker.CanCollide = false
		marker.CanQuery = false
		marker.CanTouch = false
		marker.CastShadow = false
	end

	HouseDecor.decorate(folder(shell, "Rooms"), graph, ORIGIN, segments, Furniture.wallSpans(graph))

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "NightHunterSpawn"
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Size = V(5, 0.4, 5)
	spawn.Position = ORIGIN + V(0, 0.2, 84) -- in the open front of the hall, inside the front door
	spawn.Color = Color3.fromRGB(70, 110, 160)
	spawn.Transparency = 0.6
	spawn.Parent = root

	root.Parent = Workspace
	if opts.furniture == "reseed" or not root:FindFirstChild("Furniture") then
		Furniture.seed(root, graph, ORIGIN, opts.style or ServerStorage:GetAttribute("FurnitureStyle"))
	end
	return wrap(root, graph)
end

-- Hiding spots must match the graph's hide nodes (each hide node needs exactly one tagged spot).
local function missingHideSpots(root, graph): { number }
	local have = {}
	for _, spot in game:GetService("CollectionService"):GetTagged(Furniture.HIDE_TAG) do
		if spot:IsDescendantOf(root) then
			have[spot:GetAttribute("Node")] = true
		end
	end
	local missing = {}
	for _, node in graph.nodes do
		if node.kind == "hide" and not have[node.id] then
			table.insert(missing, node.id)
		end
	end
	return missing
end

-- Runtime entry: reuse the house saved in the place, or rebuild its shell if it no longer matches.
-- The furniture in the place is never touched here: it is whatever the team left there.
function HouseBuilder.ensure(graph)
	applyLighting()
	local root = Workspace:FindFirstChild(HOUSE_NAME)
	local fresh = root
		and root:GetAttribute("Layout") == LAYOUT
		and root:FindFirstChild("Shell")
		and root:FindFirstChild("Furniture")
		and root:GetAttribute("Signature") == HouseGraph.signature(graph)
		and root:GetAttribute("ShellVersion") == HouseDecor.VERSION
	local house
	if fresh then
		house = wrap(root, graph)
	else
		if root then
			warn("[NightHunter] The house saved in this place does not match HouseGraph/HouseDecor; rebuilt the shell for this session. Rebuild it in Edit mode to update the saved copy.")
		end
		house = HouseBuilder.build(graph)
	end
	local furnitureRoot = house.root:FindFirstChild("Furniture")
	HouseKit.applyTints(furnitureRoot)
	HouseKit.relight(house.root)
	if furnitureRoot:GetAttribute("Version") ~= Furniture.VERSION then
		print(("[NightHunter] Furniture in this place is layout v%s, the code's default is v%s. Yours is kept; reseed it only if you want the new default."):format(tostring(furnitureRoot:GetAttribute("Version")), tostring(Furniture.VERSION)))
	end
	local missing = missingHideSpots(house.root, graph)
	if #missing > 0 then
		warn("[NightHunter] Hide nodes without a hiding spot in Furniture (they cannot be used): " .. table.concat(missing, ", ") .. ". Reseed the furniture, or put a hiding wardrobe/table back in that room.")
	end
	for _, other in Workspace:GetDescendants() do
		if other:IsA("SpawnLocation") and other ~= house.spawn then
			other.Enabled = false -- players must spawn inside the house
		end
	end
	return house
end

return HouseBuilder
