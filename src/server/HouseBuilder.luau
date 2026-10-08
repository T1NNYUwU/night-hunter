--!nonstrict
-- Builds the playable house from the HouseGraph: floors, walls with door gaps, closets,
-- lights, a spawn pad and one belief marker per node. Spike quality: blocky but readable.
--
-- The house is saved in the place (so it shows in Edit mode). Build or rebuild it from the
-- command bar with:
--   require(game.ServerScriptService.NightHunter.HouseBuilder).build(require(game.ReplicatedStorage.NightHunter.HouseGraph).build())
-- At runtime ensure() reuses the saved house, or rebuilds it if the graph has changed since.

local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local HouseGraph = require(game:GetService("ReplicatedStorage"):WaitForChild("NightHunter"):WaitForChild("HouseGraph"))
local HouseDecor = require(script.Parent.HouseDecor)

local HOUSE_NAME = "NightHunterHouse"
local ORIGIN = Vector3.new(0, 50, 0)
local WALL_HEIGHT = 12
local DOOR_WIDTH = 6
local HALF = HouseGraph.ROOM_SIZE / 2

local WALL_COLOR = Color3.fromRGB(62, 46, 38) -- shows only as door jambs and lintels
local CLOSET_COLOR = Color3.fromRGB(110, 75, 45)

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

local function hasDoor(graph, a, b)
	for _, door in graph.doors do
		if (door[1] == a and door[2] == b) or (door[1] == b and door[2] == a) then
			return true
		end
	end
	return false
end

-- A wall along X (alongX = true) or along Z, centred at `center`, optionally with a door gap.
local function wall(parent, center: Vector3, alongX: boolean, withDoor: boolean)
	local length = HouseGraph.ROOM_SIZE
	local y = WALL_HEIGHT / 2
	if not withDoor then
		local size = if alongX then Vector3.new(length, WALL_HEIGHT, 1) else Vector3.new(1, WALL_HEIGHT, length)
		part(parent, "Wall", size, center + Vector3.new(0, y, 0), WALL_COLOR, Enum.Material.Wood)
		return
	end
	local piece = (length - DOOR_WIDTH) / 2
	local shift = DOOR_WIDTH / 2 + piece / 2
	local lintelSize = if alongX then Vector3.new(DOOR_WIDTH, 4, 1) else Vector3.new(1, 4, DOOR_WIDTH)
	part(parent, "Lintel", lintelSize, center + Vector3.new(0, WALL_HEIGHT - 2, 0), WALL_COLOR, Enum.Material.Wood)
	for _, sign in { -1, 1 } do
		local size = if alongX then Vector3.new(piece, WALL_HEIGHT, 1) else Vector3.new(1, WALL_HEIGHT, piece)
		local offset = if alongX then Vector3.new(sign * shift, y, 0) else Vector3.new(0, y, sign * shift)
		part(parent, "Wall", size, center + offset, WALL_COLOR, Enum.Material.Wood)
	end
end

local function closet(parent, pos: Vector3, room: number)
	-- Open towards the room centre along X, so players walk in from the room side.
	local toCenter = HouseGraph.roomCenter(room) - (pos - ORIGIN)
	local sx = if toCenter.X > 0 then -1 else 1 -- back wall side
	local model = Instance.new("Model")
	model.Name = "Closet"
	part(model, "Back", Vector3.new(0.4, 8, 4.4), pos + Vector3.new(sx * 2, 4, 0), CLOSET_COLOR, Enum.Material.Wood)
	part(model, "SideA", Vector3.new(4.4, 8, 0.4), pos + Vector3.new(0, 4, 2.2), CLOSET_COLOR, Enum.Material.Wood)
	part(model, "SideB", Vector3.new(4.4, 8, 0.4), pos + Vector3.new(0, 4, -2.2), CLOSET_COLOR, Enum.Material.Wood)
	part(model, "Top", Vector3.new(4.4, 0.4, 4.4), pos + Vector3.new(0, 8.2, 0), CLOSET_COLOR, Enum.Material.Wood)
	model.Parent = parent
end

local function effect(className, name, props)
	local e = Lighting:FindFirstChild(name) or Instance.new(className)
	e.Name = name
	for k, v in props do
		e[k] = v
	end
	e.Parent = Lighting
end

-- Cold, slightly desaturated night; warm lamps and candles carry the colour.
local function applyLighting()
	Lighting.ClockTime = 0
	Lighting.Brightness = 0.4
	Lighting.Ambient = Color3.fromRGB(46, 48, 64)
	Lighting.OutdoorAmbient = Color3.fromRGB(40, 44, 60)
	Lighting.EnvironmentDiffuseScale = 0.2
	Lighting.EnvironmentSpecularScale = 0.2
	effect("ColorCorrectionEffect", "NightHunterGrade", { Saturation = -0.25, Contrast = 0.12, TintColor = Color3.fromRGB(228, 232, 255) })
	effect("BloomEffect", "NightHunterBloom", { Intensity = 0.5, Size = 20, Threshold = 0.92 })
