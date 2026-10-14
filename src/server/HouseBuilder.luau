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
local LAYOUT = 4 -- house structure version: 4 = the roomy three-floor mansion (older houses are rebuilt whole)
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
	{ -15, 14, 15, 14, LEVEL }, -- the landing balcony, between the tops of the two hall staircases
	{ -49, -28, -49, -4, 0 }, -- study stairwell, east edge
	{ -56, -4, -49, -4, 0 }, -- study stairwell, south edge
	{ 49, -28, 49, -4, 0 }, -- kitchen stairwell, west edge
	{ 49, -4, 56, -4, 0 }, -- kitchen stairwell, south edge
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
			trim("Pilaster", V(1.2, height, 1.8), V(sx * (width / 2 + 0.6), height / 2, 0))
			trim("PilasterBase", V(1.6, 1, 2.2), V(sx * (width / 2 + 0.6), 0.5, 0))
			trim("PilasterCap", V(1.8, 0.6, 2.3), V(sx * (width / 2 + 0.6), height - 0.3, 0))
			-- the corners of the arch: two steps down from the header
			trim("Spandrel", V(2, 1.2, 1.6), V(sx * (width / 2 - 1), height - 0.6, 0))
			trim("Spandrel", V(1, 1, 1.6), V(sx * (width / 2 - 2.5), height - 0.5, 0))
		end
		trim("Header", V(width + 3.6, 1.2, 2), V(0, height + 0.6, 0))
		trim("Keystone", V(1.2, 1.8, 2.2), V(0, height + 0.5, 0), HouseKit.WOOD, Enum.Material.Wood)
		m.Parent = parent
		return m
	end
	for _, sx in { -1, 1 } do
		trim("Jamb", V(0.6, height, 1.5), V(sx * (width / 2 + 0.3), height / 2, 0))
	end
	trim("Header", V(width + 1.6, 0.8, 1.6), V(0, height + 0.4, 0))
	trim("Pediment", V(width + 2.4, 0.4, 1.8), V(0, height + 1, 0))

	-- The door leaf, hinged on one jamb and left open (a different angle at each doorway).
	local rng = Random.new(seed)
	local side = if rng:NextNumber() < 0.5 then -1 else 1 -- which jamb
	local swing = if rng:NextNumber() < 0.5 then -1 else 1 -- into which room
	local angle = math.rad(rng:NextNumber(62, 100)) * swing
	local leafW, leafH = width - 0.5, height - 0.3
	local hinge = wallCF * CFrame.new(side * (width / 2 - 0.2), 0, 0) * CFrame.Angles(0, angle, 0)
	local function onLeaf(name, size, offset, color, material)
		local p = part(m, name, size, Vector3.zero, color, material)
		p.CFrame = hinge * CFrame.new(-side * leafW / 2, 0, 0) * CFrame.new(offset)
		p.CanCollide = false
		return p
	end
	onLeaf("Leaf", V(leafW, leafH, 0.3), V(0, leafH / 2 + 0.05, 0), HouseKit.WOOD, Enum.Material.Wood)
	for _, sz in { -1, 1 } do
		for _, py in { leafH * 0.3, leafH * 0.72 } do
			onLeaf("Panel", V(leafW - 1.6, leafH * 0.34, 0.06), V(0, py, sz * 0.17), HouseKit.WOOD_DARK, Enum.Material.Wood)
		end
		onLeaf("Knob", V(0.3, 0.3, 0.3), V(side * (leafW / 2 - 0.6), 4.6, sz * 0.32), HouseKit.BRASS, Enum.Material.Metal)
	end
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

-- A solid balustrade between two points (house-local), `y` = the lower end's floor, tilted if the ends differ in height.
local function balustrade(parent, a: Vector3, b: Vector3, height: number)
	local mid = (a + b) / 2
	local length = (b - a).Magnitude
	local cf = if length < 0.01 then CFrame.new(ORIGIN + mid) else CFrame.lookAt(ORIGIN + mid, ORIGIN + b)
	-- an invisible panel stops anyone falling; what you see is an open row of turned posts
	local guard = part(parent, "RailGuard", V(0.4, height + 0.8, length), Vector3.zero, WALL_COLOR, Enum.Material.Wood, 1)
	guard.CFrame = cf * CFrame.new(0, (height + 0.8) / 2, 0)
	guard.CastShadow = false
	local cap = part(parent, "Handrail", V(0.8, 0.4, length), Vector3.zero, HouseKit.WOOD_DARK, Enum.Material.Wood)
	cap.CFrame = cf * CFrame.new(0, height + 0.2, 0)
	cap.CanCollide = false
	local base = part(parent, "RailBase", V(0.7, 0.4, length), Vector3.zero, HouseKit.WOOD_DARK, Enum.Material.Wood)
	base.CFrame = cf * CFrame.new(0, 0.2, 0)
	base.CanCollide = false
	local count = math.max(2, math.floor(length / 1.4))
	for i = 0, count do
		local t = -length / 2 + i * length / count
		local post = part(parent, if i == 0 or i == count then "Newel" else "Baluster", Vector3.zero, Vector3.zero, HouseKit.WOOD, Enum.Material.Wood)
		local newel = i == 0 or i == count
		post.Size = if newel then V(0.9, height + 0.9, 0.9) else V(0.32, height, 0.32)
		-- upright even on a sloping rail: place by position along the rail, then stand it straight
		local at = (cf * CFrame.new(0, 0, t)).Position
		post.CFrame = CFrame.new(at + Vector3.new(0, post.Size.Y / 2, 0))
		post.CanCollide = false
	end
