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
HouseDecor.VERSION = 10 -- bump when the shell finish changes, so a saved shell gets rebuilt

-- Pillar and altar: where the last night's relics go. Local to the house, at the hall's floor.
HouseDecor.PILLAR_POS = V(0, 0, 21)
HouseDecor.ALTAR_POS = V(0, 0, 25.5)
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
	[1] = { name = "Entrance Hall", stone = true, wall = Color3.fromRGB(118, 98, 82), wallMat = SAND, floor = Color3.fromRGB(84, 38, 34), floorMat = Enum.Material.WoodPlanks },
	[2] = { name = "Library", paper = PAPER.green, tint = Color3.fromRGB(120, 130, 118), floor = WOOD, floorMat = Enum.Material.WoodPlanks },
	[3] = { name = "Dining Room", paper = PAPER.maroon, tint = Color3.fromRGB(150, 128, 128), floor = WOOD, floorMat = Enum.Material.WoodPlanks },
	[4] = { name = "Study", paper = PAPER.grey, tint = Color3.fromRGB(120, 108, 96), floor = WOOD, floorMat = Enum.Material.WoodPlanks },
	[5] = { name = "Ballroom", paper = PAPER.floral, tint = Color3.fromRGB(130, 112, 96), floor = Color3.fromRGB(58, 38, 30), floorMat = Enum.Material.WoodPlanks },
	[6] = { name = "Kitchen", stone = true, wall = Color3.fromRGB(150, 146, 128), wallMat = Enum.Material.CeramicTiles, floor = Color3.fromRGB(110, 108, 100), floorMat = Enum.Material.Slate },
	[7] = { name = "Landing", stone = true, wall = Color3.fromRGB(118, 98, 82), wallMat = SAND, floor = Color3.fromRGB(84, 38, 34), floorMat = Enum.Material.WoodPlanks },
	[8] = { name = "Gallery", paper = PAPER.maroon, tint = Color3.fromRGB(120, 100, 104), floor = WOOD_DARK, floorMat = Enum.Material.WoodPlanks },
	[9] = { name = "Guest Bedroom", paper = PAPER.grey, tint = Color3.fromRGB(118, 118, 128), floor = WOOD_LIGHT, floorMat = Enum.Material.WoodPlanks },
	[10] = { name = "Bathroom", stone = true, wall = Color3.fromRGB(112, 132, 124), wallMat = Enum.Material.CeramicTiles, floor = Color3.fromRGB(150, 152, 148), floorMat = Enum.Material.Marble },
	[11] = { name = "Nursery", paper = PAPER.pink, tint = Color3.fromRGB(150, 128, 130), floor = WOOD_LIGHT, floorMat = Enum.Material.WoodPlanks },
	[12] = { name = "Master Bedroom", paper = PAPER.blue, tint = Color3.fromRGB(104, 110, 132), floor = WOOD, floorMat = Enum.Material.WoodPlanks },
	[13] = { name = "Boiler Room", stone = true, wall = Color3.fromRGB(70, 66, 64), wallMat = Enum.Material.Concrete, floor = Color3.fromRGB(62, 60, 58), floorMat = Enum.Material.Concrete },
	[14] = { name = "Wine Cellar", stone = true, wall = Color3.fromRGB(88, 62, 52), wallMat = Enum.Material.Brick, floor = Color3.fromRGB(70, 66, 62), floorMat = Enum.Material.Cobblestone },
	[15] = { name = "Cold Storage", stone = true, wall = Color3.fromRGB(78, 88, 92), wallMat = Enum.Material.Slate, floor = Color3.fromRGB(70, 78, 82), floorMat = Enum.Material.Slate },
	[16] = { name = "Crypt", stone = true, wall = Color3.fromRGB(64, 64, 68), wallMat = Enum.Material.Cobblestone, floor = Color3.fromRGB(56, 56, 60), floorMat = Enum.Material.Slate },
	[17] = { name = "Coal Cellar", stone = true, wall = Color3.fromRGB(46, 44, 44), wallMat = Enum.Material.Concrete, floor = Color3.fromRGB(36, 34, 34), floorMat = Enum.Material.Basalt },
}

