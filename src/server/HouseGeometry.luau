--!nonstrict
-- Pure geometry of the mansion's shell, derived from HouseGraph's room rectangles: which wall
-- segments exist (one per stretch of wall between two rooms, or between a room and the outside),
-- where the doors are, and how a floor slab is cut around a stairwell. HouseBuilder builds the parts,
-- HouseDecor finishes the faces, NightCycle uses the free wall spans for fuse boxes.
--
-- A segment is { axisX, line, lo, hi, level, floorY, a, b, aDir, doorAt, entrance }:
--   axisX   true: the wall runs along X (its position is a z `line`); false: along Z (an x `line`)
--   lo, hi  extent along the wall;   a = room that owns it, b = room on the other side (nil = outside)
--   aDir    which side of the line room `a` is on (-1 = lower coordinate, +1 = higher)
--   doorAt  position of a doorway along the wall (nil = solid), doorWidth its width (12+ = archway);
--   entrance = it is the front door

local HouseGraph = require(game:GetService("ReplicatedStorage"):WaitForChild("NightHunter"):WaitForChild("HouseGraph"))

local Geometry = {}
Geometry.WALL_THICK = 1
Geometry.DOOR_WIDTH = 8
Geometry.DOOR_HEIGHT = 11
Geometry.ARCH_HEIGHT = 12.5 -- wide doorways (12+) are open archways without a door leaf
Geometry.ENTRANCE_WIDTH = 10
Geometry.ENTRANCE_HEIGHT = 13

local function doorPosition(a: number, b: number): (number?, number?)
	for _, d in HouseGraph.DOORS do
		if (d[1] == a and d[2] == b) or (d[1] == b and d[2] == a) then
			return d[3], d[4]
		end
	end
	return nil, nil
end

-- Walls are built once: the E and S sides of each room emit the shared walls (and outer ones), the
-- W and N sides only emit the stretches that face the outside.
function Geometry.segments(graph)
	local rooms = graph.rooms
	local out = {}
	for _, room in rooms do
		for _, side in { "E", "S", "W", "N" } do
			local axisX = side == "N" or side == "S"
			local line = if side == "E" then room.x1 elseif side == "W" then room.x0 elseif side == "S" then room.z1 else room.z0
			local lo, hi = if axisX then room.x0 else room.z0, if axisX then room.x1 else room.z1
			local positive = side == "E" or side == "S"

			local covers = {}
			for _, other in rooms do
				if other ~= room and other.level == room.level then
					local touches, olo, ohi
					if side == "E" then
						touches, olo, ohi = other.x0 == room.x1, other.z0, other.z1
					elseif side == "W" then
						touches, olo, ohi = other.x1 == room.x0, other.z0, other.z1
					elseif side == "S" then
						touches, olo, ohi = other.z0 == room.z1, other.x0, other.x1
					else
						touches, olo, ohi = other.z1 == room.z0, other.x0, other.x1
					end
					if touches then
						local from, to = math.max(lo, olo), math.min(hi, ohi)
						if to > from then
							table.insert(covers, { from = from, to = to, room = other })
						end
					end
				end
			end
			table.sort(covers, function(p, q)
				return p.from < q.from
			end)

			local function emit(from, to, other)
				if other and not positive then
					return -- the neighbour emits this one
				end
				local seg = {
					axisX = axisX,
					line = line,
					lo = from,
					hi = to,
					level = room.level,
					floorY = room.floorY,
					a = room.id,
					b = other and other.id or nil,
					aDir = if positive then -1 else 1,
					side = side,
				}
				if other then
					seg.doorAt, seg.doorWidth = doorPosition(room.id, other.id)
					if seg.doorAt and (seg.doorAt < from or seg.doorAt > to) then
						seg.doorAt = nil
					end
				elseif HouseGraph.ENTRANCE.room == room.id and HouseGraph.ENTRANCE.side == side then
					seg.doorAt = HouseGraph.ENTRANCE.at
					seg.entrance = true
				end
				table.insert(out, seg)
			end

			local cursor = lo
			for _, c in covers do
				if c.from > cursor then
					emit(cursor, c.from, nil)
				end
				emit(c.from, c.to, c.room)
				cursor = c.to
			end
			if cursor < hi then
				emit(cursor, hi, nil)
			end
		end
	end
	return out
