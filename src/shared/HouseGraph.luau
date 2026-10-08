--!strict
-- The house as the hunter sees it: a graph. Room nodes (1..9, a 3x3 grid) are joined by
-- doors; each closet is a hide node hanging off its room. Positions are local to the
-- house origin. Reasoning on ~19 nodes instead of every stud is what keeps the AI cheap.

export type Node = { id: number, kind: string, room: number, pos: Vector3 }
export type Graph = {
	nodes: { Node },
	neighbors: { { number } },
	dist: { { number } }, -- hop distance between every pair of nodes
	roomNodes: { { number } }, -- room id -> node ids inside it (room node + its closets)
	roomCount: number,
	doors: { { number } },
}

local ROOM_SIZE = 24

-- Room ids:  1 2 3 / 4 5 6 / 7 8 9   (2-5 has no door, so the house has loops and a dead corner)
local DOORS = { { 1, 2 }, { 2, 3 }, { 1, 4 }, { 3, 6 }, { 4, 5 }, { 5, 6 }, { 5, 8 }, { 4, 7 }, { 7, 8 }, { 8, 9 }, { 6, 9 } }

local CLOSETS = {
	{ room = 1, offset = Vector3.new(-8, 0, -8) },
	{ room = 2, offset = Vector3.new(8, 0, -8) },
	{ room = 3, offset = Vector3.new(8, 0, -8) },
	{ room = 4, offset = Vector3.new(-8, 0, 8) },
	{ room = 5, offset = Vector3.new(-8, 0, -8) },
	{ room = 5, offset = Vector3.new(8, 0, 8) },
	{ room = 6, offset = Vector3.new(8, 0, 8) },
	{ room = 7, offset = Vector3.new(-8, 0, 8) },
	{ room = 8, offset = Vector3.new(8, 0, 8) },
	{ room = 9, offset = Vector3.new(8, 0, 8) },
}

local HouseGraph = {}
HouseGraph.ROOM_SIZE = ROOM_SIZE

function HouseGraph.roomCenter(room: number): Vector3
	local index = room - 1
	return Vector3.new((index % 3) * ROOM_SIZE, 0, (index // 3) * ROOM_SIZE)
end

function HouseGraph.build(): Graph
	local nodes: { Node } = {}
	local neighbors: { { number } } = {}
	local roomNodes: { { number } } = {}

	local function link(a: number, b: number)
		table.insert(neighbors[a], b)
		table.insert(neighbors[b], a)
	end

	for room = 1, 9 do
		nodes[room] = { id = room, kind = "room", room = room, pos = HouseGraph.roomCenter(room) }
		neighbors[room] = {}
		roomNodes[room] = { room }
	end
	for _, door in DOORS do
		link(door[1], door[2])
	end
	for i, closet in CLOSETS do
		local id = 9 + i
		nodes[id] = { id = id, kind = "hide", room = closet.room, pos = HouseGraph.roomCenter(closet.room) + closet.offset }
		neighbors[id] = {}
		link(id, closet.room)
		table.insert(roomNodes[closet.room], id)
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

	return { nodes = nodes, neighbors = neighbors, dist = dist, roomNodes = roomNodes, roomCount = 9, doors = DOORS }
end

-- A fingerprint of the layout. The house saved in the place stores it, so a stale house
-- (built before the graph changed) is detected and rebuilt instead of silently disagreeing.
function HouseGraph.signature(graph: Graph): string
	local parts = {}
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
	if col < 0 or col > 2 or row < 0 or row > 2 then
		return nil
	end
	return row * 3 + col + 1
end

-- Which node a position belongs to: a closet if standing inside one, otherwise the room.
function HouseGraph.nodeAt(graph: Graph, localPos: Vector3, closetRadius: number): number?
	local room = HouseGraph.roomAt(localPos)
	if not room then
		return nil
	end
	for _, id in graph.roomNodes[room] do
		local node = graph.nodes[id]
		if node.kind == "hide" then
			local dx, dz = localPos.X - node.pos.X, localPos.Z - node.pos.Z
			if dx * dx + dz * dz <= closetRadius * closetRadius then
				return id
			end
		end
	end
	return room
end

return HouseGraph
