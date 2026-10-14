--!strict
-- The mansion as the hunter "hears" it: a graph. Room nodes are joined by doors and stairs; each
-- hiding spot (wardrobe / cloth table) is a hide node hanging off its room. Reasoning on ~40 nodes
-- instead of every stud is what keeps the AI cheap enough to run every 0.5 s.
--
-- Three floors, 17 studs apart (16 studs of room inside): FLOOR 1 (level 0), FLOOR 2 (level 1) and the
-- BASEMENT (level -1). Rooms are big rectangles in house-local studs (x east, z south, y up) so there
-- is room to run: 34 to 44 studs across, joined by wide doorways and open archways, every room with two
-- or more ways out. Floor 1 has the grand entrance hall; its two staircases rise through a hole in
-- floor 2 to the Landing (a balcony over the hall), so the hall is two floors tall.
--
--   floor 2                  floor 1                    basement
--   Nursery Gallery Master   Study  Ballroom Kitchen    Boiler Wine   Cold
--   Guest  [Landing] Bath    Library  HALL   Dining     Coal   Crypt  (nothing under Dining)
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

local LEVEL_HEIGHT = 17 -- floor to floor
local CLEAR = 16 -- floor to ceiling inside a room
local STEP_RISE = 1

local ROOM_DEFS = {
	-- floor 1 (level 0)
	{ name = "Entrance Hall", level = 0, x0 = -22, z0 = 0, x1 = 22, z1 = 56, anchor = { 0, 10 } }, -- (not the middle: the pillar stands there)
	{ name = "Library", level = 0, x0 = -56, z0 = 0, x1 = -22, z1 = 44 },
	{ name = "Dining Room", level = 0, x0 = 22, z0 = 0, x1 = 56, z1 = 44 },
	{ name = "Study", level = 0, x0 = -56, z0 = -36, x1 = -22, z1 = 0, holes = { { x0 = -56, z0 = -28, x1 = -49, z1 = -4 } } },
	{ name = "Ballroom", level = 0, x0 = -22, z0 = -36, x1 = 22, z1 = 0 },
	{ name = "Kitchen", level = 0, x0 = 22, z0 = -36, x1 = 56, z1 = 0, holes = { { x0 = 49, z0 = -28, x1 = 56, z1 = -4 } } },
	-- floor 2 (level 1)
	{ name = "Landing", level = 1, x0 = -22, z0 = 0, x1 = 22, z1 = 56, anchor = { 0, 7 }, holes = { { x0 = -22, z0 = 14, x1 = 22, z1 = 56 } } },
	{ name = "Gallery", level = 1, x0 = -22, z0 = -36, x1 = 22, z1 = 0 },
	{ name = "Guest Bedroom", level = 1, x0 = -56, z0 = 0, x1 = -22, z1 = 44 },
	{ name = "Bathroom", level = 1, x0 = 22, z0 = 0, x1 = 56, z1 = 44 },
	{ name = "Nursery", level = 1, x0 = -56, z0 = -36, x1 = -22, z1 = 0 },
	{ name = "Master Bedroom", level = 1, x0 = 22, z0 = -36, x1 = 56, z1 = 0 },
	-- basement (level -1)
	{ name = "Boiler Room", level = -1, x0 = -56, z0 = -36, x1 = -22, z1 = 0 },
	{ name = "Wine Cellar", level = -1, x0 = -22, z0 = -36, x1 = 22, z1 = 0 },
	{ name = "Cold Storage", level = -1, x0 = 22, z0 = -36, x1 = 56, z1 = 0 },
	{ name = "Crypt", level = -1, x0 = -22, z0 = 0, x1 = 22, z1 = 44 },
	{ name = "Coal Cellar", level = -1, x0 = -56, z0 = 0, x1 = -22, z1 = 44 },
}

-- Doorways between rooms of the same level: { roomA, roomB, position along the shared wall, width }
-- (x for a wall that runs along X, z for a wall that runs along Z). 8 = a door; 12 = an open archway.
local DOORS = {
	{ 1, 2, 7, 12 }, { 1, 3, 7, 12 }, { 1, 5, 0, 12 }, { 2, 4, -39, 8 }, { 3, 6, 39, 8 }, { 4, 5, -18, 8 }, { 5, 6, -18, 8 },
	{ 7, 8, 0, 12 }, { 7, 9, 7, 8 }, { 7, 10, 7, 8 }, { 8, 11, -18, 8 }, { 8, 12, -18, 8 }, { 9, 11, -39, 8 }, { 10, 12, 39, 8 },
	{ 13, 14, -18, 8 }, { 14, 15, -18, 8 }, { 14, 16, 0, 12 }, { 13, 17, -39, 8 }, { 17, 16, 22, 8 },
}

