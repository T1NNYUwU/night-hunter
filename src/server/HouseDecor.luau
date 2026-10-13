--!nonstrict
-- The mansion SHELL's finish: wallpaper / stone and wainscot on every wall face, windows, the
-- ceiling light of each room, the front door, and the hall's central pillar with its altar. One Model
-- per room inside the house's "Shell" folder.
--
-- Furniture is NOT here: it lives in Workspace.NightHunterHouse.Furniture (see Furniture.luau), one
-- independent Model per piece, so it can be moved or swapped in Studio and survives a rebuild of the
-- shell. Walls, floors, ceilings, stairs and doors are built by HouseBuilder from HouseGeometry.
--
-- Coordinates in here are house-local studs (add `origin` for the world).

local HouseGraph = require(game:GetService("ReplicatedStorage"):WaitForChild("NightHunter"):WaitForChild("HouseGraph"))
local HouseKit = require(script.Parent.HouseKit)
local Geometry = require(script.Parent.HouseGeometry)

local box, light = HouseKit.box, HouseKit.light
local WOOD_DARK, WOOD, WOOD_LIGHT = HouseKit.WOOD_DARK, HouseKit.WOOD, HouseKit.WOOD_LIGHT
local DIRTY_WHITE, WARM_LIGHT, MOON_LIGHT = HouseKit.DIRTY_WHITE, HouseKit.WARM_LIGHT, HouseKit.MOON_LIGHT
local V = Vector3.new
local CLEAR = HouseGraph.CLEAR

local HouseDecor = {}
HouseDecor.VERSION = 9 -- bump when the shell finish changes, so a saved shell gets rebuilt

-- Pillar and altar: where the last night's relics go. Local to the house, at the hall's floor.
HouseDecor.PILLAR_POS = V(0, 0, 14)
HouseDecor.ALTAR_POS = V(0, 0, 18.2)
HouseDecor.SOCKETS = 4

-- Room themes, by room id. `stone` rooms have bare masonry instead of wallpaper + wainscot.
local STONE = Enum.Material.Sandstone
HouseDecor.THEMES = {
	[1] = { name = "Entrance Hall", stone = true, wall = Color3.fromRGB(122, 100, 82), wallMat = STONE, floor = Color3.fromRGB(92, 42, 38), floorMat = Enum.Material.WoodPlanks },
	[2] = { name = "Library", wall = Color3.fromRGB(52, 66, 56), floor = WOOD, floorMat = Enum.Material.WoodPlanks },
	[3] = { name = "Dining Room", wall = Color3.fromRGB(70, 52, 70), floor = WOOD, floorMat = Enum.Material.WoodPlanks },
	[4] = { name = "Study", wall = Color3.fromRGB(74, 56, 46), floor = WOOD, floorMat = Enum.Material.WoodPlanks },
	[5] = { name = "Living Room", wall = Color3.fromRGB(84, 54, 50), floor = WOOD, floorMat = Enum.Material.WoodPlanks },
	[6] = { name = "Kitchen", wall = Color3.fromRGB(118, 114, 96), floor = Color3.fromRGB(150, 150, 140), floorMat = Enum.Material.Slate },
	[7] = { name = "Landing", stone = true, wall = Color3.fromRGB(122, 100, 82), wallMat = STONE, floor = Color3.fromRGB(92, 42, 38), floorMat = Enum.Material.WoodPlanks },
	[8] = { name = "Gallery", wall = Color3.fromRGB(60, 52, 72), floor = WOOD_DARK, floorMat = Enum.Material.WoodPlanks },
	[9] = { name = "Guest Bedroom", wall = Color3.fromRGB(86, 70, 92), floor = WOOD_LIGHT, floorMat = Enum.Material.WoodPlanks },
	[10] = { name = "Bathroom", wall = Color3.fromRGB(86, 108, 106), floor = Color3.fromRGB(170, 175, 172), floorMat = Enum.Material.Marble },
	[11] = { name = "Nursery", wall = Color3.fromRGB(120, 100, 82), floor = WOOD_LIGHT, floorMat = Enum.Material.WoodPlanks },
	[12] = { name = "Master Bedroom", wall = Color3.fromRGB(64, 50, 72), floor = WOOD_LIGHT, floorMat = Enum.Material.WoodPlanks },
	[13] = { name = "Boiler Room", stone = true, wall = Color3.fromRGB(70, 66, 64), wallMat = Enum.Material.Concrete, floor = Color3.fromRGB(62, 60, 58), floorMat = Enum.Material.Concrete },
	[14] = { name = "Wine Cellar", stone = true, wall = Color3.fromRGB(88, 62, 52), wallMat = Enum.Material.Brick, floor = Color3.fromRGB(70, 66, 62), floorMat = Enum.Material.Cobblestone },
	[15] = { name = "Cold Storage", stone = true, wall = Color3.fromRGB(78, 88, 92), wallMat = Enum.Material.Slate, floor = Color3.fromRGB(70, 78, 82), floorMat = Enum.Material.Slate },
	[16] = { name = "Crypt", stone = true, wall = Color3.fromRGB(64, 64, 68), wallMat = Enum.Material.Cobblestone, floor = Color3.fromRGB(56, 56, 60), floorMat = Enum.Material.Slate },
	[17] = { name = "Coal Cellar", stone = true, wall = Color3.fromRGB(46, 44, 44), wallMat = Enum.Material.Concrete, floor = Color3.fromRGB(36, 34, 34), floorMat = Enum.Material.Basalt },
}