end

-- Turns a house folder (freshly built or saved in the place) into the table the game uses.
local function wrap(root: Folder, graph)
	local markers = {}
	for _, node in graph.nodes do
		markers[node.id] = root:FindFirstChild("Belief" .. node.id)
	end

	local function ping(room: number, color: Color3)
		local p = part(root, "Ping", Vector3.new(2, 2, 2), ORIGIN + HouseGraph.roomCenter(room) + Vector3.new(0, 7, 0), color, Enum.Material.Neon, 0.3)
		p.Shape = Enum.PartType.Ball
		p.CanCollide = false
		p.CanQuery = false
		local tween = TweenService:Create(p, TweenInfo.new(0.8), { Size = Vector3.new(10, 10, 10), Transparency = 1 })
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

-- Creates the house in Workspace (replacing any old one). Works in Edit mode and at runtime.
function HouseBuilder.build(graph)
	local old = Workspace:FindFirstChild(HOUSE_NAME)
	if old then
		old:Destroy()
	end
	local root = Instance.new("Folder")
	root.Name = HOUSE_NAME
	root:SetAttribute("Signature", HouseGraph.signature(graph))
	root:SetAttribute("DecorVersion", HouseDecor.VERSION)
	-- No applyLighting() here: building in Edit mode must not darken the editor.
	-- ensure() applies the night look when the game actually runs.

	for room = 1, graph.roomCount do
		local center = ORIGIN + HouseGraph.roomCenter(room)
		local theme = HouseDecor.THEMES[room]
		part(root, "Floor" .. room, Vector3.new(HouseGraph.ROOM_SIZE, 1, HouseGraph.ROOM_SIZE), center - Vector3.new(0, 0.5, 0), theme.floor, theme.floorMat)
	end

	-- Walls: one pass over every room edge; shared walls are emitted once (by the left/top room).
	for room = 1, graph.roomCount do
		local index = room - 1
		local col, row = index % 3, index // 3
		local center = ORIGIN + HouseGraph.roomCenter(room)
		wall(root, center + Vector3.new(HALF, 0, 0), false, col < 2 and hasDoor(graph, room, room + 1)) -- east
		wall(root, center + Vector3.new(0, 0, HALF), true, row < 2 and hasDoor(graph, room, room + 3)) -- south
		if col == 0 then
			wall(root, center - Vector3.new(HALF, 0, 0), false, false) -- west outer
		end
		if row == 0 then
			wall(root, center - Vector3.new(0, 0, HALF), true, false) -- north outer
		end
	end

	for _, node in graph.nodes do
		if node.kind == "hide" then
			closet(root, ORIGIN + node.pos, node.room)
		end
		local marker = part(root, "Belief" .. node.id, Vector3.new(1, 1, 1), ORIGIN + node.pos + Vector3.new(0, 0.6, 0), Color3.fromRGB(255, 40, 60), Enum.Material.Neon, 1)
		marker.Shape = Enum.PartType.Ball
		marker.CanCollide = false
		marker.CanQuery = false
		marker.CanTouch = false
		marker.CastShadow = false
	end

	HouseDecor.decorate(root, graph, ORIGIN)

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "NightHunterSpawn"
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Size = Vector3.new(5, 0.4, 5)
	spawn.Position = ORIGIN + HouseGraph.roomCenter(1) + Vector3.new(0, 0.2, 0)
	spawn.Color = Color3.fromRGB(70, 110, 160)
	spawn.Parent = root

	root.Parent = Workspace
	return wrap(root, graph)
end

-- Runtime entry: reuse the house saved in the place, or rebuild it if it no longer matches the graph.
function HouseBuilder.ensure(graph)
	applyLighting()
	local root = Workspace:FindFirstChild(HOUSE_NAME)
	local house
	local fresh = root
		and root:GetAttribute("Signature") == HouseGraph.signature(graph)
		and root:GetAttribute("DecorVersion") == HouseDecor.VERSION
	if fresh then
		house = wrap(root, graph)
	else
		if root then
			warn("[NightHunter] The house saved in this place does not match HouseGraph/HouseDecor; rebuilt it for this session. Rebuild it in Edit mode to update the saved copy.")
		end
		house = HouseBuilder.build(graph)
	end
	for _, other in Workspace:GetDescendants() do
		if other:IsA("SpawnLocation") and other ~= house.spawn then
			other.Enabled = false -- players must spawn inside the house
		end
	end
	return house
end

return HouseBuilder
