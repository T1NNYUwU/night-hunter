--!nonstrict
-- The mansion SHELL's finish: everything that makes a bare box of walls look like an old, haunted
-- house. One Model per room inside the house's "Shell" folder:
--   walls     damask wallpaper (Victorian textures) over dark panelled wainscot, chair rail, crown
--             moulding; stone rooms get masonry with pilasters
--   decay     torn wallpaper, water stains running down from the ceiling, claw scratches, bloody
--             hand smears (placed by a fixed seed per wall, so every rebuild looks the same)
--   windows   tall windows with tattered curtains, some boarded up, a cold moonbeam in each room
--   ceiling   dark beams; a pendant lamp or chandelier; candle sconces that flicker; cobwebs
--   air       drifting dust that only shows where light falls on it (your flashlight beam)
--   hall      the front door, the stone pillar with its altar, words scrawled on the wall
--
-- Furniture is NOT here: it lives in Workspace.NightHunterHouse.Furniture (see Furniture.luau), one
-- independent Model per piece, so it can be moved or swapped in Studio and survives a rebuild of the
-- shell. Walls, floors, ceilings, stairs and doors are built by HouseBuilder from HouseGeometry.
--
-- Coordinates in here are house-local studs (add `origin` for the world).

local CollectionService = game:GetService("CollectionService")

local HouseGraph = require(game:GetService("ReplicatedStorage"):WaitForChild("NightHunter"):WaitForChild("HouseGraph"))
local HouseKit = require(script.Parent.HouseKit)
local Geometry = require(script.Parent.HouseGeometry)

local box, light = HouseKit.box, HouseKit.light
local WOOD_DARK, WOOD, WOOD_LIGHT = HouseKit.WOOD_DARK, HouseKit.WOOD, HouseKit.WOOD_LIGHT
local DIRTY_WHITE, WARM_LIGHT, MOON_LIGHT = HouseKit.DIRTY_WHITE, HouseKit.WARM_LIGHT, HouseKit.MOON_LIGHT
local V = Vector3.new
local CLEAR = HouseGraph.CLEAR
local LEVEL = HouseGraph.LEVEL_HEIGHT

local HouseDecor = {}
HouseDecor.VERSION = 45 -- bump when the shell finish changes, so a saved shell gets rebuilt

-- Pillar and altar: where the last night's relics go. Local to the house, at the hall's floor.
HouseDecor.PILLAR_POS = V(0, 0, 46)
HouseDecor.ALTAR_POS = V(0, 1, 53.6) -- (on its dais)
HouseDecor.SOCKETS = 4