end

-- Which way the wall segment faces from inside `room` (+1 / -1 along the axis across the wall).
function Geometry.faceDir(seg, room: number): number
	return if seg.a == room then seg.aDir else -seg.aDir
end

function Geometry.doorSize(seg): (number, number)
	if seg.entrance then
		return Geometry.ENTRANCE_WIDTH, Geometry.ENTRANCE_HEIGHT
	end
	local width = seg.doorWidth or Geometry.DOOR_WIDTH
	return width, if Geometry.isArch(seg) then Geometry.ARCH_HEIGHT else Geometry.DOOR_HEIGHT
end

function Geometry.isArch(seg): boolean
	return not seg.entrance and (seg.doorWidth or 0) >= 12
end

-- A rectangle with a rectangular hole cut out of it -> up to four rectangles { x0, z0, x1, z1 }.
function Geometry.subtract(rect, hole)
	local h = {
		x0 = math.clamp(hole.x0, rect.x0, rect.x1),
		x1 = math.clamp(hole.x1, rect.x0, rect.x1),
		z0 = math.clamp(hole.z0, rect.z0, rect.z1),
		z1 = math.clamp(hole.z1, rect.z0, rect.z1),
	}
	local pieces = {
		{ x0 = rect.x0, z0 = rect.z0, x1 = h.x0, z1 = rect.z1 },
		{ x0 = h.x1, z0 = rect.z0, x1 = rect.x1, z1 = rect.z1 },
		{ x0 = h.x0, z0 = rect.z0, x1 = h.x1, z1 = h.z0 },
		{ x0 = h.x0, z0 = h.z1, x1 = h.x1, z1 = rect.z1 },
	}
	local out = {}
	for _, p in pieces do
		if p.x1 - p.x0 > 0.01 and p.z1 - p.z0 > 0.01 then
			table.insert(out, p)
		end
	end
	return out
end

-- The floor of a room as rectangles (its footprint minus its holes).
function Geometry.floorPieces(room)
	local pieces = { { x0 = room.x0, z0 = room.z0, x1 = room.x1, z1 = room.z1 } }
	for _, hole in room.holes do
		local next = {}
		for _, p in pieces do
			for _, q in Geometry.subtract(p, hole) do
				table.insert(next, q)
			end
		end
		pieces = next
	end
	return pieces
end

-- Is there a room on the level above whose footprint overlaps this one? (Then its floor is our ceiling.)
function Geometry.hasRoomAbove(graph, room): boolean
	for _, other in graph.rooms do
		if other.level == room.level + 1 and other.x0 < room.x1 and other.x1 > room.x0 and other.z0 < room.z1 and other.z1 > room.z0 then
			return true
		end
	end
	return false
end

-- Stretches of wall in `room` with no doorway and no front door: { pos (house-local, at the floor),
-- normal (into the room), lo, hi, axisX, line }. Fuse boxes go on these.
function Geometry.freeWalls(segments, room: number)
	local out = {}
	for _, seg in segments do
		if (seg.a == room or seg.b == room) and not seg.doorAt and seg.hi - seg.lo >= 10 then
			local dir = Geometry.faceDir(seg, room)
			table.insert(out, {
				axisX = seg.axisX,
				line = seg.line,
				lo = seg.lo,
				hi = seg.hi,
				floorY = seg.floorY,
				normal = if seg.axisX then Vector3.new(0, 0, dir) else Vector3.new(dir, 0, 0),
				outer = seg.b == nil,
			})
		end
	end
	return out
end

return Geometry
