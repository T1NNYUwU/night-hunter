--!strict
-- The house as the hunter "hears" it: a graph. Room nodes (a COLS x ROWS grid, ids row-major
-- from 1) are joined by doors; each hiding wardrobe is a hide node hanging off its room.
-- Positions are local to the house origin. Reasoning on ~30 nodes instead of every stud is
-- what keeps the AI cheap enough to run every 0.5 s.

export type Node = { id: number, kind: string, room: number, pos: Vector3, wall: string? }
export type Graph = {
	nodes: { Node },
	neighbors: { { number } },
	dist: { { number } }, -- hop distance between every pair of nodes
	roomNodes: { { number } }, -- room id -> node ids inside it (room node + its hiding spots)
	roomCount: number,
	doors: { { number } },
}

local ROOM_SIZE = 24
local COLS, ROWS = 4, 4

--  1  2  3  4      Foyer (spawn) is room 1.
--  5  6  7  8      6-7 and 14-15 have no door, so the house has two loops and a few dead ends:
--  9 10 11 12      places where a careless player gets cornered.
-- 13 14 15 16
local DOORS = {
	{ 1, 2 }, { 2, 3 }, { 3, 4 }, { 5, 6 }, { 7, 8 }, { 9, 10 }, { 10, 11 }, { 11, 12 }, { 13, 14 }, { 15, 16 },
	{ 1, 5 }, { 2, 6 }, { 4, 8 }, { 6, 10 }, { 7, 11 }, { 8, 12 }, { 9, 13 }, { 10, 14 }, { 11, 15 }, { 12, 16 },
}

-- Hiding wardrobes: room, position in the room, and the wall they stand against (their
-- opening faces into the room). Kept to corners so they never block a door.
local WARDROBES = {
	{ room = 1, x = 8, z = -10, wall = "N" },
	{ room = 2, x = -8, z = -10, wall = "N" },
	{ room = 3, x = 8, z = 10, wall = "S" },
	{ room = 4, x = 10, z = 8, wall = "E" },
	{ room = 5, x = -10, z = -8, wall = "W" },
	{ room = 6, x = 8, z = -10, wall = "N" },
	{ room = 7, x = -10, z = 8, wall = "W" },
	{ room = 8, x = 10, z = -8, wall = "E" },
	{ room = 9, x = -10, z = 8, wall = "W" },
	{ room = 10, x = 8, z = 10, wall = "S" },
	{ room = 11, x = 10, z = 8, wall = "E" },
	{ room = 12, x = 10, z = -8, wall = "E" },
	{ room = 13, x = -8, z = 10, wall = "S" },
	{ room = 14, x = 8, z = 10, wall = "S" },
	{ room = 15, x = -8, z = 10, wall = "S" },
	{ room = 16, x = 10, z = -8, wall = "E" },
}

local HouseGraph = {}
HouseGraph.ROOM_SIZE = ROOM_SIZE
HouseGraph.COLS = COLS
HouseGraph.ROWS = ROWS
HouseGraph.SPAWN_ROOM = 1
HouseGraph.DEFAULT_LAIR = COLS * ROWS

function HouseGraph.roomCenter(room: number): Vector3
	local index = room - 1
	return Vector3.new((index % COLS) * ROOM_SIZE, 0, (index // COLS) * ROOM_SIZE)
end

function HouseGraph.build(): Graph
	local nodes: { Node } = {}
	local neighbors: { { number } } = {}
	local roomNodes: { { number } } = {}
	local roomCount = COLS * ROWS

	local function link(a: number, b: number)
		table.insert(neighbors[a], b)
		table.insert(neighbors[b], a)
	end

	for room = 1, roomCount do
		nodes[room] = { id = room, kind = "room", room = room, pos = HouseGraph.roomCenter(room) }
		neighbors[room] = {}
		roomNodes[room] = { room }
	end
	for _, door in DOORS do
		link(door[1], door[2])
	end
	for i, w in WARDROBES do
		local id = roomCount + i
		nodes[id] = { id = id, kind = "hide", room = w.room, pos = HouseGraph.roomCenter(w.room) + Vector3.new(w.x, 0, w.z), wall = w.wall }
		neighbors[id] = {}
		link(id, w.room)
		table.insert(roomNodes[w.room], id)
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

	return { nodes = nodes, neighbors = neighbors, dist = dist, roomNodes = roomNodes, roomCount = roomCount, doors = DOORS }
end

function HouseGraph.hasDoor(graph: Graph, a: number, b: number): boolean
	for _, door in graph.doors do
		if (door[1] == a and door[2] == b) or (door[1] == b and door[2] == a) then
			return true
		end
	end
	return false
end

-- A fingerprint of the layout. The house saved in the place stores it, so a stale house
-- (built before the graph changed) is detected and rebuilt instead of silently disagreeing.
function HouseGraph.signature(graph: Graph): string
	local parts = { ("grid %dx%d"):format(COLS, ROWS) }
	for _, door in graph.doors do
		table.insert(parts, door[1] .. "-" .. door[2])
	end
	for _, node in graph.nodes do
		table.insert(parts, ("%d:%s:%g,%g"):format(node.id, node.kind, node.pos.X, node.pos.Z))
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

function HouseGraph.roomAt(localPos: Vector3): number?
	local col = math.floor((localPos.X + ROOM_SIZE / 2) / ROOM_SIZE)
	local row = math.floor((localPos.Z + ROOM_SIZE / 2) / ROOM_SIZE)
	if col < 0 or col >= COLS or row < 0 or row >= ROWS then
		return nil
	end
	return row * COLS + col + 1
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
