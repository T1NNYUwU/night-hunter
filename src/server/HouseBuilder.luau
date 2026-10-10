--!nonstrict
-- Builds the playable house from the HouseGraph. It has THREE separate layers:
--
--   Shell      floors, walls with door gaps, door frames + doors, wallpaper, ceilings, windows and
--              ceiling lights (HouseDecor). Generated from code; rebuilt whenever the graph changes.
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
local Furniture = require(script.Parent.Furniture)

local HOUSE_NAME = "NightHunterHouse"
local LAYOUT = 2 -- house structure version: 2 = Shell + Furniture (older houses are rebuilt whole)
local ORIGIN = Vector3.new(0, 50, 0)
local WALL_HEIGHT = 12
local DOOR_WIDTH = 6
local DOOR_HEIGHT = 8
local HALF = HouseGraph.ROOM_SIZE / 2

local WALL_COLOR = Color3.fromRGB(62, 46, 38) -- shows only as door jambs and lintels
local TRIM_COLOR = Color3.fromRGB(44, 31, 24)
local V = Vector3.new

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

-- A doorway's frame (jambs + header, a little proud of the wall) and a door standing open.
-- wallCF: the wall's centre, local X along the wall, local Z through it.
local function doorway(parent, wallCF: CFrame, seed: number)
	local m = Instance.new("Model")
	m.Name = "Doorway"
	local function trim(name, size, offset)
		local p = part(m, name, size, Vector3.zero, TRIM_COLOR, Enum.Material.Wood)
		p.CFrame = wallCF * CFrame.new(offset)
		p.CanCollide = false
		return p
	end
	for _, sx in { -1, 1 } do
		trim("Jamb", V(0.5, DOOR_HEIGHT, 1.4), V(sx * (DOOR_WIDTH / 2 + 0.25), DOOR_HEIGHT / 2, 0))
	end
	trim("Header", V(DOOR_WIDTH + 1, 0.5, 1.4), V(0, DOOR_HEIGHT + 0.25, 0))

	-- The door leaf, hinged on one jamb and left open (a different angle at each doorway).
	local rng = Random.new(seed)
	local side = if rng:NextNumber() < 0.5 then -1 else 1 -- which jamb
	local swing = if rng:NextNumber() < 0.5 then -1 else 1 -- into which room
	local angle = math.rad(rng:NextNumber(62, 100)) * swing
	local leafW, leafH = DOOR_WIDTH - 0.5, DOOR_HEIGHT - 0.3
	local hinge = wallCF * CFrame.new(side * (DOOR_WIDTH / 2 - 0.2), 0, 0) * CFrame.Angles(0, angle, 0)
	local function onLeaf(name, size, offset, color, material)
		local p = part(m, name, size, Vector3.zero, color, material)
		p.CFrame = hinge * CFrame.new(-side * leafW / 2, 0, 0) * CFrame.new(offset)
		p.CanCollide = false
		return p
	end
	onLeaf("Leaf", V(leafW, leafH, 0.28), V(0, leafH / 2 + 0.05, 0), HouseKit.WOOD, Enum.Material.Wood)
	for _, sz in { -1, 1 } do
		onLeaf("Panel", V(leafW - 1.2, leafH - 1.6, 0.06), V(0, leafH / 2 + 0.05, sz * 0.16), HouseKit.WOOD_DARK, Enum.Material.Wood)
		onLeaf("Knob", V(0.28, 0.28, 0.28), V(side * (leafW / 2 - 0.5), 3.9, sz * 0.3), HouseKit.BRASS, Enum.Material.Metal)
	end
	m.Parent = parent
	return m
end

