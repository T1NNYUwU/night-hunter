--!strict
-- The mansion as the hunter "hears" it: a graph. Room nodes are joined by doors and stairs; each
-- hiding spot (wardrobe / cloth table) is a hide node hanging off its room. Reasoning on ~40 nodes
-- instead of every stud is what keeps the AI cheap enough to run every 0.5 s.
--
-- Three floors, 17 studs apart (16 studs of room inside): FLOOR 1 (level 0), FLOOR 2 (level 1) and the
-- BASEMENT (level -1). The plan is a real mansion's: a grand hall at the front (64 wide, reaching 20 studs
-- out in front of the wings), a wide corridor running the whole width of the house behind it on every
-- floor, and rooms of different sizes off it. Public rooms are at the front, service rooms on the east
-- (kitchen, servants' hall, a back stair through all three floors), private rooms upstairs. Every room
-- has two ways out, so there is always a loop to run. See docs/mansion.md for the drawings.
--
--   floor 2                      floor 1                        basement
--   Nursery  Gallery  Maid's     Conserv. Ballroom Servants'    Boiler  Wine    Laundry
--   ======== upper corridor ==   ======== main corridor ======  ======= tunnel ========
--   Sitting [balcony]  Bath      Study    HALL     Kitchen      Catac.  Crypt   Cold
--   Master  [galleries] Guest    Library  HALL     Dining       Catac.  Crypt   (rock)
--                                         (porch)
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
	kind: string, -- "room", or "passage" (corridor, tunnel, balcony)
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

-- kind = "passage": a corridor, tunnel or the balcony. Somewhere you pass through, not a room the
-- hunter makes its lair in.
local ROOM_DEFS = {
	-- floor 1 (level 0)
	{ name = "Entrance Hall", level = 0, x0 = -44, z0 = 0, x1 = 44, z1 = 92, anchor = { 0, 10 } }, -- (measured from under the balcony: the pillar stands in the middle)
	{ name = "Library", level = 0, x0 = -80, z0 = 20, x1 = -44, z1 = 48, holes = { { x0 = -72, z0 = 21, x1 = -52, z1 = 29 } } },
	{ name = "Dining Room", level = 0, x0 = 44, z0 = 20, x1 = 80, z1 = 48 },
	{ name = "Study", level = 0, x0 = -80, z0 = 0, x1 = -44, z1 = 20 },
	{ name = "Ballroom", level = 0, x0 = -22, z0 = -54, x1 = 22, z1 = -16 },
	{ name = "Kitchen", level = 0, x0 = 44, z0 = 0, x1 = 80, z1 = 20 },
	{ name = "Conservatory", level = 0, x0 = -80, z0 = -54, x1 = -22, z1 = -16 },
	{ name = "Servants' Hall", level = 0, x0 = 22, z0 = -54, x1 = 80, z1 = -16, holes = { { x0 = 70, z0 = -45, x1 = 79, z1 = -25 } } },
	{ name = "Main Corridor", level = 0, x0 = -80, z0 = -16, x1 = 80, z1 = 0, kind = "passage" },
	-- floor 2 (level 1)
	{ name = "Landing", level = 1, x0 = -44, z0 = 0, x1 = 44, z1 = 92, anchor = { 0, 7 }, kind = "passage",
		-- the balcony along the back of the hall and a narrow gallery down each side; the rest is open to the hall
		holes = { { x0 = -34, z0 = 12, x1 = 34, z1 = 84 } } },
	{ name = "Upper Corridor", level = 1, x0 = -80, z0 = -16, x1 = 80, z1 = 0, kind = "passage" },
	{ name = "Nursery", level = 1, x0 = -80, z0 = 0, x1 = -44, z1 = 20 }, -- (the small room next to the lady's)
	{ name = "Lady's Bedroom", level = 1, x0 = -80, z0 = 20, x1 = -44, z1 = 48 },
	{ name = "Bathroom", level = 1, x0 = 44, z0 = 0, x1 = 80, z1 = 20 },
	{ name = "Guest Bedroom", level = 1, x0 = 44, z0 = 20, x1 = 80, z1 = 48 },
	{ name = "Master Bedroom", level = 1, x0 = -80, z0 = -54, x1 = -22, z1 = -16 }, -- (the largest room upstairs)
	{ name = "Portrait Gallery", level = 1, x0 = -22, z0 = -54, x1 = 22, z1 = -16 },
	{ name = "Maid's Room", level = 1, x0 = 22, z0 = -54, x1 = 80, z1 = -16, holes = { { x0 = 61, z0 = -45, x1 = 70, z1 = -25 } } },
	-- basement (level -1)
	{ name = "Service Tunnel", level = -1, x0 = -80, z0 = -16, x1 = 80, z1 = 0, kind = "passage" },
	{ name = "Boiler Room", level = -1, x0 = -80, z0 = -54, x1 = -22, z1 = -16 },
	{ name = "Wine Cellar", level = -1, x0 = -22, z0 = -54, x1 = 22, z1 = -16 },
	{ name = "Laundry", level = -1, x0 = 22, z0 = -54, x1 = 80, z1 = -16 },
	{ name = "Catacombs", level = -1, x0 = -80, z0 = 0, x1 = -44, z1 = 48, anchor = { -62, 38 } }, -- (south of the secret stair)
	{ name = "Crypt", level = -1, x0 = -44, z0 = 0, x1 = 44, z1 = 48 },
	{ name = "Cold Storage", level = -1, x0 = 44, z0 = 0, x1 = 80, z1 = 20 },
}

-- Doorways between rooms of the same level: { roomA, roomB, position along the shared wall, width }
-- (x for a wall that runs along X, z for a wall that runs along Z). 6-8 = a door; 12 = an open archway;
-- a fifth field "open" = a doorway of that width with a cased arch and no door leaf.
local DOORS = {
	-- floor 1: the corridor runs end to end behind the hall; the hall opens to the study, library and dining room
	{ 9, 7, -51, 6 }, { 9, 5, 0, 12 }, { 9, 8, 51, 6 }, { 5, 8, -35, 6, "open" }, -- (no way from the ballroom into the conservatory)
	{ 9, 4, -62, 6 }, { 9, 1, 0, 12 }, { 9, 6, 62, 6 }, { 4, 2, -48.5, 6, "open" }, { 6, 3, 62, 6, "open" },
	{ 1, 4, 8, 8 }, { 1, 2, 41, 6 }, { 1, 3, 41, 6 }, -- (clear of the corner: a doorway's frame needs 2 studs of wall each side)
	-- floor 2: the bedrooms open onto the side galleries of the landing as well as their own rooms
	{ 11, 16, -51, 6 }, { 11, 17, 0, 12 }, { 11, 18, 51, 6 },
	{ 11, 12, -62, 6 }, { 11, 10, 0, 12 }, { 11, 14, 62, 6 }, { 12, 13, -62, 6 }, { 14, 15, 62, 6 },
	{ 10, 12, 7, 8 }, { 10, 13, 34, 6 }, { 10, 15, 34, 6 },
	-- basement
	{ 19, 20, -51, 6 }, { 19, 21, 0, 12 }, { 19, 22, 51, 6 },
	{ 19, 23, -62, 6 }, { 19, 24, 0, 12 }, { 19, 25, 62, 6 }, { 23, 24, 30, 8 },
}

-- Staircases: the foot is in `low`, the top in `high`; width across, 1 stud rise per step.
-- (lx, lz) = where the lowest step starts, (hx, hz) = where the top step ends and the upper floor begins.
-- (cx, cz), if given, bends the flight: the control point of a curve from the foot to the top; with (c2x, c2z)
-- as well it is a two-handled curve, for a sweep that swings out and comes back.
-- arc = true: (cx, cz) is a point on the flight's centre line and the flight is a true circular arc through
-- the foot, that point and the top, with fan-shaped treads.
-- railTo (0..1): how far up the flight its balustrade runs (default all the way).
-- Both ends open onto floor (the foot toward the room, the top toward the upper room); the open sides
-- of the flight get balustrades.
local STAIRS = {
	-- the imperial stair: from the front of the hall each flight runs straight back, then sweeps a quarter circle
	-- inward, and the two meet on the bowed landing over the archway to the corridor
	{ low = 1, high = 10, lx = -27, lz = 38, cx = -21.142, cz = 23.858, arc = true, hx = -7, hz = 18, width = 12, footRun = 6, footSteps = 3, steps = 17 }, -- hall, west flight
	{ low = 1, high = 10, lx = 27, lz = 38, cx = 21.142, cz = 23.858, arc = true, hx = 7, hz = 18, width = 12, footRun = 6, footSteps = 3, steps = 17 }, -- hall, east flight
	-- the servants' back stair in the north-east corner: laundry -> servants' hall -> maid's room
	{ low = 22, high = 8, lx = 74.5, lz = -25, hx = 74.5, hz = -45, width = 9 }, -- (9 studs of floor at the foot and at the head)
	{ low = 8, high = 18, lx = 65.5, lz = -45, hx = 65.5, hz = -25, width = 9 },
	-- the secret stair behind the library's bookcases, down to the catacombs
	{ low = 23, high = 2, lx = -52, lz = 25, hx = -72, hz = 25, width = 8, railTo = 0.75 },
}

-- The front door of the mansion (outer wall of a room): { room, side, position along the wall }.
local ENTRANCE = { room = 1, side = "S", at = 0 }

-- Hiding spots. Wardrobes stand against wall `wall` (their doors face into the room) at `along`
-- (offset from the room's centre along that wall); tables stand at (x, z) from the centre.
local HIDES = {
	{ room = 1, wall = "N", along = -22 },
	{ room = 1, wall = "N", along = 22 },
	{ room = 7, wall = "W", along = 9 },
	{ room = 5, wall = "N", along = -14 },
	{ room = 4, wall = "S", along = -6 },
	{ room = 6, wall = "W", along = 5 },
	{ room = 3, wall = "S", along = 10 },
	{ room = 16, wall = "W", along = 7 },
	{ room = 17, wall = "N", along = 17 },
	{ room = 14, wall = "E", along = -4 },
	{ room = 12, wall = "S", along = 10 },
	{ room = 13, wall = "N", along = 12 },
	{ room = 10, wall = "N", along = -22 },
	{ room = 18, wall = "W", along = -10 },
	{ room = 15, wall = "N", along = -12 },
	{ room = 20, wall = "W", along = 9 },
	{ room = 21, wall = "N", along = -18 },
	{ room = 22, wall = "W", along = -12 },
	{ room = 23, wall = "S", along = 10 },
	{ room = 24, wall = "S", along = -26 },
	{ room = 24, wall = "S", along = 26 },
	{ room = 5, x = -8, z = 1, spot = "table" }, -- a draped table in the ballroom (moved from the servants' hall)
	{ room = 4, x = 3, z = 0, spot = "table" }, -- Study desk
	{ room = 2, x = 0, z = 2, spot = "table" }, -- Library reading table
	{ room = 6, x = -4, z = 1, spot = "table" }, -- Kitchen table
	{ room = 3, x = 0, z = 0, spot = "table" }, -- Dining table
	{ room = 25, x = -6, z = 1, spot = "table" }, -- Butcher's slab
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
		kind = (def :: any).kind or "room",
	}
end

local HouseGraph = {}
HouseGraph.ROOM_SIZE = 36 -- typical distance between two neighbouring rooms (the AI's travel-time estimate)
HouseGraph.LEVEL_HEIGHT = LEVEL_HEIGHT
HouseGraph.CLEAR = CLEAR
HouseGraph.STEP_RISE = STEP_RISE
HouseGraph.SPAWN_ROOM = 1
HouseGraph.DEFAULT_LAIR = 24 -- the crypt under the hall
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
-- The circle of an arc flight: centre (y 0), radius, and the angles of the foot and top (pos = centre + r * (cos a, 0, sin a)).
function HouseGraph.stairArc(s): (Vector3, number, number, number)
	local ax, az, bx, bz, cx, cz = s.lx, s.lz, s.cx, s.cz, s.hx, s.hz
	local d = 2 * (ax * (bz - cz) + bx * (cz - az) + cx * (az - bz))
	local a2, b2, c2 = ax * ax + az * az, bx * bx + bz * bz, cx * cx + cz * cz
	local ox = (a2 * (bz - cz) + b2 * (cz - az) + c2 * (az - bz)) / d
	local oz = (a2 * (cx - bx) + b2 * (ax - cx) + c2 * (bx - ax)) / d
	local radius = math.sqrt((ax - ox) ^ 2 + (az - oz) ^ 2)
	local a0 = math.atan2(az - oz, ax - ox)
	local function wrap(a)
		return (a + math.pi) % (2 * math.pi) - math.pi
	end
	local via, sweep = wrap(math.atan2(bz - oz, bx - ox) - a0), wrap(math.atan2(cz - oz, cx - ox) - a0)
	if via * sweep < 0 or math.abs(via) > math.abs(sweep) then
		sweep += if sweep > 0 then -2 * math.pi else 2 * math.pi -- the long way round, through the middle point
	end
	return Vector3.new(ox, 0, oz), radius, a0, a0 + sweep
end

-- A point on an arc flight (y 0): `t` steps up (0 = the foot, s.steps = the top), `o` studs outward from its centre line.
function HouseGraph.arcEdge(s, o: number, t: number): Vector3
	local centre, radius, a0, a1 = HouseGraph.stairArc(s)
	if t <= s.footSteps then
		local out = Vector3.new(math.cos(a0), 0, math.sin(a0))
		return centre + out * (radius + o) + Vector3.new(0, 0, s.footRun * (1 - t / s.footSteps))
	end
	local a = a0 + (a1 - a0) * (t - s.footSteps) / (s.steps - s.footSteps)
	return centre + Vector3.new(math.cos(a), 0, math.sin(a)) * (radius + o)
end

function HouseGraph.stairPath(s, count: number): ({ Vector3 }, number)
	if s.arc then
		local points = {}
		local previous, length = nil, 0
		for k = 0, count do
			local p = HouseGraph.arcEdge(s, 0, k / count * s.steps)
			points[k + 1] = p
			if previous then
				length += (p - previous).Magnitude
			end
			previous = p
		end
		return points, length
	end
	local p0 = Vector3.new(s.lx, 0, s.lz)
	local p2 = Vector3.new(s.hx, 0, s.hz)
	local p1 = if s.cx then Vector3.new(s.cx, 0, s.cz) else (p0 + p2) / 2
	local dense, lengths = {}, { 0 }
	local samples = 64
	for i = 0, samples do
		local t = i / samples
		local u = 1 - t
		if s.c2x then
			dense[i + 1] = p0 * (u * u * u) + p1 * (3 * u * u * t) + Vector3.new(s.c2x, 0, s.c2z) * (3 * u * t * t) + p2 * (t * t * t)
		else
			dense[i + 1] = p0 * (u * u) + p1 * (2 * u * t) + p2 * (t * t)
		end
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
	local parts = { ("mansion v6 rooms %d"):format(#graph.rooms) }
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

-- Does the straight walk p -> q pass over the inside of floor opening `h`? (Liang-Barsky, on the ground plane)
local function crossesHole(h, p: Vector3, q: Vector3): boolean
	local t0, t1 = 0, 1
	local dx, dz = q.X - p.X, q.Z - p.Z
	for _, c in { { -dx, p.X - h.x0 }, { dx, h.x1 - p.X }, { -dz, p.Z - h.z0 }, { dz, h.z1 - p.Z } } do
		if c[1] == 0 then
			if c[2] <= 0 then
				return false
			end
		elseif c[1] < 0 then
			t0 = math.max(t0, c[2] / c[1])
		else
			t1 = math.min(t1, c[2] / c[1])
		end
	end
	return t1 - t0 > 1e-3
end

local HOLE_MARGIN = 2.5 -- how far from an opening's edge a walker keeps

-- `p` moved off the room's floor openings: a point over the hall void becomes the nearest point of the gallery.
function HouseGraph.offHole(room: number, p: Vector3): Vector3
	for _, h in ROOM_LIST[room].holes do
		if p.X > h.x0 and p.X < h.x1 and p.Z > h.z0 and p.Z < h.z1 then
			local best, bestD = p, math.huge
			for _, c in {
				{ p.X - h.x0, Vector3.new(h.x0 - HOLE_MARGIN, p.Y, p.Z) }, { h.x1 - p.X, Vector3.new(h.x1 + HOLE_MARGIN, p.Y, p.Z) },
				{ p.Z - h.z0, Vector3.new(p.X, p.Y, h.z0 - HOLE_MARGIN) }, { h.z1 - p.Z, Vector3.new(p.X, p.Y, h.z1 + HOLE_MARGIN) },
			} do
				if c[1] < bestD then
					best, bestD = c[2], c[1]
				end
			end
			return best
		end
	end
	return p
end

-- The corners to walk round so that going from `a` to `b` inside `room` never crosses an opening in its floor
-- (the landing is a gallery round the hall void). Empty when the straight line is clear. If `b` itself lies over
-- the opening (a stair head on the bow landing), the list ends at the gallery edge nearest to it.
-- ponytail: handles the first blocking opening only; rooms have one each. Chain them if a room ever gets two.
function HouseGraph.detour(room: number, a: Vector3, b: Vector3): { Vector3 }
	local r = ROOM_LIST[room]
	local from, to = HouseGraph.offHole(room, a), HouseGraph.offHole(room, b)
	local out = {}
	local lead = if from ~= a then { from } else {} -- (standing over the opening, on a stair head: step off it first)
	for _, h in r.holes do
		if crossesHole(h, from, to) then
			local function corner(x, z)
				return Vector3.new(math.clamp(x, r.x0 + 1, r.x1 - 1), a.Y, math.clamp(z, r.z0 + 1, r.z1 - 1))
			end
			local m = HOLE_MARGIN
			local c = { corner(h.x0 - m, h.z0 - m), corner(h.x1 + m, h.z0 - m), corner(h.x1 + m, h.z1 + m), corner(h.x0 - m, h.z1 + m) }
			local bestLen = math.huge
			for i = 1, 4 do
				if not crossesHole(h, from, c[i]) then
					for dir = -1, 1, 2 do
						local path, len, j = { c[i] }, (c[i] - from).Magnitude, i
						for _ = 1, 4 do
							if not crossesHole(h, c[j], to) then
								len += (to - c[j]).Magnitude
								if len < bestLen then
									bestLen, out = len, table.clone(path)
								end
								break
							end
							local k = (j - 1 + dir) % 4 + 1
							len += (c[k] - c[j]).Magnitude
							j = k
							table.insert(path, c[j])
						end
					end
				end
			end
			break
		end
	end
	table.move(out, 1, #out, #lead + 1, lead)
	if to ~= b then
		table.insert(lead, to)
	end
	return lead
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