-- Rooms whose light flickers (picked by hand so the house has a rhythm, not noise).
local FLICKER_ROOMS = { [4] = true, [11] = true, [13] = true, [15] = true, [16] = true, [17] = true }
-- Rooms lit by a chandelier instead of a pendant lamp.
local CHANDELIER_ROOMS = { [7] = true, [3] = true, [5] = true, [12] = true }

---------------------------------------------------------------- shell finish

-- Wallpaper (or masonry) + wainscot + rail on one face of a wall segment, seen from inside `room`.
local function finishFace(m, origin, seg, room, theme)
	local dir = Geometry.faceDir(seg, room.id)
	local face = seg.line + dir * 0.5
	local y0 = seg.floorY

	local function strip(name, from, to, yBottom, yTop, depth, color, material)
		local len, h = to - from, yTop - yBottom
		if len <= 0.05 or h <= 0.05 then
			return
		end
		local mid, offset = (from + to) / 2, face + dir * depth / 2
		local size = if seg.axisX then V(len, h, depth) else V(depth, h, len)
		local pos = if seg.axisX then V(mid, yBottom + h / 2, offset) else V(offset, yBottom + h / 2, mid)
		box(m, name, size, CFrame.new(origin + pos), color, material, false)
	end
	local function span(from, to, yFrom)
		if theme.stone then
			strip("Masonry", from, to, math.max(y0, yFrom), y0 + CLEAR, 0.1, theme.wall, theme.wallMat)
		else
			strip("Wallpaper", from, to, math.max(y0 + 3, yFrom), y0 + CLEAR, 0.1, theme.wall, Enum.Material.Fabric)
			if yFrom <= y0 + 3 then
				strip("Wainscot", from, to, y0, y0 + 3, 0.25, WOOD_DARK, Enum.Material.Wood)
				strip("Rail", from, to, y0 + 3, y0 + 3.2, 0.35, WOOD_LIGHT, Enum.Material.Wood)
			end
		end
	end

	if seg.doorAt then
		local w, h = Geometry.doorSize(seg)
		span(seg.lo, seg.doorAt - w / 2, y0)
		span(seg.doorAt + w / 2, seg.hi, y0)
		span(seg.doorAt - w / 2, seg.doorAt + w / 2, y0 + h) -- above the doorway
	else
		span(seg.lo, seg.hi, y0)
	end
end