-- Rooms whose light flickers (picked by hand so the house has a rhythm, not noise).
local FLICKER_ROOMS = { [4] = true, [8] = true, [11] = true, [13] = true, [15] = true, [16] = true, [17] = true }
-- Rooms lit by a chandelier instead of a pendant lamp.
local CHANDELIER_ROOMS = { [7] = true, [3] = true, [5] = true, [12] = true }
-- Windows that are boarded up (by room): the rest have curtains.
local BOARDED = { [4] = true, [6] = true, [11] = true }

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
	-- A thin mark on the wall, turned by `tilt` degrees in the wall's plane.
	local function mark(name, along, y, w, h, color, tilt, transparency)
		local out = if not theme.stone and y - h / 2 < y0 + 4.6 then 0.42 else 0.14 -- in front of the panelling
		local pos = if seg.axisX then V(along, y, face + dir * out) else V(face + dir * out, y, along)
		local cf = CFrame.new(origin + pos) * (if seg.axisX then CFrame.new() else CFrame.Angles(0, math.pi / 2, 0)) * CFrame.Angles(0, 0, math.rad(tilt or 0))
		local p = box(m, name, V(w, h, 0.04), cf, color, Enum.Material.SmoothPlastic, false)
		p.Transparency = transparency or 0
		p.CastShadow = false
		return p
	end

	local function paperSpan(from, to, yFrom)
		local top = y0 + CLEAR
		local paper = strip("Wallpaper", from, to, math.max(y0 + 4, yFrom), top - 0.9, 0.1, theme.tint, Enum.Material.SmoothPlastic)
		if paper then
			local tex = Instance.new("Texture")
			tex.Texture = theme.paper
			tex.Face = faceId(seg.axisX, dir)
			tex.StudsPerTileU = 6
			tex.StudsPerTileV = 6
			tex.Color3 = theme.tint
			tex.Parent = paper
		end
		strip("Cornice", from, to, top - 0.9, top, 0.35, WOOD_DARK, Enum.Material.Wood)
		strip("CorniceStep", from, to, top - 1.25, top - 0.9, 0.2, WOOD, Enum.Material.Wood)
		if yFrom > y0 + 4 then
			return
		end
		strip("Wainscot", from, to, y0, y0 + 4, 0.25, WOOD_DARK, Enum.Material.Wood)
		strip("ChairRail", from, to, y0 + 4, y0 + 4.35, 0.45, WOOD, Enum.Material.Wood)
		strip("Skirting", from, to, y0, y0 + 0.7, 0.4, Color3.fromRGB(34, 24, 18), Enum.Material.Wood)
		-- raised panels between stiles
		local bays = math.max(1, math.floor((to - from) / 3.6))
		local bay = (to - from) / bays
		for i = 0, bays - 1 do
			local a = from + i * bay
			strip("Panel", a + 0.45, a + bay - 0.45, y0 + 1.1, y0 + 3.5, 0.1, Color3.fromRGB(48, 32, 24), Enum.Material.Wood, 0.25)
		end
	end

	local function stoneSpan(from, to, yFrom)
		strip("Masonry", from, to, math.max(y0, yFrom), y0 + CLEAR, 0.1, theme.wall, theme.wallMat)
		if yFrom > y0 then
			return
		end
		strip("Plinth", from, to, y0, y0 + 0.8, 0.35, theme.wall:Lerp(Color3.new(0, 0, 0), 0.35), theme.wallMat)
		-- pilasters every ~10 studs (not at the very ends, where the corners are)
		local count = math.floor((to - from) / 10)
		for i = 1, count do
			local at = from + i * (to - from) / (count + 1)
			strip("Pilaster", at - 0.8, at + 0.8, y0, y0 + CLEAR, 0.55, theme.wall:Lerp(Color3.new(0, 0, 0), 0.15), theme.wallMat)
			strip("PilasterCap", at - 1.1, at + 1.1, y0 + CLEAR - 1, y0 + CLEAR, 0.75, theme.wall:Lerp(Color3.new(0, 0, 0), 0.25), theme.wallMat)
		end
	end

	-- What happened here. Roughly one mark every 9 studs, chosen by the wall's own seed.
	local function decay(from, to)
		local count = math.floor((to - from) / 9)
		for _ = 1, count do
			local roll = rng:NextNumber()
			local along = rng:NextNumber(from + 1.5, math.max(from + 1.6, to - 1.5))
			if roll < 0.3 and not theme.stone then
				-- torn wallpaper, the plaster showing through in a ragged patch (a few overlapping scraps)
				local y = y0 + rng:NextNumber(6, CLEAR - 4)
				for _ = 1, 3 do
					mark("TornPaper", along + rng:NextNumber(-0.8, 0.8), y + rng:NextNumber(-0.8, 0.8), rng:NextNumber(0.8, 2), rng:NextNumber(1, 2.6), PLASTER:Lerp(GRIME, rng:NextNumber(0, 0.4)), rng:NextNumber(-35, 35))
				end
			elseif roll < 0.55 then
				-- a water stain running down from the ceiling
				local h = rng:NextNumber(3, 8)
				mark("Stain", along, y0 + CLEAR - 1 - h / 2, rng:NextNumber(0.8, 2), h, GRIME, 0, 0.45)
			elseif roll < 0.72 then
				-- claw scratches
				local y = y0 + rng:NextNumber(3, 7)
				for k = 0, 3 do
					mark("Scratch", along + k * 0.35, y - k * 0.1, 0.1, 2.6, Color3.fromRGB(40, 14, 12), 22)
				end
			elseif roll < 0.85 then
				-- a smeared hand print, dripping
				local y = y0 + rng:NextNumber(3.5, 6)
				mark("HandSmear", along, y, 0.9, 1.1, BLOOD, rng:NextNumber(-20, 20), 0.15)
				mark("Drip", along + 0.15, y - 1.2, 0.14, rng:NextNumber(1, 2.4), BLOOD, 0, 0.2)
			end
		end
	end

	local function span(from, to, yFrom)
		if theme.stone then
			stoneSpan(from, to, yFrom)
		else
			paperSpan(from, to, yFrom)
		end
		if yFrom <= y0 then
			decay(from, to)
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
local function windowsOn(m, origin, seg, room, theme, withMoon: boolean)
	local dir = Geometry.faceDir(seg, room.id)
	local big = room.id == 7 -- the landing's great window over the front door
	local count = if big then 1 else math.max(1, math.floor((seg.hi - seg.lo) / 14))
	local look = V(if seg.axisX then 0 else dir, 0, if seg.axisX then dir else 0)
	local rng = Random.new(room.id * 77 + math.floor(seg.lo))
	for i = 1, count do
		local along = seg.lo + i * (seg.hi - seg.lo) / (count + 1)
		local w, h = if big then 9 else 5, if big then 13 else 9
		local y = seg.floorY + (if big then 9 else 3.8 + h / 2)
		local face = seg.line + dir * 0.6
		local pos = origin + (if seg.axisX then V(along, y, face) else V(face, y, along))
		local function at(x, yy, out)
			local base = CFrame.lookAt(pos + look * out, pos + look * (out + 1))
			return base * CFrame.new(x, yy, 0)
		end
		box(m, "WindowFrame", V(w + 0.8, h + 0.8, 0.4), at(0, 0, 0), WOOD_DARK, Enum.Material.Wood, false)
		local glass = box(m, "WindowGlass", V(w, h, 0.3), at(0, 0, 0.12), Color3.fromRGB(16, 22, 44), Enum.Material.Neon, false)
		glass.Transparency = 0.45
		for _, x in { -w / 4, w / 4 } do
			box(m, "Mullion", V(0.2, h, 0.45), at(x, 0, 0.15), WOOD_DARK, Enum.Material.Wood, false)
		end
		for _, yy in { -h / 6, h / 6 } do
			box(m, "Transom", V(w, 0.2, 0.45), at(0, yy, 0.15), WOOD_DARK, Enum.Material.Wood, false)
		end
		box(m, "Sill", V(w + 1.4, 0.35, 1.0), at(0, -h / 2 - 0.4, 0.45), WOOD, Enum.Material.Wood, false)
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
			beam.Shadows = true
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
local function ceilingLight(m, origin, room)
	-- the middle of the whole room rectangle (a room's `center` can be a standing point instead)
	local c = origin + V((room.x0 + room.x1) / 2, room.floorY, (room.z0 + room.z1) / 2)
	local function at(x, y, z)
		return CFrame.new(c + V(x, y, z))
	end
	local flicker = FLICKER_ROOMS[room.id]
	if CHANDELIER_ROOMS[room.id] then
		local template = HouseKit.libraryModel("Chandelier")
		local scale = if room.id == 7 then 1.2 else 0.75
		local drop = if room.id == 7 then 5 else 1.5 -- the hall's chandelier hangs from a long chain
		local h = 5
		if template then
			h = (template:GetAttribute("Size") or V(0, 8.7, 0)).Y * scale
			local chandelier = template:Clone()
			chandelier:ScaleTo(chandelier:GetScale() * scale)
			chandelier:PivotTo(at(0, CLEAR - drop - h, 0))
			chandelier.Name = "Chandelier"
			chandelier.Parent = m
		end
		box(m, "Chain", V(0.14, drop, 0.14), at(0, CLEAR - drop / 2, 0), Color3.fromRGB(20, 20, 20), Enum.Material.Metal, false)
		local glow = box(m, "ChandelierGlow", V(0.2, 0.2, 0.2), at(0, CLEAR - drop - h * 0.5, 0), WARM_LIGHT, Enum.Material.Neon, false)
		glow.Transparency = 1
		light(glow, WARM_LIGHT, HouseKit.CHANDELIER_RANGE, HouseKit.CHANDELIER_BRIGHTNESS, flicker)
		return
	end
	box(m, "LampCord", V(0.1, 3.2, 0.1), at(0, CLEAR - 1.6, 0), Color3.fromRGB(20, 20, 20), Enum.Material.SmoothPlastic, false)
	local theme = HouseDecor.THEMES[room.id]
	if not theme.stone then
		local shade = box(m, "LampShade", V(1.2, 2.8, 2.8), at(0, CLEAR - 4, 0) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(70, 52, 36), Enum.Material.Fabric, false)
		shade.Shape = Enum.PartType.Cylinder
	else
		box(m, "Cage", V(1, 1.2, 1), at(0, CLEAR - 4.6, 0), Color3.fromRGB(30, 30, 30), Enum.Material.DiamondPlate, false).Transparency = 0.6
	end
	local bulb = box(m, "Bulb", V(0.6, 0.6, 0.6), at(0, CLEAR - 4.6, 0), Color3.fromRGB(255, 170, 90), Enum.Material.Neon, false)
	bulb.Shape = Enum.PartType.Ball
	light(bulb, WARM_LIGHT, HouseKit.LAMP_RANGE, HouseKit.LAMP_BRIGHTNESS, flicker)
end

-- Two candle sconces on the room's longest solid wall: little islands of warm light that flicker.
local function sconces(m, origin, room, segments)
	local best, bestLen = nil, 0
	for _, seg in segments do
		if (seg.a == room.id or seg.b == room.id) and not seg.doorAt and seg.hi - seg.lo > bestLen then
			best, bestLen = seg, seg.hi - seg.lo
		end
	end
	if not best or bestLen < 14 then
		return
	end
	local dir = Geometry.faceDir(best, room.id)
	for _, t in { 0.3, 0.7 } do
		local along = best.lo + t * bestLen
		local face = best.line + dir * 0.75
		local pos = origin + (if best.axisX then V(along, room.floorY + 7.5, face) else V(face, room.floorY + 7.5, along))
		box(m, "SconcePlate", V(0.7, 1.4, 0.7), CFrame.new(pos), HouseKit.BRASS, Enum.Material.Metal, false)
		box(m, "SconceCandle", V(0.3, 0.9, 0.3), CFrame.new(pos + V(0, 1.1, 0)), DIRTY_WHITE, Enum.Material.SmoothPlastic, false)
		local flame = box(m, "SconceFlame", V(0.16, 0.32, 0.16), CFrame.new(pos + V(0, 1.75, 0)), Color3.fromRGB(255, 170, 70), Enum.Material.Neon, false)
		light(flame, WARM_LIGHT, 13, HouseKit.CANDLE_BRIGHTNESS, true)
	end
end

-- Cobwebs in two ceiling corners (library art; nothing if the place has no AssetLibrary).
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
	local slab = box(door, "DoorSlab", V(w - 0.1, h - 0.1, 0.5), cf, WOOD_DARK, Enum.Material.Wood)
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

-- The hall's centrepiece: a stone pillar from floor to roof with a carved face, and an altar in front
-- of it with four sockets. On the last night the relics go into the sockets and the pillar gives up the
-- key. NightCycle looks up AltarPrompt, Socket1..4 and AltarGlow by name.
local function hallCentre(shell, origin)
	local m = Instance.new("Model")
	m.Name = "Pillar"
	local base = origin + HouseDecor.PILLAR_POS
	local function at(x, y, z)
		return CFrame.new(base + V(x, y, z))
	end
	local STONE_COLOR = Color3.fromRGB(146, 126, 106)
	local top = LEVEL + CLEAR
	box(m, "Plinth", V(8, 1.4, 8), at(0, 0.7, 0), Color3.fromRGB(104, 88, 74), Enum.Material.Sandstone)
	box(m, "Plinth2", V(6.4, 1.2, 6.4), at(0, 2, 0), Color3.fromRGB(116, 98, 82), Enum.Material.Sandstone)
	local length = top - 2.6
	local column = box(m, "Column", V(length, 4.6, 4.6), at(0, 2.6 + length / 2, 0) * CFrame.Angles(0, 0, math.pi / 2), STONE_COLOR, Enum.Material.Sandstone)
	column.Shape = Enum.PartType.Cylinder
	for _, y in { 6, 18, 26 } do
		local ring = box(m, "Band", V(0.7, 5.1, 5.1), at(0, y, 0) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(96, 80, 66), Enum.Material.Sandstone)
		ring.Shape = Enum.PartType.Cylinder
	end
	box(m, "Capital", V(6.6, 1.6, 6.6), at(0, top - 0.8, 0), Color3.fromRGB(104, 88, 74), Enum.Material.Sandstone)
	-- the carved mask looking at the front door: a long pale face, deep empty sockets with a faint red
	-- glint far inside, and a mouth stretched open in a scream
	local pale = Color3.fromRGB(178, 166, 148)
	-- an ellipsoid: a block with a sphere mesh stretched to its size
	local function oval(name, size, cf, color, material)
		local p = box(m, name, size, cf, color, material, false)
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = p
		return p
	end
	oval("Mask", V(3.6, 5.8, 2.2), at(0, 12.6, 2.6), pale, Enum.Material.Limestone)
	box(m, "Brow", V(3.6, 0.6, 0.9), at(0, 14.4, 3.2), pale:Lerp(Color3.new(0, 0, 0), 0.15), Enum.Material.Limestone, false)
	for _, sx in { -1, 1 } do
		oval("Socket", V(1.1, 1.8, 0.6), at(sx * 0.85, 13.4, 3.55), Color3.fromRGB(6, 4, 4), Enum.Material.SmoothPlastic)
		local glint = box(m, "Glint", V(0.18, 0.18, 0.1), at(sx * 0.85, 13.3, 3.82), Color3.fromRGB(120, 0, 0), Enum.Material.Neon, false)
		glint.Transparency = 0.2
		box(m, "Streak", V(0.14, 2.6, 0.08), at(sx * 0.95, 11.6, 3.6), Color3.fromRGB(30, 22, 18), Enum.Material.SmoothPlastic, false)
	end
	oval("Mouth", V(1.3, 2.8, 0.6), at(0, 10.7, 3.5), Color3.fromRGB(4, 3, 3), Enum.Material.SmoothPlastic)
	for k = -1, 1 do
		box(m, "Crack", V(0.08, 1.8, 0.06), at(1.1 + k * 0.1, 14.6 - k * 0.3, 3.6) * CFrame.Angles(0, 0, math.rad(20 + k * 25)), Color3.fromRGB(30, 26, 22), Enum.Material.SmoothPlastic, false)
	end

	-- the altar
	local altar = origin + HouseDecor.ALTAR_POS
	local function onAltar(x, y, z)
		return CFrame.new(altar + V(x, y, z))
	end
	box(m, "AltarBase", V(6.4, 1.8, 2.8), onAltar(0, 0.9, 0), Color3.fromRGB(82, 68, 60), Enum.Material.Granite)
	box(m, "AltarTop", V(7, 0.4, 3.4), onAltar(0, 2, 0), Color3.fromRGB(110, 94, 82), Enum.Material.Granite)
	box(m, "AltarCloth", V(3, 0.06, 3.6), onAltar(0, 2.23, 0), Color3.fromRGB(80, 14, 18), Enum.Material.Fabric, false)
	for i = 1, HouseDecor.SOCKETS do
		local socket = box(m, "Socket" .. i, V(1.0, 0.25, 1.0), onAltar(-2.55 + (i - 1) * 1.7, 2.3, 0), Color3.fromRGB(32, 34, 40), Enum.Material.Metal, false)
		socket:SetAttribute("Filled", false)
	end
	for _, sx in { -1, 1 } do
		box(m, "AltarCandle", V(0.35, 1.2, 0.35), onAltar(sx * 3.1, 2.8, 1.1), DIRTY_WHITE, Enum.Material.SmoothPlastic, false)
		local flame = box(m, "AltarFlame", V(0.16, 0.32, 0.16), onAltar(sx * 3.1, 3.55, 1.1), Color3.fromRGB(255, 170, 70), Enum.Material.Neon, false)
		light(flame, WARM_LIGHT, 10, HouseKit.CANDLE_BRIGHTNESS, true)
	end
	local prompt = box(m, "AltarPrompt", V(2, 2, 2), onAltar(0, 3.2, 0), Color3.new(1, 1, 1), Enum.Material.SmoothPlastic, false)
	prompt.Transparency = 1
	prompt.CanQuery = false
	local glow = box(m, "AltarGlow", V(0.4, 0.4, 0.4), onAltar(0, 3.4, 0), Color3.fromRGB(90, 255, 210), Enum.Material.Neon, false)
	glow.Transparency = 1
	local l = light(glow, Color3.fromRGB(90, 255, 210), 16, 0.35, false)
	l.Name = "AltarLight"
	m.Parent = shell
end

-- Words smeared high on the hall's west wall, above the staircase: the first thing you see.
local function scrawl(shell, origin, text: string, pos: Vector3, normal: Vector3, width: number)
	local board = box(shell, "Scrawl", V(width, width * 0.32, 0.05), CFrame.lookAt(origin + pos, origin + pos + normal), Color3.new(0, 0, 0), Enum.Material.SmoothPlastic, false)
	board.Transparency = 1
	board.CanQuery = false
	board.CastShadow = false
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 30
	gui.LightInfluence = 1
	gui.Parent = board
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.Font = Enum.Font.Creepster
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(120, 10, 10)
	label.TextTransparency = 0.1
	label.Rotation = -3
	label.Parent = gui
end

---------------------------------------------------------------- assembly

-- One Model per room inside `shell`. (Walls, floors, stairs and doors are made by HouseBuilder.)
function HouseDecor.decorate(shell: Instance, graph, origin: Vector3, segments)
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
				elseif seg.b == nil and room.level >= 0 and seg.hi - seg.lo >= 12 and not (room.id == 1) then
					windowsOn(m, origin, seg, room, theme, moon)
					moon = false
				end
			end
		end
		beams(m, origin, room, theme, graph)
		ceilingLight(m, origin, room)
		if not theme.stone or room.level < 0 then
			sconces(m, origin, room, segments)
		end
		cobwebs(m, origin, room)
		dust(m, origin, room)
		m.Parent = shell
	end
	hallCentre(shell, origin)
	-- high on the west wall of the hall, above the stairs, seen from the front door
	scrawl(shell, origin, "IT HEARS YOU", V(-20.85, LEVEL + 7, 29), V(1, 0, 0), 14)
	CollectionService:AddTag(shell, "NightHunterShell")
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
		box(m, "Flame", V(0.15, 0.3, 0.15), at(x, 0.95, z), Color3.fromRGB(255, 170, 70), Enum.Material.Neon, false)
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