end

-- One staircase: solid steps (1 stud rise each) from the foot up to the top, a carpet runner on the
-- grand ones, and a tilted balustrade along the open side.
local function buildStairs(parent, graph, s)
	local low, high = graph.rooms[s.low], graph.rooms[s.high]
	local yLow, yHigh = low.floorY, high.floorY
	local n = math.floor((yHigh - yLow) / STEP + 0.5)
	local foot, top = V(s.lx, yLow, s.lz), V(s.hx, yHigh, s.hz)
	local flat = V(top.X - foot.X, 0, top.Z - foot.Z)
	local run = flat.Magnitude
	local dir = flat.Unit
	local tread = run / n
	local grand = s.low == 1
	for i = 1, n do
		local mid = foot + dir * ((i - 0.5) * tread)
		local topY = yLow + i * STEP
		local height = topY - (yLow - 0.5)
		local cf = CFrame.lookAt(ORIGIN + V(mid.X, yLow - 0.5 + height / 2, mid.Z), ORIGIN + V(mid.X, yLow - 0.5 + height / 2, mid.Z) + dir)
		local step = part(parent, "Step", V(s.width, height, tread + 0.02), Vector3.zero, STAIR_COLOR, Enum.Material.Wood)
		step.CFrame = cf
		if grand then
			local carpet = part(parent, "Carpet", V(s.width - 2.4, 0.1, tread), Vector3.zero, CARPET_COLOR, Enum.Material.Fabric)
			carpet.CFrame = cf * CFrame.new(0, height / 2 + 0.05, 0)
			carpet.CanCollide = false
		end
	end
	-- balustrade on the side facing the room's middle (the other side is a wall)
	local inner = if low.center.X < s.lx then -1 else 1
	local x = s.lx + inner * (s.width / 2 - 0.25)
	balustrade(parent, V(x, yLow, s.lz), V(x, yHigh, s.hz), 4.4)
end

local function effect(className, name, props)
	local e = Lighting:FindFirstChild(name) or Instance.new(className)
	e.Name = name
	for k, v in props do
		e[k] = v
	end
	e.Parent = Lighting
end

-- Cold, nearly black night; a few warm lamps and candles carry the colour. The flashlight does the rest.
-- A thin dark haze swallows the far end of every big room, so you never quite see what is there.
local function applyLighting()
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
	atmosphere.Density = 0.42
	atmosphere.Offset = 0
	atmosphere.Color = Color3.fromRGB(26, 24, 30)
	atmosphere.Decay = Color3.fromRGB(10, 9, 13)
	atmosphere.Glare = 0
	atmosphere.Haze = 1.2
	atmosphere.Parent = Lighting
	Lighting.ClockTime = 0
	Lighting.Brightness = 0.06
	Lighting.Ambient = Color3.fromRGB(15, 16, 25)
	Lighting.OutdoorAmbient = Color3.fromRGB(12, 13, 22)
	Lighting.EnvironmentDiffuseScale = 0.05
	Lighting.EnvironmentSpecularScale = 0.05
	effect("ColorCorrectionEffect", "NightHunterGrade", { Saturation = -0.3, Contrast = 0.14, TintColor = Color3.fromRGB(224, 230, 255) })
	-- Bloom only on really bright things (lamps, lens); a low threshold made the whole beam glow.
	effect("BloomEffect", "NightHunterBloom", { Intensity = 0.3, Size = 18, Threshold = 1.15 })
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
	for _, r in RAILS do
		balustrade(stairs, V(r[1], r[5], r[2]), V(r[3], r[5], r[4]), 4.4)
	end

	for _, node in graph.nodes do
		local marker = part(root, "Belief" .. node.id, V(1, 1, 1), ORIGIN + node.pos + V(0, 0.6, 0), Color3.fromRGB(255, 40, 60), Enum.Material.Neon, 1)
		marker.Shape = Enum.PartType.Ball
		marker.CanCollide = false
		marker.CanQuery = false
		marker.CanTouch = false
		marker.CastShadow = false
	end

	HouseDecor.decorate(folder(shell, "Rooms"), graph, ORIGIN, segments)

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "NightHunterSpawn"
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Size = V(5, 0.4, 5)
	spawn.Position = ORIGIN + V(0, 0.2, 35) -- inside the front door, clear of the pillar
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