-- A tall window on an outer wall, with a faint cold moonbeam pushing into the room.
local function windowOn(m, origin, seg, room)
	local dir = Geometry.faceDir(seg, room.id)
	local big = room.id == 7 -- the landing's window over the front door
	local mid = (seg.lo + seg.hi) / 2
	local w, h = if big then 8 else 5.4, if big then 10 else 7.4
	local y = seg.floorY + (if big then 8 else 8)
	local face = seg.line + dir * 0.6
	local pos = origin + (if seg.axisX then V(mid, y, face) else V(face, y, mid))
	local look = Vector3.new(if seg.axisX then 0 else dir, 0, if seg.axisX then dir else 0)
	local function at(offset: number)
		return CFrame.lookAt(pos + look * offset, pos + look * (offset + 1))
	end
	box(m, "WindowFrame", V(w, h, 0.3), at(0), WOOD_DARK, Enum.Material.Wood, false)
	local glass = box(m, "WindowGlass", V(w - 0.8, h - 0.8, 0.35), at(0.1), Color3.fromRGB(20, 28, 54), Enum.Material.Neon, false)
	glass.Transparency = 0.4
	box(m, "WindowBarV", V(0.2, h - 0.8, 0.4), at(0.15), WOOD_DARK, Enum.Material.Wood, false)
	box(m, "WindowBarH", V(w - 0.8, 0.2, 0.4), at(0.15), WOOD_DARK, Enum.Material.Wood, false)
	local beam = Instance.new("SpotLight")
	beam.Color = MOON_LIGHT
	beam.Range = if big then 40 else 22
	beam.Brightness = HouseKit.WINDOW_BRIGHTNESS
	beam.Angle = 60
	beam.Face = Enum.NormalId.Front
	beam.Parent = glass
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
		local scale = if room.id == 7 then 1.0 else 0.65
		local drop = if room.id == 7 then 4 else 0 -- the hall's chandelier hangs from a long chain
		local h = 5
		if template then
			h = (template:GetAttribute("Size") or V(0, 8.7, 0)).Y * scale
			local chandelier = template:Clone()
			chandelier:ScaleTo(chandelier:GetScale() * scale)
			chandelier:PivotTo(at(0, CLEAR - drop - h, 0))
			chandelier.Name = "Chandelier"
			chandelier.Parent = m
		end
		if drop > 0 then
			box(m, "Chain", V(0.12, drop, 0.12), at(0, CLEAR - drop / 2, 0), Color3.fromRGB(20, 20, 20), Enum.Material.Metal, false)
		end
		local glow = box(m, "ChandelierGlow", V(0.2, 0.2, 0.2), at(0, CLEAR - drop - h * 0.5, 0), WARM_LIGHT, Enum.Material.Neon, false)
		glow.Transparency = 1
		light(glow, WARM_LIGHT, HouseKit.CHANDELIER_RANGE, HouseKit.CHANDELIER_BRIGHTNESS, flicker)
		return
	end
	box(m, "LampCord", V(0.1, 3.2, 0.1), at(0, CLEAR - 1.6, 0), Color3.fromRGB(20, 20, 20), Enum.Material.SmoothPlastic, false)
	local theme = HouseDecor.THEMES[room.id]
	if not theme.stone then
		local shade = box(m, "LampShade", V(1, 2.4, 2.4), at(0, CLEAR - 4, 0) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(70, 52, 36), Enum.Material.Fabric, false)
		shade.Shape = Enum.PartType.Cylinder
	end
	local bulb = box(m, "Bulb", V(0.6, 0.6, 0.6), at(0, CLEAR - 4.6, 0), Color3.fromRGB(255, 170, 90), Enum.Material.Neon, false)
	bulb.Shape = Enum.PartType.Ball
	light(bulb, WARM_LIGHT, HouseKit.LAMP_RANGE, HouseKit.LAMP_BRIGHTNESS, flicker)
