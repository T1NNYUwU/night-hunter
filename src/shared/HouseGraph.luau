--!strict
-- The mansion as the hunter "hears" it: a graph. Room nodes are joined by doors and stairs; each
-- hiding spot (wardrobe / cloth table) is a hide node hanging off its room. Reasoning on ~40 nodes
-- instead of every stud is what keeps the AI cheap enough to run every 0.5 s.
--
-- Three levels (each 15 studs apart, 14 studs of room inside): basement -1, ground floor 0,
-- upper floor 1. Rooms are rectangles in house-local studs (x east, z south, y up). Level 0 has
-- the grand entrance hall; its two staircases rise through a hole in the upper floor to the
-- Landing (a balcony over the hall), so the hall is two floors tall.
--
--   ground floor            upper floor              basement
--   Study  Living Kitchen   Nursery Gallery Master   Boiler Wine   Cold
--   Library  HALL  Dining   Guest  [Landing] Bath    Coal   Crypt  (nothing under Dining)
--
-- Positions are local to the house origin; room ids never change once a house is saved.

export type Hole = { x0: number, z0: number, x1: number, z1: number }
export type Room = {
	id: number,
	name: string,
	level: number,
	floorY: number,
	x0: number,
	z0: number,
	x1: number,
	z1: number,
	center: Vector3, -- where furniture is measured from and where the hunter stands
	holes: { Hole }, -- openings in this room's floor (stairwells, the hall void)
}
export type Passage = { a: number, b: number, kind: string, pts: { Vector3 } } -- pts walk a -> b
export type Node = { id: number, kind: string, room: number, pos: Vector3, wall: string?, spot: string? }
export type Graph = {
	nodes: { Node },
	neighbors: { { number } },
	dist: { { number } }, -- hop distance between every pair of nodes
	roomNodes: { { number } }, -- room id -> node ids inside it (room node + its hiding spots)
	roomCount: number,
	rooms: { Room },
	passages: { Passage },
}

local LEVEL_HEIGHT = 15 -- floor to floor
local CLEAR = 14 -- floor to ceiling inside a room
local STEP_RISE = 1

local ROOM_DEFS = {
	-- ground floor (level 0)
	{ name = "Entrance Hall", level = 0, x0 = -16, z0 = 0, x1 = 16, z1 = 32 },
	{ name = "Library", level = 0, x0 = -40, z0 = 0, x1 = -16, z1 = 32 },
	{ name = "Dining Room", level = 0, x0 = 16, z0 = 0, x1 = 40, z1 = 32 },
	{ name = "Study", level = 0, x0 = -40, z0 = -32, x1 = -16, z1 = 0, holes = { { x0 = -40, z0 = -26, x1 = -34, z1 = -6 } } },
	{ name = "Living Room", level = 0, x0 = -16, z0 = -32, x1 = 16, z1 = 0 },
	{ name = "Kitchen", level = 0, x0 = 16, z0 = -32, x1 = 40, z1 = 0, holes = { { x0 = 34, z0 = -26, x1 = 40, z1 = -6 } } },
	-- upper floor (level 1)
	{ name = "Landing", level = 1, x0 = -16, z0 = 0, x1 = 16, z1 = 32, anchor = { 0, 4 }, holes = { { x0 = -16, z0 = 8, x1 = 16, z1 = 32 } } },
	{ name = "Gallery", level = 1, x0 = -16, z0 = -32, x1 = 16, z1 = 0 },
	{ name = "Guest Bedroom", level = 1, x0 = -40, z0 = 0, x1 = -16, z1 = 32 },
	{ name = "Bathroom", level = 1, x0 = 16, z0 = 0, x1 = 40, z1 = 32 },
	{ name = "Nursery", level = 1, x0 = -40, z0 = -32, x1 = -16, z1 = 0 },
	{ name = "Master Bedroom", level = 1, x0 = 16, z0 = -32, x1 = 40, z1 = 0 },
	-- basement (level -1)
	{ name = "Boiler Room", level = -1, x0 = -40, z0 = -32, x1 = -16, z1 = 0 },
	{ name = "Wine Cellar", level = -1, x0 = -16, z0 = -32, x1 = 16, z1 = 0 },
	{ name = "Cold Storage", level = -1, x0 = 16, z0 = -32, x1 = 40, z1 = 0 },
	{ name = "Crypt", level = -1, x0 = -16, z0 = 0, x1 = 16, z1 = 32 },
	{ name = "Coal Cellar", level = -1, x0 = -40, z0 = 0, x1 = -16, z1 = 32 },
}