-- Staircases: the foot is in `low`, the top in `high`; width across, 1 stud rise per step.
-- (lx, lz) = where the lowest step starts, (hx, hz) = where the top step ends and the upper floor begins.
-- (cx, cz), if given, bends the flight: it is the control point of a curve from the foot to the top.
-- Both ends open onto floor (the foot toward the room, the top toward the upper room); the open sides
-- of the flight get balustrades.
local STAIRS = {
	-- the hall's two grand flights start halfway back, sweep along the side walls and curve in toward the
	-- middle to meet the balcony, leaving the front of the hall (by the door) wide open
	{ low = 1, high = 7, lx = -18, lz = 40, cx = -18.5, cz = 22, hx = -10, hz = 14, width = 7 }, -- hall, west flight
	{ low = 1, high = 7, lx = 18, lz = 40, cx = 18.5, cz = 22, hx = 10, hz = 14, width = 7 }, -- hall, east flight
	{ low = 15, high = 6, lx = 52.5, lz = -4, hx = 52.5, hz = -28, width = 7 }, -- cold storage up to the kitchen
	{ low = 13, high = 4, lx = -52.5, lz = -4, hx = -52.5, hz = -28, width = 7 }, -- boiler room up to the study
}

-- The front door of the mansion (outer wall of a room): { room, side, position along the wall }.
local ENTRANCE = { room = 1, side = "S", at = 0 }

-- Hiding spots. Wardrobes stand against wall `wall` (their doors face into the room) at `along`
-- (offset from the room's centre along that wall); tables stand at (x, z) from the centre.
-- Wardrobes come first and tables are appended, so existing node ids never move when one is added.
local HIDES = {
	{ room = 1, wall = "N", along = -12 },
	{ room = 2, wall = "W", along = 10 },
	{ room = 3, wall = "E", along = 10 },
	{ room = 4, wall = "N", along = 10 },
	{ room = 5, wall = "N", along = -14 },
	{ room = 6, wall = "N", along = -8 },
	{ room = 7, wall = "N", along = -11 },
	{ room = 8, wall = "N", along = 12 },
	{ room = 9, wall = "W", along = 10 },
	{ room = 10, wall = "E", along = 10 },
	{ room = 11, wall = "W", along = -10 },
	{ room = 12, wall = "E", along = -10 },
	{ room = 13, wall = "N", along = 10 },
	{ room = 14, wall = "N", along = -12 },
	{ room = 15, wall = "N", along = -8 },
	{ room = 16, wall = "S", along = 12 },
	{ room = 16, wall = "E", along = 10 },
	{ room = 17, wall = "W", along = 10 },
	{ room = 2, x = -6, z = 8, spot = "table" }, -- Library reading table
	{ room = 3, x = 0, z = 8, spot = "table" }, -- Dining table
	{ room = 4, x = 6, z = 6, spot = "table" }, -- Study desk
	{ room = 6, x = -6, z = 8, spot = "table" }, -- Kitchen table
	{ room = 12, x = -6, z = 8, spot = "table" }, -- Dressing table
	{ room = 15, x = -6, z = 8, spot = "table" }, -- Butcher's slab
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
HouseGraph.ROOM_SIZE = 38 -- typical distance between two neighbouring rooms (the AI's travel-time estimate)
HouseGraph.LEVEL_HEIGHT = LEVEL_HEIGHT
HouseGraph.CLEAR = CLEAR
HouseGraph.STEP_RISE = STEP_RISE
HouseGraph.SPAWN_ROOM = 1
HouseGraph.DEFAULT_LAIR = 16 -- the crypt under the hall
HouseGraph.LEVEL_NAMES = { [-1] = "BASEMENT", [0] = "FLOOR 1", [1] = "FLOOR 2" }
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
		local path = HouseGraph.stairPath(s, 6)
		local pts = {}
		for i, p in path do
			pts[i] = Vector3.new(p.X, low.floorY + (high.floorY - low.floorY) * (i - 1) / (#path - 1), p.Z)
		end
		local d0 = (path[2] - path[1]).Unit
		local d1 = (path[#path] - path[#path - 1]).Unit
		table.insert(pts, 1, pts[1] - d0 * 2.5)
		table.insert(pts, pts[#pts] + d1 * 2.5)
		table.insert(passages, { a = low.id, b = high.id, kind = "stairs", pts = pts })
	end
	return passages
end

-- The centre line of a staircase from its foot to its top as `count` + 1 evenly spaced points (y = 0):
-- a straight line, or a curve through the control point (cx, cz). Also returns the length.
function HouseGraph.stairPath(s, count: number): ({ Vector3 }, number)
	local p0 = Vector3.new(s.lx, 0, s.lz)
	local p2 = Vector3.new(s.hx, 0, s.hz)
	local p1 = if s.cx then Vector3.new(s.cx, 0, s.cz) else (p0 + p2) / 2
	local dense, lengths = {}, { 0 }
	local samples = 64
	for i = 0, samples do
		local t = i / samples
		local u = 1 - t
		dense[i + 1] = p0 * (u * u) + p1 * (2 * u * t) + p2 * (t * t)
	end
	for i = 2, #dense do
		lengths[i] = lengths[i - 1] + (dense[i] - dense[i - 1]).Magnitude
	end
	local total = lengths[#lengths]
	local out = {}
	local j = 1
	for k = 0, count do
		local target = total * k / count
		while j < #dense - 1 and lengths[j + 1] < target do
			j += 1
		end
		local span = lengths[j + 1] - lengths[j]
		out[k + 1] = dense[j]:Lerp(dense[j + 1], if span > 0 then math.clamp((target - lengths[j]) / span, 0, 1) else 0)
	end
	return out, total
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
	local parts = { ("mansion v2 rooms %d"):format(#graph.rooms) }
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