end

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
			box(door, "Panel", V(w / 2 - 0.9, h - 2.6, 0.12), cf * CFrame.new(sx * (w / 4), 0, sz * 0.28), WOOD, Enum.Material.Wood, false)
		end
		for _, y in { -1.2, 1.6 } do
			box(door, "Bar", V(w - 0.8, 0.35, 0.18), cf * CFrame.new(0, y, sz * 0.3), HouseKit.METAL, Enum.Material.Metal, false)
		end
		for _, sx in { -1, 1 } do
			box(door, "Handle", V(0.3, 1.2, 0.3), cf * CFrame.new(sx * 0.6, -0.2, sz * 0.5), HouseKit.BRASS, Enum.Material.Metal, false)
		end
	end
	local anchor = box(door, "DoorPrompt", V(0.5, 0.5, 0.5), cf * CFrame.new(0, -1.5, -1.2), Color3.new(1, 1, 1), Enum.Material.SmoothPlastic, false)
	anchor.Transparency = 1
	anchor.CanQuery = false
	door.PrimaryPart = slab
	door.WorldPivot = cf
	door.Parent = m
	-- a heavy stone frame around it
	local frameCF = cf * CFrame.new(0, -h / 2, 0)
	for _, sx in { -1, 1 } do
		box(m, "DoorFrame", V(0.8, h + 0.4, 1.4), frameCF * CFrame.new(sx * (w / 2 + 0.4), h / 2, 0), Color3.fromRGB(90, 76, 64), Enum.Material.Sandstone, false)
	end
	box(m, "DoorFrame", V(w + 2, 0.8, 1.4), frameCF * CFrame.new(0, h + 0.4, 0), Color3.fromRGB(90, 76, 64), Enum.Material.Sandstone, false)
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
	local STONE_COLOR = Color3.fromRGB(150, 128, 108)
	box(m, "Plinth", V(7.5, 1.4, 7.5), at(0, 0.7, 0), Color3.fromRGB(110, 92, 78), Enum.Material.Sandstone)
	box(m, "Plinth2", V(6, 1.2, 6), at(0, 2, 0), Color3.fromRGB(120, 100, 84), Enum.Material.Sandstone)
	local column = box(m, "Column", V(26.4, 4.4, 4.4), at(0, 15.8, 0) * CFrame.Angles(0, 0, math.pi / 2), STONE_COLOR, Enum.Material.Sandstone)
	column.Shape = Enum.PartType.Cylinder
	box(m, "Capital", V(6, 1.4, 6), at(0, CLEAR * 2 - 1.2, 0), Color3.fromRGB(110, 92, 78), Enum.Material.Sandstone)
	-- the carved face looking at the front door: pale, hollow-eyed
	local head = box(m, "Face", V(3.4, 3.4, 3.4), at(0, 12, 2.2), Color3.fromRGB(205, 190, 170), Enum.Material.Limestone, false)
	head.Shape = Enum.PartType.Ball
	for _, sx in { -1, 1 } do
		local eye = box(m, "Eye", V(0.7, 1.5, 0.5), at(sx * 0.85, 12.3, 3.7), Color3.fromRGB(4, 3, 3), Enum.Material.SmoothPlastic, false)
		eye.Shape = Enum.PartType.Ball
	end
	local mouth = box(m, "Mouth", V(0.8, 1.7, 0.5), at(0, 10.9, 3.7), Color3.fromRGB(4, 3, 3), Enum.Material.SmoothPlastic, false)
	mouth.Shape = Enum.PartType.Ball -- a long, open scream

	-- the altar
	local altar = origin + HouseDecor.ALTAR_POS
	local function onAltar(x, y, z)
		return CFrame.new(altar + V(x, y, z))
	end
	box(m, "AltarBase", V(6.4, 1.8, 2.8), onAltar(0, 0.9, 0), Color3.fromRGB(82, 68, 60), Enum.Material.Granite)
	box(m, "AltarTop", V(7, 0.4, 3.4), onAltar(0, 2, 0), Color3.fromRGB(110, 94, 82), Enum.Material.Granite)
	for i = 1, HouseDecor.SOCKETS do
		local socket = box(m, "Socket" .. i, V(1.0, 0.25, 1.0), onAltar(-2.55 + (i - 1) * 1.7, 2.3, 0), Color3.fromRGB(32, 34, 40), Enum.Material.Metal, false)
		socket:SetAttribute("Filled", false)
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

-- One Model per room inside `shell`. (Walls, floors, stairs and doors are made by HouseBuilder.)
function HouseDecor.decorate(shell: Instance, graph, origin: Vector3, segments)
	for _, room in graph.rooms do
		local theme = HouseDecor.THEMES[room.id]
		local m = Instance.new("Model")
		m.Name = "Room " .. theme.name
		for _, seg in segments do
			if seg.a == room.id or seg.b == room.id then
				finishFace(m, origin, seg, room, theme)
				if seg.b == nil and seg.entrance then
					frontDoor(m, origin, seg)
				elseif seg.b == nil and room.level >= 0 and seg.hi - seg.lo >= 12 then
					windowOn(m, origin, seg, room)
				end
			end
		end
		ceilingLight(m, origin, room)
		m.Parent = shell
	end
	hallCentre(shell, origin)
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