-- Doors between rooms of the same level: { roomA, roomB, position along the shared wall }
-- (x for a wall that runs along X, z for a wall that runs along Z).
local DOORS = {
	{ 1, 2, 4 }, { 1, 3, 4 }, { 1, 5, 0 }, { 2, 4, -28 }, { 3, 6, 28 }, { 4, 5, -16 }, { 5, 6, -16 },
	{ 7, 8, 0 }, { 7, 9, 4 }, { 7, 10, 4 }, { 8, 11, -16 }, { 8, 12, -16 }, { 9, 11, -28 }, { 10, 12, 28 },
	{ 13, 14, -16 }, { 14, 15, -16 }, { 14, 16, 0 }, { 13, 17, -28 }, { 17, 16, 16 },
}

-- Staircases: the foot is in `low`, the top in `high`; width across, 1 stud rise per step.
-- (lx, lz) = where the lowest step starts, (hx, hz) = where the top step ends and the upper floor begins.
-- Both ends open onto floor (the foot toward the room, the top toward the upper room); the open side
-- of the flight gets a balustrade.
local STAIRS = {
	{ low = 1, high = 7, lx = -13, lz = 28, hx = -13, hz = 8, width = 6 }, -- hall, west flight
	{ low = 1, high = 7, lx = 13, lz = 28, hx = 13, hz = 8, width = 6 }, -- hall, east flight
	{ low = 15, high = 6, lx = 37, lz = -6, hx = 37, hz = -26, width = 6 }, -- cold storage up to the kitchen
	{ low = 13, high = 4, lx = -37, lz = -6, hx = -37, hz = -26, width = 6 }, -- boiler room up to the study
}

-- The front door of the mansion (outer wall of a room): { room, side, position along the wall }.
local ENTRANCE = { room = 1, side = "S", at = 0 }

-- Hiding spots. Wardrobes stand against wall `wall` (their doors face into the room) at `along`
-- (offset from the room's centre along that wall); tables stand at (x, z) from the centre.
-- Wardrobes come first and tables are appended, so existing node ids never move when one is added.
local HIDES = {
	{ room = 1, wall = "N", along = -9 },
	{ room = 2, wall = "W", along = 8 },
	{ room = 3, wall = "E", along = 8 },
	{ room = 4, wall = "N", along = 8.5 },
	{ room = 5, wall = "N", along = -10 },
	{ room = 6, wall = "N", along = -6 },
	{ room = 7, wall = "N", along = -7 },
	{ room = 8, wall = "N", along = 8 },
	{ room = 9, wall = "W", along = 8 },
	{ room = 10, wall = "E", along = 9 },
	{ room = 11, wall = "W", along = -8 },
	{ room = 12, wall = "E", along = -8 },
	{ room = 13, wall = "N", along = 8 },
	{ room = 14, wall = "N", along = -9 },
	{ room = 15, wall = "N", along = -6 },
	{ room = 16, wall = "S", along = 8 },
	{ room = 16, wall = "E", along = 8 },
	{ room = 17, wall = "W", along = 8 },
	{ room = 2, x = -4, z = 6, spot = "table" }, -- Library reading table
	{ room = 3, x = -2, z = 6, spot = "table" }, -- Dining table
	{ room = 4, x = 4, z = 4, spot = "table" }, -- Study desk
	{ room = 6, x = -4, z = 6, spot = "table" }, -- Kitchen table
	{ room = 12, x = -4, z = 6, spot = "table" }, -- Dressing table
	{ room = 15, x = -4, z = 6, spot = "table" }, -- Butcher's slab
}

-- Where a wardrobe's centre sits against its wall (the wall's inner face is 0.5 from the room edge).
local WARDROBE_INSET = 1.85

local ROOM_LIST: { Room } = {}
for i, def in ROOM_DEFS do
	local floorY = def.level * LEVEL_HEIGHT
	local cx = if def.anchor then def.anchor[1] else (def.x0 + def.x1) / 2
	local cz = if def.anchor then def.anchor[2] else (def.z0 + def.z1) / 2
	ROOM_LIST[i] = {
		id = i,
		name = def.name,
		level = def.level,
		floorY = floorY,
		x0 = def.x0,
		z0 = def.z0,
		x1 = def.x1,
		z1 = def.z1,
		center = Vector3.new(cx, floorY, cz),
		holes = (def :: any).holes or {},
	}
end