-- A wall along X (alongX = true) or along Z, centred at `center`, optionally with a door gap.
local function wall(walls, doors, center: Vector3, alongX: boolean, withDoor: boolean, seed: number)
	local length = HouseGraph.ROOM_SIZE
	local y = WALL_HEIGHT / 2
	if not withDoor then
		local size = if alongX then V(length, WALL_HEIGHT, 1) else V(1, WALL_HEIGHT, length)
		part(walls, "Wall", size, center + V(0, y, 0), WALL_COLOR, Enum.Material.Wood)
		return
	end
	local piece = (length - DOOR_WIDTH) / 2
	local shift = DOOR_WIDTH / 2 + piece / 2
	local lintelSize = if alongX then V(DOOR_WIDTH, WALL_HEIGHT - DOOR_HEIGHT, 1) else V(1, WALL_HEIGHT - DOOR_HEIGHT, DOOR_WIDTH)
	part(walls, "Lintel", lintelSize, center + V(0, WALL_HEIGHT - (WALL_HEIGHT - DOOR_HEIGHT) / 2, 0), WALL_COLOR, Enum.Material.Wood)
	for _, sign in { -1, 1 } do
		local size = if alongX then V(piece, WALL_HEIGHT, 1) else V(1, WALL_HEIGHT, piece)
		local offset = if alongX then V(sign * shift, y, 0) else V(0, y, sign * shift)
		part(walls, "Wall", size, center + offset, WALL_COLOR, Enum.Material.Wood)
	end
	local wallCF = CFrame.new(center) * (if alongX then CFrame.new() else CFrame.Angles(0, math.pi / 2, 0))
	doorway(doors, wallCF, seed)
end

local function effect(className, name, props)
	local e = Lighting:FindFirstChild(name) or Instance.new(className)
	e.Name = name
	for k, v in props do
		e[k] = v
	end
	e.Parent = Lighting
end

-- Cold, dark night; a few warm lamps and candles carry the colour. The flashlight does the rest.
local function applyLighting()
	Lighting.ClockTime = 0
	Lighting.Brightness = 0.15
	Lighting.Ambient = Color3.fromRGB(28, 30, 42)
	Lighting.OutdoorAmbient = Color3.fromRGB(24, 27, 40)
	Lighting.EnvironmentDiffuseScale = 0.1
	Lighting.EnvironmentSpecularScale = 0.1
	effect("ColorCorrectionEffect", "NightHunterGrade", { Saturation = -0.3, Contrast = 0.12, TintColor = Color3.fromRGB(224, 230, 255) })
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

	return { origin = ORIGIN, root = root, spawn = root:FindFirstChild("NightHunterSpawn"), markers = markers, ping = ping, setLair = setLair }
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
		root:Destroy() -- an older house (furniture baked into the rooms): start over
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
	-- No applyLighting() here: building in Edit mode must not darken the editor.
	-- ensure() applies the night look when the game actually runs.

	local shell = folder(root, "Shell")
	local floors, walls, doors = folder(shell, "Floors"), folder(shell, "Walls"), folder(shell, "Doors")

	for room = 1, graph.roomCount do
		local center = ORIGIN + HouseGraph.roomCenter(room)
		local theme = HouseDecor.THEMES[room]
		part(floors, "Floor" .. room, V(HouseGraph.ROOM_SIZE, 1, HouseGraph.ROOM_SIZE), center - V(0, 0.5, 0), theme.floor, theme.floorMat)
	end

	-- Walls: one pass over every room edge; shared walls are emitted once (by the left/top room).
	for room = 1, graph.roomCount do
		local index = room - 1
		local col, row = index % HouseGraph.COLS, index // HouseGraph.COLS
		local center = ORIGIN + HouseGraph.roomCenter(room)
		wall(walls, doors, center + V(HALF, 0, 0), false, col < HouseGraph.COLS - 1 and HouseGraph.hasDoor(graph, room, room + 1), room * 2) -- east
		wall(walls, doors, center + V(0, 0, HALF), true, row < HouseGraph.ROWS - 1 and HouseGraph.hasDoor(graph, room, room + HouseGraph.COLS), room * 2 + 1) -- south
		if col == 0 then
			wall(walls, doors, center - V(HALF, 0, 0), false, false, 0) -- west outer
		end
		if row == 0 then
			wall(walls, doors, center - V(0, 0, HALF), true, false, 0) -- north outer
		end
	end

	for _, node in graph.nodes do
		local marker = part(root, "Belief" .. node.id, V(1, 1, 1), ORIGIN + node.pos + V(0, 0.6, 0), Color3.fromRGB(255, 40, 60), Enum.Material.Neon, 1)
		marker.Shape = Enum.PartType.Ball
		marker.CanCollide = false
		marker.CanQuery = false
		marker.CanTouch = false
		marker.CastShadow = false
	end

	HouseDecor.decorate(folder(shell, "Rooms"), graph, ORIGIN)

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "NightHunterSpawn"
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Size = V(5, 0.4, 5)
	spawn.Position = ORIGIN + HouseGraph.roomCenter(HouseGraph.SPAWN_ROOM) + V(0, 0.2, 0)
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