-- Victorian damask wallpapers (textures from ValyziaFortens' "No-Blox Revolution" set, see docs/assets.md).
local PAPER = {
	blue = "rbxassetid://4871615427",
	pink = "rbxassetid://4871616234",
	green = "rbxassetid://4871637380",
	maroon = "rbxassetid://4871614772",
	grey = "rbxassetid://4871614264",
	floral = "rbxassetid://4871613662",
}

-- Room themes, by room id. Paper rooms: `paper` texture tinted by `tint` (darker = older). `stone` rooms
-- have masonry (`wallMat`) and pilasters instead.
local SAND = Enum.Material.Sandstone
HouseDecor.THEMES = {
	[1] = { name = "Entrance Hall", paper = PAPER.green, tint = Color3.fromRGB(70, 84, 74), wainscot = 8.5, floor = Color3.fromRGB(148, 138, 122), floorMat = Enum.Material.Marble },
	[2] = { name = "Library", paper = PAPER.green, tint = Color3.fromRGB(120, 130, 118), floor = WOOD, floorMat = Enum.Material.WoodPlanks },
	[3] = { name = "Dining Room", paper = PAPER.maroon, tint = Color3.fromRGB(150, 128, 128), floor = WOOD, floorMat = Enum.Material.WoodPlanks },
	[4] = { name = "Study", paper = PAPER.grey, tint = Color3.fromRGB(120, 108, 96), floor = WOOD, floorMat = Enum.Material.WoodPlanks },
	[5] = { name = "Ballroom", paper = PAPER.floral, tint = Color3.fromRGB(130, 112, 96), floor = Color3.fromRGB(58, 38, 30), floorMat = Enum.Material.WoodPlanks },
	[6] = { name = "Kitchen", stone = true, wall = Color3.fromRGB(150, 146, 128), wallMat = Enum.Material.CeramicTiles, floor = Color3.fromRGB(110, 108, 100), floorMat = Enum.Material.Slate },
	[7] = { name = "Conservatory", stone = true, wall = Color3.fromRGB(70, 84, 78), wallMat = Enum.Material.Glass, floor = Color3.fromRGB(96, 96, 92), floorMat = Enum.Material.Marble },
	[8] = { name = "Servants' Hall", paper = PAPER.grey, tint = Color3.fromRGB(124, 116, 100), floor = WOOD, floorMat = Enum.Material.WoodPlanks },
	[9] = { name = "Main Corridor", paper = PAPER.maroon, tint = Color3.fromRGB(120, 100, 100), floor = WOOD_DARK, floorMat = Enum.Material.WoodPlanks },
	[10] = { name = "Landing", paper = PAPER.green, tint = Color3.fromRGB(70, 84, 74), wainscot = 6, floor = Color3.fromRGB(58, 30, 26), floorMat = Enum.Material.WoodPlanks },
	[11] = { name = "Upper Corridor", paper = PAPER.grey, tint = Color3.fromRGB(110, 106, 110), floor = WOOD_DARK, floorMat = Enum.Material.WoodPlanks },
	[12] = { name = "Nursery", paper = PAPER.pink, tint = Color3.fromRGB(150, 128, 130), floor = WOOD_LIGHT, floorMat = Enum.Material.WoodPlanks },
	[13] = { name = "Lady's Bedroom", paper = PAPER.floral, tint = Color3.fromRGB(128, 110, 100), floor = WOOD, floorMat = Enum.Material.WoodPlanks },
	[14] = { name = "Bathroom", stone = true, wall = Color3.fromRGB(112, 132, 124), wallMat = Enum.Material.CeramicTiles, floor = Color3.fromRGB(150, 152, 148), floorMat = Enum.Material.Marble },
	[15] = { name = "Guest Bedroom", paper = PAPER.green, tint = Color3.fromRGB(112, 120, 116), floor = WOOD_LIGHT, floorMat = Enum.Material.WoodPlanks },
	[16] = { name = "Master Bedroom", paper = PAPER.blue, tint = Color3.fromRGB(104, 110, 132), floor = WOOD, floorMat = Enum.Material.WoodPlanks },
	[17] = { name = "Portrait Gallery", paper = PAPER.maroon, tint = Color3.fromRGB(120, 100, 104), floor = WOOD_DARK, floorMat = Enum.Material.WoodPlanks },
	[18] = { name = "Maid's Room", paper = PAPER.grey, tint = Color3.fromRGB(116, 112, 104), floor = WOOD_LIGHT, floorMat = Enum.Material.WoodPlanks },
	[19] = { name = "Service Tunnel", stone = true, wall = Color3.fromRGB(74, 58, 50), wallMat = Enum.Material.Brick, floor = Color3.fromRGB(60, 58, 56), floorMat = Enum.Material.Concrete },
	[20] = { name = "Boiler Room", stone = true, wall = Color3.fromRGB(70, 66, 64), wallMat = Enum.Material.Concrete, floor = Color3.fromRGB(62, 60, 58), floorMat = Enum.Material.Concrete },
	[21] = { name = "Wine Cellar", stone = true, wall = Color3.fromRGB(88, 62, 52), wallMat = Enum.Material.Brick, floor = Color3.fromRGB(70, 66, 62), floorMat = Enum.Material.Cobblestone },
	[22] = { name = "Laundry", stone = true, wall = Color3.fromRGB(96, 100, 104), wallMat = Enum.Material.Plaster, floor = Color3.fromRGB(78, 80, 82), floorMat = Enum.Material.Slate },
	[23] = { name = "Catacombs", stone = true, wall = Color3.fromRGB(58, 54, 50), wallMat = Enum.Material.Cobblestone, floor = Color3.fromRGB(48, 46, 44), floorMat = Enum.Material.Basalt },
	[24] = { name = "Crypt", stone = true, wall = Color3.fromRGB(64, 64, 68), wallMat = Enum.Material.Cobblestone, floor = Color3.fromRGB(56, 56, 60), floorMat = Enum.Material.Slate },
	[25] = { name = "Cold Storage", stone = true, wall = Color3.fromRGB(78, 88, 92), wallMat = Enum.Material.Slate, floor = Color3.fromRGB(70, 78, 82), floorMat = Enum.Material.Slate },
}

-- docs/theme.md: every room in the same aged, dark, desaturated palette as the hall.
do
	local function age(c: Color3, darken: number): Color3
		local h, sat, v = c:ToHSV()
		return Color3.fromHSV(h, sat * 0.7, v * darken)
	end
	for id, theme in HouseDecor.THEMES do
		if id ~= 1 and id ~= 10 then
			if theme.tint then
				theme.tint = age(theme.tint, 0.72)
			end
			if theme.wall then
				theme.wall = age(theme.wall, 0.78)
			end
			if theme.floor then
				theme.floor = age(theme.floor, 0.8)
			end
		end
	end
end

-- Rooms whose ceiling light still works. Everywhere else the bulb is dead: candles, moonlight and your
-- flashlight are all there is, and the dark between them is where the fear lives.
local LIT_ROOMS = setmetatable({}, { __index = function() return true end }) -- (every lamp works: the gloom comes from their low brightness and the cold grade)
-- Lights that flicker (picked by hand so the house has a rhythm, not noise).
local FLICKER_ROOMS = { [6] = true, [11] = true, [17] = true, [19] = true, [20] = true, [22] = true }
-- Rooms lit by a chandelier instead of a pendant lamp.
local CHANDELIER_ROOMS = { [10] = true, [3] = true, [5] = true, [16] = true }
-- Windows that are boarded up (by room): the rest have curtains.
local BOARDED = { [4] = true, [6] = true, [12] = true, [18] = true }

local PLASTER = Color3.fromRGB(84, 76, 66)
local GRIME = Color3.fromRGB(26, 20, 16)
local BLOOD = Color3.fromRGB(70, 8, 8)
local CURTAIN = Color3.fromRGB(70, 18, 24)

-- The NormalId of a part's face that points in direction `dir` (+1/-1) across a wall.
local function faceId(axisX: boolean, dir: number): Enum.NormalId
	if axisX then
		return if dir > 0 then Enum.NormalId.Back else Enum.NormalId.Front
	end
	return if dir > 0 then Enum.NormalId.Right else Enum.NormalId.Left
end

---------------------------------------------------------------- walls

-- One face of a wall segment, seen from inside `room`: wallpaper or masonry, panelling, mouldings, and
-- a few marks of what happened here.
local function finishFace(m, origin, seg, room, theme)
	local dir = Geometry.faceDir(seg, room.id)
	local face = seg.line + dir * 0.5
	local y0 = seg.floorY
	local rng = Random.new(room.id * 1000 + math.floor(seg.lo * 7 + seg.line * 13))

	-- A box flat against the wall: from..to along it, yBottom..yTop up, `depth` out from the face.
	local function strip(name, from, to, yBottom, yTop, depth, color, material, out)
		local len, h = to - from, yTop - yBottom
		if len <= 0.05 or h <= 0.05 then
			return nil
		end
		local mid, offset = (from + to) / 2, face + dir * ((out or 0) + depth / 2)
		local size = if seg.axisX then V(len, h, depth) else V(depth, h, len)
		local pos = if seg.axisX then V(mid, yBottom + h / 2, offset) else V(offset, yBottom + h / 2, mid)
		return box(m, name, size, CFrame.new(origin + pos), color, material, false)
	end
	local function paperSpan(from, to, yFrom)
		local top = y0 + CLEAR
		local wain = theme.wainscot or 4 -- height of the wooden panelling
		local paper = strip("Wallpaper", from, to, math.max(y0 + wain, yFrom), top - 0.9, 0.1, theme.tint, Enum.Material.SmoothPlastic)
		if paper then
			local tex = Instance.new("Texture")
			tex.Texture = theme.paper
			tex.Face = faceId(seg.axisX, dir)
			tex.StudsPerTileU = 6
			tex.StudsPerTileV = 6
			tex.Color3 = theme.tint:Lerp(Color3.new(1, 1, 1), 0.3) -- (the pattern a step lighter than the room's tone, or it drowns)
			tex.Parent = paper
		end
		strip("Cornice", from, to, top - 0.9, top, 0.35, WOOD_DARK, Enum.Material.Wood)
		strip("CorniceStep", from, to, top - 1.25, top - 0.9, 0.2, WOOD, Enum.Material.Wood)
		if yFrom > y0 + wain then
			return
		end
		strip("Wainscot", from, to, y0, y0 + wain, 0.25, WOOD_DARK, Enum.Material.Wood)
		strip("ChairRail", from, to, y0 + wain, y0 + wain + 0.35, 0.45, WOOD, Enum.Material.Wood)
		strip("Skirting", from, to, y0, y0 + 0.7, 0.4, Color3.fromRGB(34, 24, 18), Enum.Material.Wood)
		-- raised panels between stiles (two tiers on tall panelling)
		local bays = math.max(1, math.floor((to - from) / 3.6))
		local bay = (to - from) / bays
		local tiers = if wain > 5 then { { 1.1, wain * 0.42 }, { wain * 0.42 + 0.6, wain - 0.6 } } else { { 1.1, 3.5 } }
		for i = 0, bays - 1 do
			local a = from + i * bay
			for _, tier in tiers do
				strip("Panel", a + 0.45, a + bay - 0.45, y0 + tier[1], y0 + tier[2], 0.1, Color3.fromRGB(48, 32, 24), Enum.Material.Wood, 0.25)
			end
		end
	end

	local function stoneSpan(from, to, yFrom)
		strip("Masonry", from, to, math.max(y0, yFrom), y0 + CLEAR, 0.1, theme.wall, theme.wallMat)
		if yFrom > y0 then
			return
		end
		strip("Plinth", from, to, y0, y0 + 0.8, 0.35, theme.wall:Lerp(Color3.new(0, 0, 0), 0.35), theme.wallMat)
		if theme.wallMat == Enum.Material.CeramicTiles then
			strip("TileDado", from, to, y0 + 0.8, y0 + 4.4, 0.16, theme.wall:Lerp(Color3.new(0, 0, 0), 0.4), theme.wallMat)
			strip("TileBand", from, to, y0 + 4.4, y0 + 4.9, 0.24, Color3.fromRGB(24, 26, 26), theme.wallMat)
			strip("TileBand", from, to, y0 + CLEAR - 1.2, y0 + CLEAR - 0.8, 0.2, Color3.fromRGB(24, 26, 26), theme.wallMat)
		end
		-- pilasters every ~10 studs (not at the very ends, where the corners are)
		local count = if room.level < 0 then math.floor((to - from) / 10) else 0 -- (above ground the windows stand there)
		for i = 1, count do
			local at = from + i * (to - from) / (count + 1)
			strip("Pilaster", at - 0.8, at + 0.8, y0, y0 + CLEAR, 0.55, theme.wall:Lerp(Color3.new(0, 0, 0), 0.15), theme.wallMat)
			strip("PilasterCap", at - 1.1, at + 1.1, y0 + CLEAR - 1, y0 + CLEAR, 0.75, theme.wall:Lerp(Color3.new(0, 0, 0), 0.25), theme.wallMat)
		end
	end

	local function span(from, to, yFrom)
		if theme.stone then
			stoneSpan(from, to, yFrom)
		else
			paperSpan(from, to, yFrom)
		end
	end

	if seg.doorAt then
		local w, h = Geometry.doorSize(seg)
		span(seg.lo, seg.doorAt - w / 2 - 1, y0) -- (the door frame stands in the last stud)
		span(seg.doorAt + w / 2 + 1, seg.hi, y0)
		span(seg.doorAt - w / 2 - 1, seg.doorAt + w / 2 + 1, y0 + h + 1.4) -- above the doorway
	else
		span(seg.lo, seg.hi, y0)
	end
end

-- Tall windows on an outer wall (one per ~14 studs): frame, panes, sill, and tattered curtains, or
-- planks nailed across. The first window of a room lets in a faint cold moonbeam.
local WINDOW_HALF = 5.2 -- half the width of a window with its curtains and valance

-- The parts of [lo, hi] not covered by `taken` ({ from, to } pairs).
local function freeSpans(lo: number, hi: number, taken)
	table.sort(taken, function(a, b)
		return a[1] < b[1]
	end)
	local out, cursor = {}, lo
	for _, t in taken do
		if t[1] > cursor then
			table.insert(out, { cursor, math.min(t[1], hi) })
		end
		cursor = math.max(cursor, t[2])
	end
	if cursor < hi then
		table.insert(out, { cursor, hi })
	end
	return out
end

local function windowsOn(parent, origin, seg, room, theme, withMoon: boolean, taken)
	local dir = Geometry.faceDir(seg, room.id)
	local big = room.id == 10 -- the landing's great window over the front door
	local look = V(if seg.axisX then 0 else dir, 0, if seg.axisX then dir else 0)
	local rng = Random.new(room.id * 77 + math.floor(seg.lo))
	local places = {}
	if big then
		places[1] = (seg.lo + seg.hi) / 2
	else
		for _, span in freeSpans(seg.lo + 0.6, seg.hi - 0.6, taken) do
			local len = span[2] - span[1]
			if len >= WINDOW_HALF * 2 then
				local n = math.max(1, math.floor(len / 14))
				for i = 1, n do
					table.insert(places, span[1] + i * len / (n + 1))
				end
			end
		end
	end
	for i, along in places do
		local m = Instance.new("Model")
		m.Name = "Window"
		m.Parent = parent
		local w, h = if big then 9 else 5, if big then 9.5 else 8
		local y = seg.floorY + 5.1 + h / 2 -- the sill sits on top of the chair rail, nothing crosses the glass
		local face = seg.line + dir * 0.85
		local pos = origin + (if seg.axisX then V(along, y, face) else V(face, y, along))
		local function at(x, yy, out)
			local base = CFrame.lookAt(pos + look * out, pos + look * (out + 1))
			return base * CFrame.new(x, yy, 0)
		end
		box(m, "WindowFrame", V(w + 0.9, h + 0.9, 0.5), at(0, 0, -0.1), WOOD_DARK, Enum.Material.Wood, false)
		box(m, "WindowCasing", V(w + 1.5, h + 1.5, 0.22), at(0, 0, -0.32), WOOD, Enum.Material.Wood, false)
		local glass = box(m, "WindowGlass", V(w, h, 0.3), at(0, 0, 0.12), Color3.fromRGB(16, 22, 44), Enum.Material.Neon, false)
		glass.Transparency = 0.45
		for _, x in { -w / 4, w / 4 } do
			box(m, "Mullion", V(0.2, h, 0.45), at(x, 0, 0.15), WOOD_DARK, Enum.Material.Wood, false)
		end
		for _, yy in { -h / 6, h / 6 } do
			box(m, "Transom", V(w, 0.2, 0.45), at(0, yy, 0.15), WOOD_DARK, Enum.Material.Wood, false)
		end
		box(m, "Sill", V(w + 1.9, 0.35, 1.2), at(0, -h / 2 - 0.55, 0.3), WOOD, Enum.Material.Wood, false)
		if BOARDED[room.id] or (not theme.stone and rng:NextNumber() < 0.2) then
			for k = 1, 3 do
				box(m, "Board", V(w + 1.6, 0.9, 0.25), at(0, (k - 2) * h / 3.6, 0.55) * CFrame.Angles(0, 0, math.rad(rng:NextNumber(-14, 14))), Color3.fromRGB(78, 62, 48), Enum.Material.WoodPlanks, false)
			end
		elseif not theme.stone or big then
			-- curtains hanging to the floor, ragged at the bottom
			local topRel, bottomRel = h / 2 + 1.5, seg.floorY + 0.3 - y -- from above the window down to the floor
			local drop = topRel - bottomRel
			for _, sx in { -1, 1 } do
				local cw = 2.2
				local cx = sx * (w / 2 + cw / 2 - 0.6)
				local curtain = box(m, "Curtain", V(cw, drop, 0.2), at(cx, topRel - drop / 2, 0.7), CURTAIN, Enum.Material.Fabric, false)
				curtain.CFrame *= CFrame.Angles(0, 0, math.rad(sx * rng:NextNumber(0, 3)))
				box(m, "CurtainRag", V(cw * 0.6, 1.2, 0.18), at(cx + sx * 0.3, bottomRel + 0.5, 0.72), CURTAIN:Lerp(Color3.new(0, 0, 0), 0.3), Enum.Material.Fabric, false)
			end
			box(m, "Valance", V(w + 5, 1.2, 0.5), at(0, h / 2 + 1.2, 0.75), CURTAIN:Lerp(Color3.new(0, 0, 0), 0.2), Enum.Material.Fabric, false)
			box(m, "CurtainRod", V(w + 5.6, 0.18, 0.18), at(0, h / 2 + 1.9, 0.75), HouseKit.BRASS, Enum.Material.Metal, false)
		end
		if withMoon and i == 1 then
			local beam = Instance.new("SpotLight")
			beam.Color = MOON_LIGHT
			beam.Range = if big then 48 else 30
			beam.Brightness = HouseKit.WINDOW_BRIGHTNESS
			beam.Angle = 55
			beam.Shadows = true -- window bars and curtains throw long shadows across the floor
			beam.Face = Enum.NormalId.Front
			beam.Parent = glass
			glass.CFrame = CFrame.lookAt(glass.Position, glass.Position + look - V(0, 0.35, 0))
		end
	end
end

---------------------------------------------------------------- ceiling, light, air

-- Dark beams across the room every ~8 studs (along its shorter side), under the ceiling.
local function beams(m, origin, room, theme, graph)
	-- not under a hole in the floor above (the hall's void, the stairwells): they would hang in the air
	for _, other in graph.rooms do
		if other.level == room.level + 1 and #other.holes > 0 and other.x0 < room.x1 and other.x1 > room.x0 and other.z0 < room.z1 and other.z1 > room.z0 then
			return
		end
	end
	local w, d = room.x1 - room.x0, room.z1 - room.z0
	local top = room.floorY + CLEAR
	local acrossX = w <= d -- beams run along X, spaced along Z
	local length = if acrossX then w else d
	local span = if acrossX then d else w
	local count = math.floor(span / 8)
	local color = if theme.stone and room.level < 0 then Color3.fromRGB(40, 32, 26) else Color3.fromRGB(44, 30, 22)
	for i = 1, count do
		local t = (if acrossX then room.z0 else room.x0) + i * span / (count + 1)
		local pos = if acrossX then V((room.x0 + room.x1) / 2, top - 0.5, t) else V(t, top - 0.5, (room.z0 + room.z1) / 2)
		local size = if acrossX then V(length - 1, 1, 1) else V(1, 1, length - 1)
		box(m, "Beam", size, CFrame.new(origin + pos), color, Enum.Material.Wood, false)
	end
end

-- Ceiling light: a pendant lamp, or (4 grand rooms) the chandelier model.
local function ceilingLight(parent, origin, room)
	local m = Instance.new("Model")
	m.Name = "Ceiling light"
	m.Parent = parent
	-- the middle of the whole room rectangle (a room's `center` can be a standing point instead)
	local c = origin + V((room.x0 + room.x1) / 2, room.floorY, if room.id == 10 then 70 else (room.z0 + room.z1) / 2) -- (the hall's hangs over the carpet, clear of the monument)
	local function at(x, y, z)
		return CFrame.new(c + V(x, y, z))
	end
	local flicker = FLICKER_ROOMS[room.id]
	if CHANDELIER_ROOMS[room.id] then
		local template = HouseKit.libraryModel("Chandelier")
		local scale = if room.id == 10 then 1.4 else 0.75
		local drop = if room.id == 10 then 4 else 1.5 -- the hall's chandelier hangs from a long chain
		local h = 5
		if template then
			h = (template:GetAttribute("Size") or V(0, 8.7, 0)).Y * scale
			local chandelier = template:Clone()
			chandelier:ScaleTo(chandelier:GetScale() * scale)
			chandelier:PivotTo(at(0, CLEAR - drop - h, 0))
			chandelier.Name = "Chandelier"
			chandelier.Parent = m
			-- its bulbs (the model's Neon parts) are slim flame-shaped lamps, alight, with a crystal drop under each;
			-- the bright glass gold of the rest is old dark gilt
			for _, d in chandelier:GetDescendants() do
				if d:IsA("ParticleEmitter") then
					d.Enabled = false
				elseif d:IsA("BasePart") and d.Material == Enum.Material.Neon then
					local long = math.max(d.Size.X, d.Size.Y, d.Size.Z)
					local function slim(v)
						return if v == long then v else v * 0.55
					end
					d.Size = V(slim(d.Size.X), slim(d.Size.Y), slim(d.Size.Z))
					d.Color = Color3.fromRGB(255, 204, 136)
					d.Transparency = 0
					d.CastShadow = false
					local drop = box(chandelier, "Crystal", V(0.26, 0.62, 0.26) * scale, CFrame.new(d.Position - V(0, long * 0.5 + 0.75 * scale, 0)), Color3.fromRGB(226, 232, 240), Enum.Material.Glass, false)
					drop.Transparency = 0.25
					drop.Reflectance = 0.35
					drop.CastShadow = false
					local mesh = Instance.new("SpecialMesh")
					mesh.MeshType = Enum.MeshType.Sphere
					mesh.Parent = drop
				elseif d:IsA("BasePart") and d.Transparency < 1 then
					d.Material = Enum.Material.Metal
					d.Color = Color3.fromRGB(92, 72, 40)
				end
			end
		end
		-- a brass chain of real links and a ceiling rose (a plain dark bar read as something hanging there)
		local links = math.max(2, math.floor(drop / 0.55))
		for i = 1, links do
			local turn = if i % 2 == 0 then math.pi / 2 else 0
			box(m, "ChainLink", V(0.09, drop / links + 0.14, 0.32), at(0, CLEAR - (i - 0.5) * drop / links, 0) * CFrame.Angles(0, turn, 0), HouseKit.BRASS, Enum.Material.Metal, false)
		end
		local rose = box(m, "CeilingRose", V(0.35, 3, 3), at(0, CLEAR - 0.17, 0) * CFrame.Angles(0, 0, math.pi / 2), HouseKit.BRASS, Enum.Material.Metal, false)
		rose.Shape = Enum.PartType.Cylinder
		if LIT_ROOMS[room.id] then
			local glow = box(m, "ChandelierGlow", V(0.2, 0.2, 0.2), at(0, CLEAR - drop - h * 0.5, 0), WARM_LIGHT, Enum.Material.Neon, false)
			glow.Transparency = 1
			-- (the big one over the hall keeps its reach; in a room it is a soft pool of light)
			light(glow, WARM_LIGHT, if room.id == 10 then HouseKit.CHANDELIER_RANGE else 34, if room.id == 10 then HouseKit.CHANDELIER_BRIGHTNESS else 0.45, flicker, true)
		end
		return
	end
	-- the room's ceiling light: a brass fitting with a frosted glass bowl hung on chains (AssetLibrary.Asset_CeilingLight)
	local lit = LIT_ROOMS[room.id]
	local glowAt = at(0, CLEAR - 2.6, 0)
	local template = HouseKit.libraryModel("Asset_CeilingLight")
	if template then
		local lamp = template:Clone()
		lamp:PivotTo(at(0, CLEAR - (template:GetAttribute("Size") or V(3, 3.6, 3)).Y, 0))
		lamp.Name = "Lamp"
		for _, d in lamp:GetDescendants() do
			if d:IsA("MeshPart") and d:GetFullName():lower():find("bowl") then
				glowAt = d.CFrame
				if lit then -- the bowl itself glows
					for _, c in d:GetChildren() do
						if c:IsA("SurfaceAppearance") then
							c:Destroy()
						end
					end
					d.TextureID = ""
					d.Material = Enum.Material.Neon
					d.Color = Color3.fromRGB(255, 200, 130)
					d.Transparency = 0.1
					d.CastShadow = false
				end
			end
		end
		lamp.Parent = m
	end
	local bulb = box(m, "Bulb", V(0.5, 0.5, 0.5), glowAt, if lit then Color3.fromRGB(255, 196, 120) else Color3.fromRGB(40, 36, 30), if lit then Enum.Material.Neon else Enum.Material.Glass, false)
	bulb.Shape = Enum.PartType.Ball
	bulb.CastShadow = false
	bulb.Transparency = if template then 1 else 0
	if lit then
		light(bulb, WARM_LIGHT, HouseKit.LAMP_RANGE, HouseKit.LAMP_BRIGHTNESS, flicker, true)
	else
		-- a dead bulb: only a faint cold glow from outside, so the room's shape still reads in the dark
		light(bulb, MOON_LIGHT, 40, 0.2, false, false)
	end
end

-- Two candle sconces on the room's longest solid wall: little islands of warm light that flicker.
local function sconces(parent, origin, room, segments, takenOn)
	local best, bestLen = nil, 0
	for _, seg in segments do
		local windowed = seg.b == nil and room.level >= 0
		if (seg.a == room.id or seg.b == room.id) and not seg.doorAt and not windowed and seg.hi - seg.lo > bestLen then
			best, bestLen = seg, seg.hi - seg.lo
		end
	end
	if not best or bestLen < 14 then
		return
	end
	local dir = Geometry.faceDir(best, room.id)
	local taken = takenOn(best, room)
	local placed = 0
	for _, t in { 0.3, 0.7, 0.15, 0.85, 0.5 } do
		local along = best.lo + t * bestLen
		local clear = placed < 2
		for _, span in taken do
			if along > span[1] - 1 and along < span[2] + 1 then
				clear = false
			end
		end
		if clear then
			placed += 1
			table.insert(taken, { along - 1, along + 1 })
			-- a brass bracket: back plate on the wall, an arm curling out and up to a drip pan, one candle
			local m = Instance.new("Model")
			m.Name = "Wall sconce"
			m.Parent = parent
			local face = best.line + dir * 0.62
			local pos = origin + (if best.axisX then V(along, room.floorY + 7.5, face) else V(face, room.floorY + 7.5, along))
			local cf = CFrame.lookAt(pos, pos + (if best.axisX then V(0, 0, dir) else V(dir, 0, 0))) -- (-Z = out from the wall)
			local brass, dark = Color3.fromRGB(96, 76, 42), Color3.fromRGB(60, 46, 26)
			local function piece(name, size, offset, color, rot)
				return box(m, name, size, cf * CFrame.new(offset) * (rot or CFrame.new()), color, Enum.Material.Metal, false)
			end
			local function round(name, height, dia, offset, color, material)
				local p = box(m, name, V(height, dia, dia), cf * CFrame.new(offset) * CFrame.Angles(0, 0, math.pi / 2), color, material or Enum.Material.Metal, false)
				p.Shape = Enum.PartType.Cylinder
				return p
			end
			piece("SconcePlate", V(0.9, 2.3, 0.12), V(0, 0, 0), dark)
			piece("SconcePlateBoss", V(0.56, 1.7, 0.1), V(0, 0, -0.1), brass)
			for _, y in { 1.25, -1.25 } do
				local knob = piece("SconceFinial", V(0.32, 0.32, 0.32), V(0, y, -0.02), brass)
				knob.Shape = Enum.PartType.Ball
			end
			piece("SconceArm", V(0.12, 0.12, 0.62), V(0, -0.5, -0.42), brass, CFrame.Angles(math.rad(-28), 0, 0))
			piece("SconceArm", V(0.12, 0.12, 0.5), V(0, -0.66, -0.92), brass)
			piece("SconceArm", V(0.12, 0.12, 0.42), V(0, -0.52, -1.24), brass, CFrame.Angles(math.rad(62), 0, 0))
			round("SconcePan", 0.08, 0.72, V(0, -0.3, -1.3), brass)
			round("SconceCup", 0.24, 0.34, V(0, -0.16, -1.3), dark)
			round("SconceCandle", 1, 0.24, V(0, 0.44, -1.3), DIRTY_WHITE, Enum.Material.SmoothPlastic)
			HouseKit.flame(m, cf * CFrame.new(0, 0.94, -1.3), 0.36, 18)
			m.WorldPivot = cf
		end
	end
end

-- Cobwebs in two ceiling corners (library art; nothing if the place has no AssetLibrary).
-- Old dried blood: in about half the rooms a dark pool on the floor and the trail of something dragged from it.
local function stains(m, origin, room)
	local rng = Random.new(room.id * 131 + 7)
	if rng:NextNumber() < 0.45 then
		return
	end
	local x, z = rng:NextNumber(room.x0 + 7, room.x1 - 7), rng:NextNumber(room.z0 + 5, room.z1 - 5)
	for _, hole in room.holes do
		if x > hole.x0 - 6 and x < hole.x1 + 6 and z > hole.z0 - 6 and z < hole.z1 + 6 then
			return
		end
	end
	local blood = Color3.fromRGB(44, 8, 8)
	local y = room.floorY + 0.02
	for _ = 1, 4 do
		local d = rng:NextNumber(1.4, 3.6)
		local pool = box(m, "Stain", V(0.03, d, d * rng:NextNumber(0.7, 1)), CFrame.new(origin + V(x + rng:NextNumber(-1.4, 1.4), y, z + rng:NextNumber(-1.4, 1.4))) * CFrame.Angles(0, rng:NextNumber(0, 3), math.pi / 2), blood, Enum.Material.SmoothPlastic, false)
		pool.Shape = Enum.PartType.Cylinder
		pool.CastShadow = false
	end
	local a = rng:NextNumber(0, math.pi * 2)
	local dir = V(math.cos(a), 0, math.sin(a))
	for k = 1, 6 do
		local p = V(x, y, z) + dir * (1.5 + k * 1.7)
		if p.X > room.x0 + 2 and p.X < room.x1 - 2 and p.Z > room.z0 + 2 and p.Z < room.z1 - 2 then
			local streak = box(m, "Stain", V(rng:NextNumber(0.4, 0.9), 0.03, 1.5), CFrame.lookAt(origin + p, origin + p + dir) * CFrame.Angles(0, rng:NextNumber(-0.2, 0.2), 0), blood, Enum.Material.SmoothPlastic, false)
			streak.Transparency = 0.15 + k * 0.12
			streak.CastShadow = false
		end
	end
end

local function cobwebs(m, origin, room)
	local template = HouseKit.libraryModel("Cobwebs")
	if not template then
		return
	end
	local corners = { { room.x0, room.z0, 45 }, { room.x1, room.z1, 225 } }
	for _, c in corners do
		local web = template:Clone()
		web:ScaleTo(web:GetScale() * 0.42)
		local inward = V(if c[1] == room.x0 then 2.4 else -2.4, 0, if c[2] == room.z0 then 2.4 else -2.4)
		web:PivotTo(CFrame.new(origin + V(c[1], room.floorY + CLEAR - 1.3, c[2]) + inward) * CFrame.Angles(0, math.rad(c[3]), 0))
		web.Name = "Cobwebs"
		web.Parent = m
	end
end

-- Dust hanging in the air of the room. It only shows where light falls on it, so it drifts through
-- the flashlight beam and the moonlight and is invisible in the dark.
local function dust(m, origin, room)
	local w, d = room.x1 - room.x0, room.z1 - room.z0
	local volume = box(m, "DustVolume", V(w - 2, CLEAR - 3, d - 2), CFrame.new(origin + V((room.x0 + room.x1) / 2, room.floorY + CLEAR / 2, (room.z0 + room.z1) / 2)), Color3.new(1, 1, 1), Enum.Material.SmoothPlastic, false)
	volume.Transparency = 1
	volume.CanQuery = false
	volume.CanTouch = false
	volume.CastShadow = false
	local e = Instance.new("ParticleEmitter")
	e.Shape = Enum.ParticleEmitterShape.Box
	e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	e.Rate = math.max(2, math.floor(w * d / 260))
	e.Lifetime = NumberRange.new(10, 16)
	e.Speed = NumberRange.new(0.05, 0.25)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Acceleration = V(0, -0.02, 0)
	e.Size = NumberSequence.new(0.07)
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.2, 0.35), NumberSequenceKeypoint.new(0.8, 0.35), NumberSequenceKeypoint.new(1, 1) })
	e.Color = ColorSequence.new(Color3.fromRGB(230, 220, 200))
	e.LightInfluence = 1
	e.LightEmission = 0
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	e.Parent = volume
end

---------------------------------------------------------------- the hall

-- The front door the players escape through: one slab in the entrance gap, drawn on both faces.
-- NightCycle finds the Model "FrontDoor" (its PrimaryPart is the slab) and swings it open.
local function frontDoor(m, origin, seg)
	local w, h = Geometry.doorSize(seg)
	local door = Instance.new("Model")
	door.Name = "FrontDoor"
	local pos = origin + (if seg.axisX then V(seg.doorAt, seg.floorY + h / 2, seg.line) else V(seg.line, seg.floorY + h / 2, seg.doorAt))
	local cf = CFrame.new(pos) * (if seg.axisX then CFrame.new() else CFrame.Angles(0, math.pi / 2, 0))
	local slab = box(door, "DoorSlab", V(w + 0.1, h + 0.1, 0.5), cf, WOOD_DARK, Enum.Material.Wood)
	for _, sz in { -1, 1 } do
		for _, sx in { -1, 1 } do
			for _, py in { -h / 4, h / 4 } do
				box(door, "Panel", V(w / 2 - 1.2, h / 2 - 1.6, 0.12), cf * CFrame.new(sx * (w / 4), py, sz * 0.28), WOOD, Enum.Material.Wood, false)
			end
		end
		for _, y in { -h / 2 + 1.5, h / 2 - 1.5 } do
			box(door, "Strap", V(w - 0.6, 0.45, 0.18), cf * CFrame.new(0, y, sz * 0.3), HouseKit.METAL, Enum.Material.Metal, false)
		end
		for _, sx in { -1, 1 } do
			box(door, "Ring", V(0.2, 1.4, 1.4), cf * CFrame.new(sx * 0.7, -0.5, sz * 0.5), HouseKit.BRASS, Enum.Material.Metal, false)
		end
	end
	local anchor = box(door, "DoorPrompt", V(0.5, 0.5, 0.5), cf * CFrame.new(0, -h / 2 + 3, -1.4), Color3.new(1, 1, 1), Enum.Material.SmoothPlastic, false)
	anchor.Transparency = 1
	anchor.CanQuery = false
	door.PrimaryPart = slab
	door.WorldPivot = cf
	door.Parent = m
	-- a heavy stone frame around it
	local stone = Color3.fromRGB(96, 80, 66)
	local frameCF = cf * CFrame.new(0, -h / 2, 0)
	for _, sx in { -1, 1 } do
		box(m, "DoorFrame", V(1.4, h + 1, 1.8), frameCF * CFrame.new(sx * (w / 2 + 0.7), (h + 1) / 2, 0), stone, Enum.Material.Sandstone, false)
	end
	box(m, "DoorFrame", V(w + 3.6, 1.4, 2), frameCF * CFrame.new(0, h + 0.7, 0), stone, Enum.Material.Sandstone, false)
	box(m, "DoorFrameKey", V(1.6, 2.2, 2.2), frameCF * CFrame.new(0, h + 1, 0), stone:Lerp(Color3.new(1, 1, 1), 0.1), Enum.Material.Sandstone, false)
end

-- The hall's centrepiece, and the first thing you see from the front door. A column of black veined marble
-- from floor to roof, ribbed and banded in old bronze; a stone lion's head in a crown of iron spikes looks down
-- at the door, a ring of smaller lions below it. In front, on a round dais, the altar: four smouldering sockets, a
-- rune circle in the floor and its own shaft of light, so you can spot it from anywhere in the hall.
-- NightCycle looks up AltarPrompt, Socket1..4 and AltarGlow by name.
-- The memorial in the middle of the hall: a carved column, the lion's medallion on its face and a bronze lion
-- on top. It is a piece of Furniture (HouseDecor.fixtures), separate from the quest altar, so it can be moved.
function HouseDecor.monument(origin: Vector3): Model
	local m = Instance.new("Model")
	m.Name = "Monument"
	local base = origin + HouseDecor.PILLAR_POS
	local function at(x, y, z)
		return CFrame.new(base + V(x, y, z))
	end
	local MARBLE = Color3.fromRGB(46, 42, 46)
	local BRONZE = Color3.fromRGB(88, 68, 38) -- tarnished brass
	local BRONZE_DARK = Color3.fromRGB(58, 44, 26)
	local top = 18 -- a monument, half the hall's height: the stairs stay in view behind it
	local function disc(name, height, diameter, y, color, material, z, collide)
		local p = box(m, name, V(height, diameter, diameter), at(0, y, z or 0) * CFrame.Angles(0, 0, math.pi / 2), color, material or Enum.Material.Metal, collide == true)
		p.Shape = Enum.PartType.Cylinder
		return p
	end

	-- plinth, shaft, flutes, bands, flared capital
	-- The memorial: a short thick column of dark carved wood, gothic arches round its shaft (AssetLibrary.Asset_MemorialColumn) with a bronze lion
	-- (Asset_LionStatue) sitting on its capital, facing the front door. Built from parts if the library is missing.
	local memorial = HouseKit.libraryModel("Asset_MemorialColumn")
	local COLUMN_SCALE = 1 -- (the library's column is drawn at its size: 9.5 studs high) ...
	local COLUMN_WIDEN = 1.6 -- ... and set broader than drawn, so it stands thick and solid
	local STATUE_SCALE = 0.85
	if memorial then
		local column = memorial:Clone()
		column:ScaleTo(column:GetScale() * COLUMN_SCALE)
		column:PivotTo(CFrame.new(base)) -- (first: the widening below places the mesh at the base directly)
		-- its own texture is gilded and bright; the carving is in the shape, so it is cast in dark stone instead
		for _, d in column:GetDescendants() do
			if d:IsA("MeshPart") then
				if not memorial:GetAttribute("KeepTexture") then -- (a gilded generated texture is recast in plain marble)
					d.TextureID = ""
					d.Color = Color3.fromRGB(74, 74, 78) -- dark weathered stone, light enough for the carving to read (docs/theme.md)
					d.Material = Enum.Material.Slate
				end
				d.Size = V(d.Size.X * COLUMN_WIDEN, d.Size.Y, d.Size.Z * COLUMN_WIDEN)
				d.CFrame = CFrame.new(base + V(0, d.Size.Y / 2, 0)) * d.CFrame.Rotation
			end
		end
		column.WorldPivot = CFrame.new(base)
		column.Name = "Memorial column"
		column.Parent = m
		-- the asset says where its capital ends and how thick its shaft is (measured when it was added to the library)
		local capTop = (memorial:GetAttribute("CapitalTop") or 16.5) * COLUMN_SCALE
		disc("StatuePlinth", 1, 4.8, capTop + 0.5, BRONZE_DARK, Enum.Material.Metal, 0, false)
		disc("StatuePlinthLip", 0.3, 5.3, capTop + 0.85, BRONZE)
		local statueTemplate = HouseKit.libraryModel("Asset_LionStatue")
		if statueTemplate then
			local statue = statueTemplate:Clone()
			statue:ScaleTo(statue:GetScale() * STATUE_SCALE)
			for _, d in statue:GetDescendants() do
				if d:IsA("MeshPart") and statueTemplate:GetAttribute("KeepTexture") then
					d.Material = Enum.Material.Metal -- (its own sculpted bronze texture carries the detail)
					d.Reflectance = 0.12
				elseif d:IsA("MeshPart") then -- old dark bronze, catching only a little light
					d.TextureID = ""
					d.Color = Color3.fromRGB(88, 80, 64)
					d.Material = Enum.Material.Metal -- (old dull bronze)
					d.Reflectance = 0.1
				end
			end
			statue:PivotTo(CFrame.new(base + V(0, capTop + 1, 0)) * CFrame.Angles(0, math.pi, 0)) -- (looking toward the door)
			for _, d in statue:GetDescendants() do
				if d:IsA("BasePart") then
					d.CanCollide = false
				end
			end
			statue.Name = "Lion statue"
			statue.Parent = m
		end
		for i = 1, 0 do -- (no candles up there: the monument stays a dark shape against the stairs)
			local a = (i / 10) * math.pi * 2 + 0.3
			local h = 0.6 + (i % 4) * 0.25
			local r = 3.2
			local candle = box(m, "Candle", V(h, 0.36, 0.36), at(math.cos(a) * r, capTop + h / 2, math.sin(a) * r) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(214, 204, 178), Enum.Material.SmoothPlastic, false)
			candle.Shape = Enum.PartType.Cylinder
			box(m, "CandleFlame", V(0.12, 0.26, 0.12), at(math.cos(a) * r, capTop + 0.15 + h, math.sin(a) * r), Color3.fromRGB(255, 170, 70), Enum.Material.Neon, false)
		end
		local glow = box(m, "CrownGlow", V(0.3, 0.3, 0.3), at(0, capTop + 1, 3.8), Color3.fromRGB(255, 170, 70), Enum.Material.Neon, false)
		glow.Transparency = 1
		glow:Destroy()
	else
		-- A memorial column after the old baroque columns of European squares: round steps, a drum pedestal, a smooth
		-- shaft (the lion's medallion on its face), a leafy capital, and a veiled mourning figure with folded wings.
		local WOOD_DARK_M = Color3.fromRGB(40, 26, 18)
		local WOOD_M = Color3.fromRGB(58, 38, 26)
		local FIGURE = Color3.fromRGB(56, 48, 38)
		local W = Enum.Material.Wood
		local function blob(name, size, cf, color, material)
			local p = box(m, name, size, cf, color, material or Enum.Material.Metal, false)
			local mesh = Instance.new("SpecialMesh")
			mesh.MeshType = Enum.MeshType.Sphere
			mesh.Parent = p
			return p
		end
		disc("Step", 0.6, 10.4, 0.3, WOOD_DARK_M, W, 0, true)
		disc("Step", 0.6, 9, 0.9, WOOD_M, W, 0, true)
		disc("Drum", 2.6, 7.4, 2.5, WOOD_DARK_M, W, 0, true)
		disc("DrumTorus", 0.35, 7.9, 1.35, BRONZE_DARK)
		disc("DrumTorus", 0.35, 7.9, 3.7, BRONZE_DARK)
		disc("DrumCap", 0.4, 7.2, 4.0, WOOD_M, W)
		local length = top - 2 - 4.2
		disc("Column", length, 6, 4.2 + length / 2, WOOD_M, W, 0, true)
		disc("Band", 0.3, 6.4, 4.4, BRONZE)
		disc("Band", 0.3, 6.4, top - 2.1, BRONZE)
		-- capital: a bell of stacked rings and a crown of leaves curling out
		disc("Bell", 0.5, 6.2, top - 1.7, WOOD_DARK_M, W)
		disc("Bell", 0.5, 6.8, top - 1.2, WOOD_M, W)
		for i = 1, 12 do
			local a = (i / 12) * math.pi * 2
			local leaf = blob("Leaf", V(0.9, 1.3, 0.5), at(math.cos(a) * 3.15, top - 1.25, math.sin(a) * 3.15) * CFrame.Angles(0, -a + math.pi / 2, 0) * CFrame.Angles(math.rad(-20), 0, 0), BRONZE_DARK)
			leaf.CastShadow = false
		end
		disc("Abacus", 0.5, 8, top - 0.6, WOOD_DARK_M, W)
		disc("AbacusTop", 0.3, 7.4, top - 0.2, BRONZE_DARK)
		-- the figure: robe falling in folds to a round plinth, hood, clasped hands, wings folded behind
		disc("FigurePlinth", 1, 3.8, top + 0.5, WOOD_DARK_M, W)
		for k = 0, 5 do
			disc("Robe", 0.85, 3 - k * 0.3, top + 1.4 + k * 0.72, FIGURE, Enum.Material.Metal)
		end
		blob("Shoulders", V(2.3, 1.1, 1.5), at(0, top + 5.6, 0), FIGURE)
		blob("Hood", V(1.35, 1.6, 1.45), at(0, top + 6.45, 0.05), FIGURE)
		blob("Veil", V(0.8, 1, 0.3), at(0, top + 6.3, 0.62), Color3.fromRGB(12, 10, 10), Enum.Material.SmoothPlastic)
		blob("Hands", V(0.7, 0.55, 0.55), at(0, top + 4.7, 0.8), FIGURE)
		for _, sx in { -1, 1 } do
			blob("Sleeve", V(0.55, 1.4, 0.6), at(sx * 0.55, top + 5, 0.45) * CFrame.Angles(math.rad(-35), 0, math.rad(sx * 25)), FIGURE)
			for k, feather in { { 3.6, 1.3, 0 }, { 3, 1, 0.35 }, { 2.3, 0.8, 0.7 } } do
				blob("Wing", V(0.3, feather[1], feather[2] + 0.6), at(sx * (0.75 + k * 0.12), top + 5.2 - feather[3], -0.75 - k * 0.1) * CFrame.Angles(math.rad(12), math.rad(sx * 20), math.rad(sx * -12)), FIGURE)
			end
		end
		-- votive candles round the capital's top
		for i = 1, 10 do
			local a = (i / 10) * math.pi * 2 + 0.3
			local h = 0.6 + (i % 4) * 0.25
			local r = 3.3
			local candle = box(m, "Candle", V(h, 0.36, 0.36), at(math.cos(a) * r, top - 0.05 + h / 2, math.sin(a) * r) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(214, 204, 178), Enum.Material.SmoothPlastic, false)
			candle.Shape = Enum.PartType.Cylinder
			box(m, "CandleFlame", V(0.12, 0.26, 0.12), at(math.cos(a) * r, top + 0.1 + h, math.sin(a) * r), Color3.fromRGB(255, 170, 70), Enum.Material.Neon, false)
		end
		local wick = box(m, "CrownGlow", V(0.3, 0.3, 0.3), at(0, top + 0.8, 3.6), Color3.fromRGB(255, 170, 70), Enum.Material.Neon, false)
		wick.Transparency = 1
		light(wick, Color3.fromRGB(255, 170, 90), 14, 0.7, true)
	end

	-- the lion, in its crown of spikes, and the ring of lions below (the mesh faces -Z)
	local lion = HouseKit.libraryModel("Asset_LionHead")
	local function placeLion(height: number, cf: CFrame, name: string)
		if not lion then
			return
		end
		local s = lion:Clone()
		local size = s:GetAttribute("Size") or V(1, 1, 1)
		s:ScaleTo(s:GetScale() * height / size.Y)
		s:PivotTo(cf)
		s.Name = name
		if memorial and not lion:GetAttribute("KeepTexture") then -- (the sculpted one keeps its own tinted surface)
			for _, d in s:GetDescendants() do
				if d:IsA("MeshPart") then
					d.TextureID = ""
					d.Color = Color3.fromRGB(88, 80, 64)
					d.Material = Enum.Material.Metal -- (old dull bronze)
					d.Reflectance = 0.1
				end
			end
		end
		for _, d in s:GetDescendants() do
			if d:IsA("BasePart") then
				d.CanCollide = false
			end
		end
		s.Parent = m
	end
	-- the lion's medallion on the shaft: smaller on the slim carved column
	local faceY, faceZ = if memorial then 6.2 else 10.4, if memorial then (memorial:GetAttribute("ShaftRadius") or 1.7) * COLUMN_WIDEN + 0.1 else 3.2
	local headH = if memorial then 3 else 5.2
	local lionSize = lion and lion:GetAttribute("Size") or V(1, 1, 0.34)
	local haloR = if memorial then 1.7 else 3.1
	placeLion(headH, at(0, faceY - headH / 2, faceZ + headH * lionSize.Z / lionSize.Y / 2 - 0.12) * CFrame.Angles(0, math.pi, 0), "Great lion") -- (its back plate just sunk into the shaft: the head stands out in deep relief)
	disc("Halo", 0.3, haloR * 2 + 0.2, 0, BRONZE_DARK).CFrame = at(0, faceY, faceZ - 0.15) * CFrame.Angles(0, math.pi / 2, 0)
	disc("HaloInner", 0.34, haloR * 2 - 0.8, 0, Color3.fromRGB(14, 11, 11), Enum.Material.Slate).CFrame = at(0, faceY, faceZ - 0.12) * CFrame.Angles(0, math.pi / 2, 0)
	for i = 1, 16 do -- a short crown of spikes that keeps close to the column, so it reads from behind as well
		local a = (i / 16) * math.pi * 2
		local len = if i % 2 == 0 then 1.4 else 0.8
		box(m, "Spike", V(0.3, len, 0.2), at(math.cos(a) * (haloR + len / 2), faceY + math.sin(a) * (haloR + len / 2), faceZ - 0.3) * CFrame.Angles(0, 0, a - math.pi / 2), Color3.fromRGB(44, 40, 36), Enum.Material.Metal, false)
	end
	-- two dim lamps of its own, so the monument reads from the door (and on the title screen)
	for _, l in { { V(0, faceY + 1, faceZ + 5), 16, 1.1 }, { V(0, faceY + 9, 5), 14, 1.3 } } do
		local lamp = box(m, "MonumentGlow", V(0.2, 0.2, 0.2), CFrame.new(base + l[1]), Color3.new(1, 1, 1), Enum.Material.SmoothPlastic, false)
		lamp.Transparency = 1
		light(lamp, Color3.fromRGB(255, 206, 150), l[2], l[3], false)
	end
	local eyeLight = box(m, "EyeGlow", V(0.2, 0.2, 0.2), at(0, faceY + 0.6, faceZ + 4.5), Color3.new(1, 0, 0), Enum.Material.SmoothPlastic, false)
	eyeLight.Transparency = 1
	light(eyeLight, Color3.fromRGB(190, 30, 16), 9, 0.7, true)
	for i = 1, if memorial then 0 else 10 do -- (the carved column has no room for the ring of small lions)
		local a = (i / 10) * math.pi * 2
		local dir = V(math.sin(a), 0, math.cos(a))
		local pos = base + dir * 3.7 + V(0, 5, 0)
		placeLion(1.5, CFrame.lookAt(pos, pos + dir), "Ring lion")
	end
	-- iron chains wound round the column, dried blood from the crown
	for turn = 0, if memorial then -1 else 26 do
		local a = turn * 0.48
		local y = 7 + turn * 0.13
		local dir = V(math.cos(a), 0, math.sin(a))
		if dir.Z < 0.65 then -- (not across the face)
			box(m, "Chain", V(0.2, 0.2, 0.75), CFrame.lookAt(base + dir * 3.25 + V(0, y, 0), base + dir * 3.25 + V(0, y + 0.1, 0) + V(-dir.Z, 0, dir.X)), Color3.fromRGB(38, 36, 36), Enum.Material.CorrodedMetal, false)
		end
	end
	for i, x in { -1.9, -1, 0.7, 1.7 } do
		local h = 2.5 + i * 0.9
		box(m, "BloodRun", V(0.2, h, 0.05), at(x * headH / 5.2, faceY - headH * 0.62 - h / 2, faceZ - 0.16 - math.abs(x) * 0.2), Color3.fromRGB(50, 6, 6), Enum.Material.SmoothPlastic, false)
	end
	m.WorldPivot = CFrame.new(base)
	return m
end

-- The quest altar in front of the monument: dais, rune rings, the shaft of light, the four sockets and the plaque.
-- NightCycle finds it as the Model "Pillar" (AltarPrompt, Socket1..4, AltarGlow, AltarLight).
local function hallCentre(shell, origin)
	local m = Instance.new("Model")
	m.Name = "Pillar"
	local BRONZE = Color3.fromRGB(88, 68, 38) -- tarnished brass
	local BRONZE_DARK = Color3.fromRGB(58, 44, 26)

	-- the dais, the rune ring, the shaft of light
	local altar = origin + HouseDecor.ALTAR_POS
	local function floorDisc(name, h, d, y, color)
		local p = box(m, name, V(h, d, d), CFrame.new(altar - V(0, 1, 0) + V(0, y, 0)) * CFrame.Angles(0, 0, math.pi / 2), color, Enum.Material.Marble, true)
		p.Shape = Enum.PartType.Cylinder
		return p
	end
	floorDisc("Dais", 0.5, 18, 0.25, Color3.fromRGB(40, 36, 38))
	floorDisc("Dais2", 0.5, 14.4, 0.75, Color3.fromRGB(54, 48, 48))
	local runeColor = Color3.fromRGB(214, 120, 40)
	local function arcBar(radius: number, a: number, y: number, count: number)
		local c = altar - V(0, 1, 0) + V(math.cos(a) * radius, y, math.sin(a) * radius)
		local bar = box(m, "RuneRing", V(radius * 2 * math.pi / count + 0.1, 0.03, 0.16), CFrame.lookAt(c, c + V(-math.sin(a), 0, math.cos(a))) * CFrame.Angles(0, math.pi / 2, 0), runeColor, Enum.Material.Neon, false)
		bar.CastShadow = false
		bar.CanQuery = false
	end
	for i = 1, 40 do
		arcBar(8.5, (i / 40) * math.pi * 2, 0.51, 40)
	end
	for i = 1, 32 do
		arcBar(6.8, (i / 32) * math.pi * 2, 1.01, 32)
	end
	local beamSource = box(m, "AltarShaft", V(0.4, 0.4, 0.4), CFrame.lookAt(altar + V(0, 19, 9), altar), Color3.new(1, 1, 1), Enum.Material.SmoothPlastic, false)
	beamSource.Transparency = 1
	beamSource.CanQuery = false
	local shaft = Instance.new("SpotLight")
	shaft.Name = "AltarShaftLight"
	shaft.Color = Color3.fromRGB(170, 190, 235) -- cold, like moonlight through the high window
	shaft.Brightness = 0.7 -- (a faint shaft: bright enough to find the altar, not to wash out the column)
	shaft.Range = 30
	shaft.Angle = 22
	shaft.Shadows = true
	shaft.Face = Enum.NormalId.Front
	shaft.Parent = beamSource

	-- the altar
	local function onAltar(x, y, z)
		return CFrame.new(altar + V(x, y, z))
	end
	box(m, "AltarBase", V(9.6, 2.6, 3.6), onAltar(0, 1.3, 0), Color3.fromRGB(30, 26, 28), Enum.Material.Marble)
	box(m, "AltarTop", V(10.6, 0.4, 4.6), onAltar(0, 2.8, 0), BRONZE_DARK, Enum.Material.Metal)
	box(m, "AltarTrim", V(10.8, 0.14, 4.8), onAltar(0, 2.55, 0), BRONZE, Enum.Material.Metal, false)
	box(m, "AltarFoot", V(10.4, 0.4, 4.4), onAltar(0, 0.2, 0), BRONZE_DARK, Enum.Material.Metal, false)
	box(m, "AltarCloth", V(3.2, 0.06, 4.8), onAltar(0, 3.03, 0), Color3.fromRGB(96, 12, 16), Enum.Material.Fabric, false)
	for i = 1, HouseDecor.SOCKETS do
		local x = -3.45 + (i - 1) * 2.3
		box(m, "SocketCup", V(1.7, 0.3, 1.7), onAltar(x, 3.15, 0.2), BRONZE, Enum.Material.Metal, false)
		local socket = box(m, "Socket" .. i, V(1.2, 0.3, 1.2), onAltar(x, 3.3, 0.2), Color3.fromRGB(150, 26, 18), Enum.Material.Neon, false)
		socket:SetAttribute("Filled", false)
	end
	-- the words on its face
	local plaque = box(m, "AltarPlaque", V(7.6, 1.5, 0.12), onAltar(0, 1.4, 1.84), BRONZE, Enum.Material.Metal, false)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Back
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0.25 -- (legible by candlelight)
	gui.Parent = plaque
	local words = Instance.new("TextLabel")
	words.Size = UDim2.fromScale(1, 1)
	words.BackgroundTransparency = 1
	words.Font = Enum.Font.Antique
	words.TextScaled = true
	words.TextColor3 = Color3.fromRGB(212, 184, 120)
	words.TextStrokeColor3 = Color3.fromRGB(20, 12, 6)
	words.TextStrokeTransparency = 0.4
	words.Text = "FOUR OFFERINGS OPEN THE WAY"
	words.Parent = gui
	for _, sx in { -1, 1 } do
		box(m, "AltarCandle", V(0.45, 1.8, 0.45), onAltar(sx * 4.8, 3.9, 1.3), DIRTY_WHITE, Enum.Material.SmoothPlastic, false)
		local flame = HouseKit.flame(m, onAltar(sx * 4.8, 4.8, 1.3), 0.45, 12)
		flame.Name = "AltarFlame"
	end
	local prompt = box(m, "AltarPrompt", V(2, 2, 2), onAltar(0, 3.2, 0), Color3.new(1, 1, 1), Enum.Material.SmoothPlastic, false)
	prompt.Transparency = 1
	prompt.CanQuery = false
	local glow = box(m, "AltarGlow", V(0.4, 0.4, 0.4), onAltar(0, 4.4, 0.5), Color3.fromRGB(255, 150, 60), Enum.Material.Neon, false)
	glow.Transparency = 1
	local l = light(glow, Color3.fromRGB(255, 140, 60), 20, 0.9, true)
	l.Name = "AltarLight"
	m.Parent = shell

	-- a black and white marble checkerboard over the whole hall floor
	local tiles = Instance.new("Model")
	tiles.Name = "Checker floor"
	for ix = 0, 10 do
		for iz = 0, 11 do
			if (ix + iz) % 2 == 0 then
				local tile = box(tiles, "Tile", V(8, 0.03, math.min(8, 92 - iz * 8)), CFrame.new(origin + V(-44 + ix * 8 + 4, 0.015, iz * 8 + math.min(8, 92 - iz * 8) / 2)), Color3.fromRGB(64, 64, 70), Enum.Material.Marble, false)
				tile.CanQuery = false
				tile.CastShadow = false
			end
		end
	end
	tiles.Parent = shell

	-- a compass star inlaid in the marble round the dais: a dark border ring, pale field, sixteen points in brown
	-- and slate, and a ring of small diamonds
	local rose = Instance.new("Model")
	rose.Name = "Floor compass"
	local roseAt = origin + V(0, 0, HouseDecor.ALTAR_POS.Z)
	local function flat(name, d, y, color)
		local p = box(rose, name, V(0.02, d, d), CFrame.new(roseAt + V(0, y, 0)) * CFrame.Angles(0, 0, math.pi / 2), color, Enum.Material.Marble, false)
		p.Shape = Enum.PartType.Cylinder
		p.CanQuery = false
		p.CastShadow = false
	end
	flat("CompassBorder", 42, 0.035, Color3.fromRGB(40, 34, 32))
	flat("CompassField", 39.6, 0.045, Color3.fromRGB(176, 168, 156))
	flat("CompassInner", 22, 0.056, Color3.fromRGB(40, 34, 32))
	flat("CompassInnerField", 20.8, 0.062, Color3.fromRGB(176, 168, 156))
	-- a point = two thin right triangles back to back (WedgeParts lying flat)
	local function triangle(corner: Vector3, along: Vector3, la: number, out: Vector3, lo: number, y: number, color)
		local w = Instance.new("WedgePart")
		w.Name = "CompassPoint"
		w.Anchored = true
		w.CanCollide = false
		w.CanQuery = false
		w.CastShadow = false
		w.Size = V(0.02, la, lo)
		w.CFrame = CFrame.fromMatrix(corner + along * la / 2 - out * lo / 2 + V(0, y, 0), along:Cross(out), along, out)
		w.Color = color
		w.Material = Enum.Material.Marble
		w.TopSurface = Enum.SurfaceType.Smooth
		w.Parent = rose
	end
	for i = 0, 15 do
		local a = i / 16 * math.pi * 2
		local dir = V(math.cos(a), 0, math.sin(a))
		local perp = V(-dir.Z, 0, dir.X)
		local long = i % 2 == 0
		local inner, tip, half = 10.6, if long then 19.6 else 15.5, if long then 1.7 else 1.2
		local foot = roseAt + dir * inner
		local y = if long then 0.068 else 0.066 -- (all of the inlay stays under the carpet's top at 0.07)
		triangle(foot, dir, tip - inner, perp, half, y, if long then Color3.fromRGB(150, 106, 66) else Color3.fromRGB(70, 74, 82))
		triangle(foot, dir, tip - inner, -perp, half, y, if long then Color3.fromRGB(118, 82, 50) else Color3.fromRGB(52, 56, 64))
	end
	for i = 0, 23 do
		local a = (i + 0.5) / 24 * math.pi * 2
		local at = roseAt + V(math.cos(a), 0, math.sin(a)) * 21.3 + V(0, 0.05, 0)
		local d = box(rose, "CompassDiamond", V(0.9, 0.02, 0.9), CFrame.new(at) * CFrame.Angles(0, -a + math.pi / 4, 0), if i % 2 == 0 then Color3.fromRGB(122, 84, 52) else Color3.fromRGB(64, 68, 76), Enum.Material.Marble, false)
		d.CanQuery = false
		d.CastShadow = false
	end
	rose.Parent = shell

	-- the moulded beam along the galleries' edge (the posts that carry it are furniture: HouseDecor.fixtures)
	local arcade = Instance.new("Model")
	arcade.Name = "Gallery beams"
	for _, sx in { -1, 1 } do
		box(arcade, "GalleryBeam", V(1, 1.4, 72), CFrame.new(origin + V(sx * 34, LEVEL - 0.9, 48)), Color3.fromRGB(44, 28, 20), Enum.Material.Wood, false)
	end
	box(arcade, "GalleryBeam", V(69, 1.4, 1), CFrame.new(origin + V(0, LEVEL - 0.9, 84)), Color3.fromRGB(44, 28, 20), Enum.Material.Wood, false)
	box(arcade, "GalleryBeam", V(27, 1.4, 1), CFrame.new(origin + V(-20.5, LEVEL - 0.9, 12)), Color3.fromRGB(44, 28, 20), Enum.Material.Wood, false)
	box(arcade, "GalleryBeam", V(27, 1.4, 1), CFrame.new(origin + V(20.5, LEVEL - 0.9, 12)), Color3.fromRGB(44, 28, 20), Enum.Material.Wood, false)
	arcade.Parent = shell
end

---------------------------------------------------------------- assembly

-- One Model per room inside `shell`. (Walls, floors, stairs and doors are made by HouseBuilder.)
-- wallSpans (Furniture.wallSpans): what stands against each wall, so windows and sconces go around it.
function HouseDecor.decorate(shell: Instance, graph, origin: Vector3, segments, wallSpans)
	local function takenOn(seg, room)
		local dir = Geometry.faceDir(seg, room.id)
		local side = if seg.axisX then (if dir > 0 then "N" else "S") else (if dir > 0 then "W" else "E")
		local out = {}
		for _, span in (wallSpans and wallSpans[room.id .. side]) or {} do
			if span[2] > seg.lo and span[1] < seg.hi then
				table.insert(out, { span[1] - WINDOW_HALF, span[2] + WINDOW_HALF })
			end
		end
		return out
	end
	for _, room in graph.rooms do
		local theme = HouseDecor.THEMES[room.id]
		local m = Instance.new("Model")
		m.Name = "Room " .. theme.name
		local moon = true
		for _, seg in segments do
			if seg.a == room.id or seg.b == room.id then
				finishFace(m, origin, seg, room, theme)
				if seg.b == nil and seg.entrance then
					frontDoor(m, origin, seg)
				end
			end
		end
		beams(m, origin, room, theme, graph)
		cobwebs(m, origin, room)
		stains(m, origin, room)
		dust(m, origin, room)
		m.Parent = shell
	end
	hallCentre(shell, origin)
	CollectionService:AddTag(shell, "NightHunterShell")
end

-- A gothic pier in carved dark wood: an octagonal plinth, a round shaft with four colonnettes, gilt rings and a flared
-- capital under the beam it carries. `size` = the shaft's width, `height` = floor to the underside of the beam.
local PIER_STONE = Color3.fromRGB(62, 38, 26) -- carved dark wood, like the rest of the hall's joinery
local PIER_STONE_DARK = Color3.fromRGB(36, 23, 16)
local PIER_GOLD = Color3.fromRGB(88, 68, 38) -- tarnished brass, barely catching the light
local function woodPost(parent, name: string, foot: Vector3, size: number, height: number)
	-- A mansion post: a square shaft of dark panelled wood with beaded corners, a tall sunk panel on every face, a
	-- moulded base block, and a carved capital with scrolled brackets reaching out under the beam.
	local m = Instance.new("Model")
	m.Name = name
	local WOOD_POST = Color3.fromRGB(44, 28, 19)
	local DARK = Color3.fromRGB(26, 17, 12)
	local MID = Color3.fromRGB(60, 39, 26)
	local W = Enum.Material.Wood
	local function at(x, y, z)
		return CFrame.new(foot + V(x, y, z))
	end
	box(m, "Plinth", V(size + 1.1, 1.6, size + 1.1), at(0, 0.8, 0), DARK, W, false)
	box(m, "PlinthMould", V(size + 0.7, 0.35, size + 0.7), at(0, 1.78, 0), MID, W, false)
	box(m, "PlinthMould", V(size + 0.4, 0.25, size + 0.4), at(0, 2.08, 0), DARK, W, false)
	local shaftH = height - 4.4
	local shaftY = 2.2 + shaftH / 2
	local shaft = box(m, "Shaft", V(size, shaftH, size), at(0, shaftY, 0), WOOD_POST, W, true)
	for _, c in { { 1, 1 }, { 1, -1 }, { -1, 1 }, { -1, -1 } } do -- beaded corners
		local bead = box(m, "CornerBead", V(shaftH, 0.34, 0.34), at(c[1] * size / 2, shaftY, c[2] * size / 2) * CFrame.Angles(0, 0, math.pi / 2), MID, W, false)
		bead.Shape = Enum.PartType.Cylinder
	end
	for _, face in { V(1, 0, 0), V(-1, 0, 0), V(0, 0, 1), V(0, 0, -1) } do
		local out = face * (size / 2)
		local wide = size - 0.8
		local function slab(partName, w, h, depth, y, color)
			local sizeV = if face.X ~= 0 then V(depth, h, w) else V(w, h, depth)
			box(m, partName, sizeV, at(out.X + face.X * depth / 2, y, out.Z + face.Z * depth / 2), color, W, false)
		end
		slab("SunkPanel", wide, shaftH - 1.6, 0.04, shaftY, DARK) -- the recess
		slab("PanelMould", wide - 0.3, shaftH - 2.2, 0.06, shaftY, WOOD_POST)
		slab("PanelField", wide - 0.7, shaftH - 2.8, 0.09, shaftY, MID) -- the raised field
		slab("PanelBoss", 0.5, 0.5, 0.14, shaftY, DARK) -- a carved rosette at its middle
	end
	-- capital: astragal, a deep frieze block, cornice; brackets under the beam on the two sides along it
	box(m, "Astragal", V(size + 0.25, 0.3, size + 0.25), at(0, height - 2.05, 0), MID, W, false)
	box(m, "Frieze", V(size + 0.15, 0.9, size + 0.15), at(0, height - 1.45, 0), DARK, W, false)
	box(m, "Fillet", V(size + 0.35, 0.12, size + 0.35), at(0, height - 0.94, 0), PIER_GOLD, Enum.Material.Metal, false)
	box(m, "Cornice", V(size + 0.9, 0.5, size + 0.9), at(0, height - 0.63, 0), WOOD_POST, W, false)
	box(m, "CorniceTop", V(size + 1.3, 0.3, size + 1.3), at(0, height - 0.15, 0), DARK, W, false)
	for _, sz in { -1, 1 } do
		local z = sz * (size / 2 + 0.55)
		box(m, "Bracket", V(size * 0.55, 1.9, 1.1), at(0, height - 2.6, z) * CFrame.Angles(math.rad(sz * 16), 0, 0), WOOD_POST, W, false)
		box(m, "BracketScroll", V(size * 0.62, 0.5, 0.5), at(0, height - 3.5, z - sz * 0.15), MID, W, false)
	end
	m.WorldPivot = CFrame.new(foot)
	m.Parent = parent
	return m, shaft
end

-- A pointed (gothic) arch between two piers, in the plane x = `x`, from z0 to z1, its crown at the beam (`top`). Solid
-- carved wood above the curve, a moulded rib along it, a gilt keystone.
local function pointedArch(parent, x: number, z0: number, z1: number, spring: number, top: number, origin: Vector3)
	local m = Instance.new("Model")
	m.Name = "Gallery arch"
	local half = (z1 - z0) / 2
	local mid = (z0 + z1) / 2
	local rise = half -- a round arch: a half circle from shaft to shaft
	spring = math.min(spring, top - rise - 0.9) -- (room above the crown for the archivolt)
	local segments = 16
	local centre = origin + V(x, spring, mid)
	local fillTop = top - spring
	for k = 1, segments do
		local a0, a1 = math.pi * (k - 1) / segments, math.pi * k / segments
		local p = V(0, math.sin(a0) * half, -math.cos(a0) * half)
		local q = V(0, math.sin(a1) * half, -math.cos(a1) * half)
		local m1 = (p + q) / 2
		local len = (q - p).Magnitude
		local fill = box(m, "Spandrel", V(1.1, fillTop - m1.Y, math.abs(q.Z - p.Z) + 0.05), CFrame.new(centre + V(0, m1.Y + (fillTop - m1.Y) / 2, m1.Z)), PIER_STONE, Enum.Material.Wood, false)
		fill.CastShadow = true
		-- the archivolt: a broad carved band and a slim bead inside it
		local band = box(m, "Archivolt", V(1.35, 0.6, len + 0.1), CFrame.lookAt(centre + m1 * 1.06, centre + q * 1.06), PIER_STONE_DARK, Enum.Material.Wood, false)
		band.CastShadow = false
		local bead = box(m, "ArchBead", V(1.2, 0.18, len + 0.04), CFrame.lookAt(centre + m1 * 0.98, centre + q * 0.98), PIER_GOLD, Enum.Material.Metal, false)
		bead.CastShadow = false
	end
	local keystone = box(m, "Keystone", V(1.5, 1.2, 0.9), CFrame.new(centre + V(0, rise + 0.2, 0)), PIER_STONE_DARK, Enum.Material.Wood, false)
	local scroll = box(m, "KeystoneScroll", V(1.6, 0.4, 0.5), CFrame.new(centre + V(0, rise + 0.85, 0)), PIER_STONE, Enum.Material.Wood, false)
	scroll.Shape = Enum.PartType.Cylinder
	keystone.CastShadow = false
	for _, z in { z0 + 0.2, z1 - 0.2 } do -- where the arch meets the post, closed right up to the beam
		box(m, "ArchJamb", V(1.1, top - spring + 0.6, 0.4), CFrame.new(origin + V(x, spring - 0.6 + (top - spring + 0.6) / 2, z)), PIER_STONE, Enum.Material.Wood, false)
	end
	m.WorldPivot = CFrame.new(origin + V(x, spring, mid))
	m.Parent = parent
	return m
end

-- The pieces of the house a designer moves about: windows, ceiling lights and chandeliers, and the posts in the hall.
-- They are seeded into Furniture (Furniture.seed) like any other piece, so a rebuilt shell leaves them where you put
-- them. Returns { [roomId] = Folder of Models }.
function HouseDecor.fixtures(graph, origin: Vector3, segments, wallSpans)
	local out = {}
	for _, room in graph.rooms do
		local theme = HouseDecor.THEMES[room.id]
		local holder = Instance.new("Folder")
		local moon = true
		for _, seg in segments do
			if (seg.a == room.id or seg.b == room.id) and seg.b == nil and not seg.entrance and room.level >= 0 and seg.hi - seg.lo >= 12 then
				local dir = Geometry.faceDir(seg, room.id)
				local side = if seg.axisX then (if dir > 0 then "N" else "S") else (if dir > 0 then "W" else "E")
				local taken = {}
				for _, span in (wallSpans and wallSpans[room.id .. side]) or {} do
					if span[2] > seg.lo and span[1] < seg.hi then
						table.insert(taken, { span[1] - WINDOW_HALF, span[2] + WINDOW_HALF })
					end
				end
				windowsOn(holder, origin, seg, room, theme, moon, taken)
				moon = false
			end
		end
		if room.id ~= 1 then -- the hall is open to the roof: the landing's chandelier hangs over it
			ceilingLight(holder, origin, room)
		end
		if not theme.stone or room.level < 0 or room.id == 1 then
			-- candle sconces, clear of whatever stands against that wall
			sconces(holder, origin, room, segments, function(seg, r)
				local dir = Geometry.faceDir(seg, r.id)
				local side = if seg.axisX then (if dir > 0 then "N" else "S") else (if dir > 0 then "W" else "E")
				local out = {}
				for _, span in (wallSpans and wallSpans[r.id .. side]) or {} do
					if span[2] > seg.lo and span[1] < seg.hi then
						table.insert(out, { span[1] - 1, span[2] + 1 })
					end
				end
				return out
			end)
		end
		if room.id == 1 then
			HouseDecor.monument(origin).Parent = holder
			for _, sx in { -1, 1 } do
				for z = 16, 76, 10 do
					woodPost(holder, "Gallery post", origin + V(sx * 36, 0, z), 2.4, LEVEL - 1.6)
					if z < 76 then
						pointedArch(holder, sx * 36, z + 1.2, z + 8.8, 9.8, LEVEL - 1.6, origin) -- (from shaft face to shaft face)
					end
				end
				-- the pair that carries the bowed landing
				woodPost(holder, "Landing post", origin + V(sx * 4.5, 0, 28), 1.6, LEVEL - 1.2)
			end
		end
		out[room.id] = holder
	end
	return out
end

-- The hunter's nest for tonight: candles in a ring, a pile of rags, a red glow.
function HouseDecor.lair(parent: Instance, origin: Vector3, room: number): Instance
	local m = Instance.new("Model")
	m.Name = "Lair"
	local c = origin + HouseGraph.roomCenter(room)
	local function at(x, y, z, yaw)
		return CFrame.new(c + V(x, y, z)) * CFrame.Angles(0, math.rad(yaw or 0), 0)
	end
	local rng = Random.new(room)
	for i = 1, 8 do
		local a = (i / 8) * math.pi * 2
		local x, z = math.cos(a) * 4.5, math.sin(a) * 4.5
		box(m, "Candle", V(0.3, 0.8, 0.3), at(x, 0.4, z), DIRTY_WHITE, Enum.Material.SmoothPlastic, false)
		HouseKit.flame(m, at(x, 0.8, z), 0.3, 6)
	end
	for _ = 1, 7 do
		box(m, "Rags", V(rng:NextNumber(1.5, 3), 0.5, rng:NextNumber(1.5, 3)), at(rng:NextNumber(-1.8, 1.8), 0.25, rng:NextNumber(-1.8, 1.8), rng:NextNumber(0, 180)), Color3.fromRGB(35, 28, 26), Enum.Material.Fabric, false)
	end
	for i = 1, 4 do
		box(m, "Scratch", V(0.15, 0.02, 3), at(-2.2 + i * 0.5, 0.07, -6, 15), Color3.fromRGB(90, 20, 20), Enum.Material.SmoothPlastic, false)
	end
	local glow = box(m, "Glow", V(0.5, 0.5, 0.5), at(0, 2, 0), Color3.fromRGB(255, 40, 40), Enum.Material.Neon, false)
	glow.Transparency = 1
	light(glow, Color3.fromRGB(255, 50, 40), 18, 1.2, true)
	m.Parent = parent
	return m
end

return HouseDecor