local HouseGraph = {}
HouseGraph.ROOM_SIZE = 28 -- typical distance between two neighbouring rooms (the AI's travel-time estimate)
HouseGraph.LEVEL_HEIGHT = LEVEL_HEIGHT
HouseGraph.CLEAR = CLEAR
HouseGraph.STEP_RISE = STEP_RISE
HouseGraph.SPAWN_ROOM = 1
HouseGraph.DEFAULT_LAIR = 16 -- the crypt under the hall
HouseGraph.ROOMS = ROOM_LIST
HouseGraph.DOORS = DOORS
HouseGraph.STAIRS = STAIRS
HouseGraph.ENTRANCE = ENTRANCE
HouseGraph.HIDES = HIDES
HouseGraph.WARDROBE_INSET = WARDROBE_INSET

function HouseGraph.roomCenter(room: number): Vector3
	return ROOM_LIST[room].center
end

function HouseGraph.floorY(room: number): number
	return ROOM_LIST[room].floorY
end

-- The wall two rooms of one level share: which way it runs, where, and the span of the overlap.
function HouseGraph.sharedEdge(a: Room, b: Room): { axisX: boolean, line: number, lo: number, hi: number }?
	if a.level ~= b.level then
		return nil
	end
	local zlo, zhi = math.max(a.z0, b.z0), math.min(a.z1, b.z1)
	local xlo, xhi = math.max(a.x0, b.x0), math.min(a.x1, b.x1)
	if (a.x1 == b.x0 or b.x1 == a.x0) and zhi > zlo then
		return { axisX = false, line = if a.x1 == b.x0 then a.x1 else a.x0, lo = zlo, hi = zhi }
	elseif (a.z1 == b.z0 or b.z1 == a.z0) and xhi > xlo then
		return { axisX = true, line = if a.z1 == b.z0 then a.z1 else a.z0, lo = xlo, hi = xhi }
	end
	return nil
end

local function buildPassages(): { Passage }
	local passages: { Passage } = {}
	for _, door in DOORS do
		local a, b = ROOM_LIST[door[1]], ROOM_LIST[door[2]]
		local edge = HouseGraph.sharedEdge(a, b)
		assert(edge, ("HouseGraph: rooms %d and %d do not share a wall"):format(a.id, b.id))
		local y = a.floorY
		local point, normal
		if edge.axisX then
			point = Vector3.new(door[3], y, edge.line)
			normal = Vector3.new(0, 0, if b.center.Z > a.center.Z then 1 else -1)
		else
			point = Vector3.new(edge.line, y, door[3])
			normal = Vector3.new(if b.center.X > a.center.X then 1 else -1, 0, 0)
		end
		table.insert(passages, { a = a.id, b = b.id, kind = "door", pts = { point - normal * 2.5, point + normal * 2.5 } })
	end
	for _, s in STAIRS do
		local low, high = ROOM_LIST[s.low], ROOM_LIST[s.high]
		local foot = Vector3.new(s.lx, low.floorY, s.lz)
		local top = Vector3.new(s.hx, high.floorY, s.hz)
		local dir = Vector3.new(top.X - foot.X, 0, top.Z - foot.Z).Unit
		table.insert(passages, { a = low.id, b = high.id, kind = "stairs", pts = { foot - dir * 2.5, foot, top, top + dir * 2.5 } })
	end
	return passages
end

local PASSAGES = buildPassages()

-- Position of a hiding spot, local to the house (wardrobes flush against their wall).
local function hidePosition(h): Vector3
	local r = ROOM_LIST[h.room]
	local c = r.center
	if h.spot == "table" then
		return Vector3.new(c.X + h.x, r.floorY, c.Z + h.z)
	elseif h.wall == "W" then
		return Vector3.new(r.x0 + WARDROBE_INSET, r.floorY, c.Z + h.along)
	elseif h.wall == "E" then
		return Vector3.new(r.x1 - WARDROBE_INSET, r.floorY, c.Z + h.along)
	elseif h.wall == "N" then
		return Vector3.new(c.X + h.along, r.floorY, r.z0 + WARDROBE_INSET)
	end
	return Vector3.new(c.X + h.along, r.floorY, r.z1 - WARDROBE_INSET)
end

function HouseGraph.build(): Graph
	local nodes: { Node } = {}
	local neighbors: { { number } } = {}
	local roomNodes: { { number } } = {}
	local roomCount = #ROOM_LIST

	local function link(a: number, b: number)
		if not table.find(neighbors[a], b) then
			table.insert(neighbors[a], b)
			table.insert(neighbors[b], a)
		end
	end

	for room = 1, roomCount do
		nodes[room] = { id = room, kind = "room", room = room, pos = ROOM_LIST[room].center }
		neighbors[room] = {}
		roomNodes[room] = { room }
	end
	for _, passage in PASSAGES do
		link(passage.a, passage.b)
	end
	for i, h in HIDES do
		local id = roomCount + i
		nodes[id] = { id = id, kind = "hide", room = h.room, pos = hidePosition(h), wall = h.wall, spot = h.spot or "wardrobe" }
		neighbors[id] = {}
		link(id, h.room)
		table.insert(roomNodes[h.room], id)
	end

	local dist: { { number } } = {}
	for source = 1, #nodes do
		local d = table.create(#nodes, math.huge)
		d[source] = 0
		local queue = { source }
		local head = 1
		while head <= #queue do
			local u = queue[head]
			head += 1
			for _, v in neighbors[u] do
				if d[v] == math.huge then
					d[v] = d[u] + 1
					table.insert(queue, v)
				end
			end
		end
		dist[source] = d
	end

	return { nodes = nodes, neighbors = neighbors, dist = dist, roomNodes = roomNodes, roomCount = roomCount, rooms = ROOM_LIST, passages = PASSAGES }
end

function HouseGraph.hasDoor(graph: Graph, a: number, b: number): boolean
	return table.find(graph.neighbors[a], b) ~= nil
end

-- A fingerprint of the layout. The house saved in the place stores it, so a stale house
-- (built before the graph changed) is detected and rebuilt instead of silently disagreeing.
function HouseGraph.signature(graph: Graph): string
	local parts = { ("mansion v1 levels %d"):format(#graph.rooms) }
	for _, r in graph.rooms do
		table.insert(parts, ("%s:%d:%g,%g,%g,%g"):format(r.name, r.level, r.x0, r.z0, r.x1, r.z1))
	end
	for _, p in graph.passages do
		table.insert(parts, ("%s%d-%d"):format(p.kind, p.a, p.b))
	end
	for _, node in graph.nodes do
		table.insert(parts, ("%d:%s:%g,%g,%g"):format(node.id, node.kind, node.pos.X, node.pos.Y, node.pos.Z))
	end
	return table.concat(parts, ";")
end

-- First hop on a shortest path from `from` to `to` (ties broken by lowest id, so it is deterministic).
function HouseGraph.nextStep(graph: Graph, from: number, to: number): number
	if from == to then
		return to
	end
	local best, bestDist = from, math.huge
	for _, v in graph.neighbors[from] do
		local d = graph.dist[v][to]
		if d < bestDist or (d == bestDist and v < best) then
			best, bestDist = v, d
		end
	end
	return best
end

-- The points to walk through to get from room `from` into the neighbouring room `to` (a doorway, or up
-- or down a staircase). With several ways (the hall has two staircases) the one nearest `fromPos`.
function HouseGraph.route(graph: Graph, from: number, to: number, fromPos: Vector3?): { Vector3 }
	local best, bestD, reversed = nil, math.huge, false
	for _, p in graph.passages do
		local forward = p.a == from and p.b == to
		if forward or (p.a == to and p.b == from) then
			local first = if forward then p.pts[1] else p.pts[#p.pts]
			local d = if fromPos then (Vector3.new(first.X, 0, first.Z) - Vector3.new(fromPos.X, 0, fromPos.Z)).Magnitude else 0
			if d < bestD then
				best, bestD, reversed = p, d, not forward
			end
		end
	end
	local out = {}
	if best then
		local n = #best.pts
		for i = 1, n do
			table.insert(out, if reversed then best.pts[n + 1 - i] else best.pts[i])
		end
	end
	return out
end

-- The room containing a house-local position. `y` decides the level: the room whose floor is the
-- highest one at or below the feet (a body's centre sits ~3 studs up, so 1.5 studs of slack).
function HouseGraph.roomAt(localPos: Vector3): number?
	local best: number? = nil
	local bestY = -math.huge
	for _, r in ROOM_LIST do
		if localPos.X >= r.x0 and localPos.X < r.x1 and localPos.Z >= r.z0 and localPos.Z < r.z1
			and r.floorY <= localPos.Y + 1.5 and r.floorY > bestY then
			best, bestY = r.id, r.floorY
		end
	end
	return best
end

-- Which node a position belongs to: a hiding spot if standing in one, otherwise the room.
function HouseGraph.nodeAt(graph: Graph, localPos: Vector3, hideRadius: number): number?
	local room = HouseGraph.roomAt(localPos)
	if not room then
		return nil
	end
	for _, id in graph.roomNodes[room] do
		local node = graph.nodes[id]
		if node.kind == "hide" then
			local dx, dz = localPos.X - node.pos.X, localPos.Z - node.pos.Z
			if dx * dx + dz * dz <= hideRadius * hideRadius then
				return id
			end
		end
	end
	return room
end

return HouseGraph
