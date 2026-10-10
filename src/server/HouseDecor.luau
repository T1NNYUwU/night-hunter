--!nonstrict
-- The house SHELL's finish: wallpaper and wainscot on every wall face, windows, ceiling and the
-- ceiling light of each room. One Model per room inside the house's "Shell" folder.
--
-- Furniture is NOT here: it lives in Workspace.NightHunterHouse.Furniture (see Furniture.luau),
-- one independent Model per piece, so it can be moved or swapped in Studio and survives a
-- rebuild of the shell. Walls, doorways and doors are built by HouseBuilder.
--
-- Coordinates are room-local: room centre = 0,0,0, floor top = y 0, inner wall faces at ±11.5.

local HouseGraph = require(game:GetService("ReplicatedStorage"):WaitForChild("NightHunter"):WaitForChild("HouseGraph"))
local HouseKit = require(script.Parent.HouseKit)

local box, placer, light = HouseKit.box, HouseKit.placer, HouseKit.light
local WOOD_DARK, WOOD, WOOD_LIGHT = HouseKit.WOOD_DARK, HouseKit.WOOD, HouseKit.WOOD_LIGHT
local DIRTY_WHITE, WARM_LIGHT, MOON_LIGHT = HouseKit.DIRTY_WHITE, HouseKit.WARM_LIGHT, HouseKit.MOON_LIGHT

local HouseDecor = {}
HouseDecor.VERSION = 7 -- bump when the shell finish changes, so a saved shell gets rebuilt

-- Room themes. `noWindow` lists outer walls that get no window (a door, a fireplace, a shelf).
HouseDecor.THEMES = {
	[1] = { name = "Foyer", wall = Color3.fromRGB(78, 62, 58), floor = Color3.fromRGB(70, 66, 62), floorMat = Enum.Material.Marble, noWindow = { W = true } },
	[2] = { name = "Grand Hall", wall = Color3.fromRGB(70, 58, 50), floor = WOOD_DARK, floorMat = Enum.Material.WoodPlanks },
	[3] = { name = "Library", wall = Color3.fromRGB(52, 66, 56), floor = WOOD, floorMat = Enum.Material.WoodPlanks },
	[4] = { name = "Study", wall = Color3.fromRGB(74, 56, 46), floor = WOOD, floorMat = Enum.Material.WoodPlanks, noWindow = { N = true } },
	[5] = { name = "Storeroom", wall = Color3.fromRGB(86, 80, 70), floor = Color3.fromRGB(80, 74, 66), floorMat = Enum.Material.Concrete },
	[6] = { name = "Living Room", wall = Color3.fromRGB(84, 54, 50), floor = WOOD, floorMat = Enum.Material.WoodPlanks },
	[7] = { name = "Gallery", wall = Color3.fromRGB(60, 52, 72), floor = WOOD_DARK, floorMat = Enum.Material.WoodPlanks },
	[8] = { name = "Bedroom", wall = Color3.fromRGB(86, 70, 92), floor = WOOD_LIGHT, floorMat = Enum.Material.WoodPlanks },
	[9] = { name = "Kitchen", wall = Color3.fromRGB(118, 114, 96), floor = Color3.fromRGB(150, 150, 140), floorMat = Enum.Material.Slate },
	[10] = { name = "Dining Room", wall = Color3.fromRGB(70, 52, 70), floor = WOOD, floorMat = Enum.Material.WoodPlanks },
	[11] = { name = "Hallway", wall = Color3.fromRGB(80, 74, 60), floor = WOOD_DARK, floorMat = Enum.Material.WoodPlanks },
	[12] = { name = "Master Bedroom", wall = Color3.fromRGB(64, 50, 72), floor = WOOD_LIGHT, floorMat = Enum.Material.WoodPlanks },
	[13] = { name = "Pantry", wall = Color3.fromRGB(96, 88, 72), floor = Color3.fromRGB(90, 84, 74), floorMat = Enum.Material.Slate, noWindow = { S = true, W = true } },
	[14] = { name = "Servants' Room", wall = Color3.fromRGB(90, 80, 66), floor = WOOD, floorMat = Enum.Material.WoodPlanks },
	[15] = { name = "Nursery", wall = Color3.fromRGB(120, 100, 82), floor = WOOD_LIGHT, floorMat = Enum.Material.WoodPlanks },
	[16] = { name = "Bathroom", wall = Color3.fromRGB(86, 108, 106), floor = Color3.fromRGB(170, 175, 172), floorMat = Enum.Material.Marble },
}

-- Rooms whose light flickers (picked by hand so the house has a rhythm, not noise).
local FLICKER_ROOMS = { [5] = true, [7] = true, [11] = true, [14] = true, [16] = true }
-- Rooms lit by a chandelier instead of a pendant lamp.
local CHANDELIER_ROOMS = { [1] = true, [2] = true, [10] = true }

---------------------------------------------------------------- shell pieces

-- Which wall sides of a room have a door, and which are outer walls.
local function sides(graph, room)
	local cols, rows = HouseGraph.COLS, HouseGraph.ROWS
	local index = room - 1
	local col, row = index % cols, index // cols
	return {
		N = { name = "N", door = row > 0 and HouseGraph.hasDoor(graph, room, room - cols), outer = row == 0, axisX = true, sign = -1 },
		S = { name = "S", door = row < rows - 1 and HouseGraph.hasDoor(graph, room, room + cols), outer = row == rows - 1, axisX = true, sign = 1 },
		W = { name = "W", door = col > 0 and HouseGraph.hasDoor(graph, room, room - 1), outer = col == 0, axisX = false, sign = -1 },
		E = { name = "E", door = col < cols - 1 and HouseGraph.hasDoor(graph, room, room + 1), outer = col == cols - 1, axisX = false, sign = 1 },
	}
end

-- Wallpaper + dark wainscot + rail on every inner face, with a gap where a door is.
local function finishWalls(m, at, theme, side)
	local face = 11.45
	local function strip(name, y, height, depth, color, material)
		local pieces = if side.door then { { -7.5, 9 }, { 7.5, 9 } } else { { 0, 23 } }
		for _, piece in pieces do
			local offset, length = piece[1], piece[2]
			local size = if side.axisX then Vector3.new(length, height, depth) else Vector3.new(depth, height, length)
			local x = if side.axisX then offset else side.sign * face
			local z = if side.axisX then side.sign * face else offset
			box(m, name, size, at(x, y, z), color, material, false)
		end
	end
	strip("Wallpaper", 7.5, 9, 0.1, theme.wall, Enum.Material.Fabric)
	strip("Wainscot", 1.5, 3, 0.25, WOOD_DARK, Enum.Material.Wood)
	strip("Rail", 3.05, 0.2, 0.35, WOOD_LIGHT, Enum.Material.Wood)
end

local function windowOn(m, at, side)
	local face = 11.35
	local x = if side.axisX then 0 else side.sign * face
	local z = if side.axisX then side.sign * face else 0
	local yaw = if side.axisX then 0 else 90
	box(m, "WindowFrame", Vector3.new(5.4, 4.4, 0.3), at(x, 6.5, z, yaw), WOOD_DARK, Enum.Material.Wood, false)
	local glass = box(m, "WindowGlass", Vector3.new(4.6, 3.6, 0.35), at(x, 6.5, z, yaw), Color3.fromRGB(22, 30, 56), Enum.Material.Neon, false)
	glass.Transparency = 0.35
	box(m, "WindowBarV", Vector3.new(0.2, 3.6, 0.4), at(x, 6.5, z, yaw), WOOD_DARK, Enum.Material.Wood, false)
	box(m, "WindowBarH", Vector3.new(4.6, 0.2, 0.4), at(x, 6.5, z, yaw), WOOD_DARK, Enum.Material.Wood, false)
	local beam = Instance.new("SpotLight")
	beam.Color = MOON_LIGHT
	beam.Range = 18
	beam.Brightness = HouseKit.WINDOW_BRIGHTNESS
	beam.Angle = 50
	beam.Face = Enum.NormalId.Front
	beam.Parent = glass
	-- Front of the glass must face into the room.
	glass.CFrame = CFrame.lookAt(glass.Position, glass.Position - (if side.axisX then Vector3.new(0, 0, side.sign) else Vector3.new(side.sign, 0, 0)))
end

-- Ceiling light: a pendant lamp, or (3 grand rooms) the chandelier model.
local function ceilingLight(m, at, room)
	if CHANDELIER_ROOMS[room] then
		local template = HouseKit.libraryModel("Chandelier")
		local h = 6.5
		if template then
			local c = template:Clone()
			c:ScaleTo(c:GetScale() * 0.6)
			c:PivotTo(at(0, 12 - ((template:GetAttribute("Size") or Vector3.new(0, 8.7, 0)).Y * 0.6), 0, 0))
			c.Name = "Chandelier"
			c.Parent = m
			h = (template:GetAttribute("Size") or Vector3.new(0, 8.7, 0)).Y * 0.6
		end
		local glow = box(m, "ChandelierGlow", Vector3.new(0.2, 0.2, 0.2), at(0, 12 - h * 0.5, 0), WARM_LIGHT, Enum.Material.Neon, false)
		glow.Transparency = 1
		light(glow, WARM_LIGHT, 22, HouseKit.CHANDELIER_BRIGHTNESS, FLICKER_ROOMS[room])
		return
	end
	box(m, "LampCord", Vector3.new(0.1, 1.6, 0.1), at(0, 11.2, 0), Color3.fromRGB(20, 20, 20), Enum.Material.SmoothPlastic, false)
	local shade = box(m, "LampShade", Vector3.new(1, 2.4, 2.4), at(0, 10.1, 0) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(70, 52, 36), Enum.Material.Fabric, false)
	shade.Shape = Enum.PartType.Cylinder
	local bulb = box(m, "Bulb", Vector3.new(0.6, 0.6, 0.6), at(0, 9.45, 0), Color3.fromRGB(255, 170, 90), Enum.Material.Neon, false)
	bulb.Shape = Enum.PartType.Ball
	light(bulb, WARM_LIGHT, HouseKit.LAMP_RANGE, HouseKit.LAMP_BRIGHTNESS, FLICKER_ROOMS[room])
end

-- The front door the players escape through (NightCycle looks it up by name).
local function frontDoor(m, at)
	box(m, "FrontDoor", Vector3.new(0.4, 8, 5), at(-11.3, 4, 0), WOOD_DARK, Enum.Material.Wood, false)
	box(m, "DoorKnob", Vector3.new(0.3, 0.3, 0.3), at(-11.05, 4, 1.7), HouseKit.BRASS, Enum.Material.Metal, false)
end

-- One Model per room inside `shell`. (Walls, floors and doors are made by HouseBuilder.)
function HouseDecor.decorate(shell: Instance, graph, origin: Vector3)
	for room = 1, graph.roomCount do
		local theme = HouseDecor.THEMES[room]
		local at = placer(origin + HouseGraph.roomCenter(room))
		local m = Instance.new("Model")
		m.Name = "Room " .. theme.name
		local s = sides(graph, room)
		for _, key in { "N", "S", "E", "W" } do
			finishWalls(m, at, theme, s[key])
			if s[key].outer and not (theme.noWindow and theme.noWindow[key]) then
				windowOn(m, at, s[key])
			end
		end
		box(m, "Ceiling", Vector3.new(24, 1, 24), at(0, 12.5, 0), Color3.fromRGB(46, 42, 40), Enum.Material.Plaster)
		ceilingLight(m, at, room)
		if room == 1 then
			frontDoor(m, at)
		end
		m.Parent = shell
	end
end

-- The hunter's nest for tonight: candles in a ring, a pile of rags, a red glow.
function HouseDecor.lair(parent: Instance, origin: Vector3, room: number): Instance
	local m = Instance.new("Model")
	m.Name = "Lair"
	local at = placer(origin + HouseGraph.roomCenter(room))
	local rng = Random.new(room)
	for i = 1, 8 do
		local a = (i / 8) * math.pi * 2
		local x, z = math.cos(a) * 4.5, math.sin(a) * 4.5
		box(m, "Candle", Vector3.new(0.3, 0.8, 0.3), at(x, 0.4, z), DIRTY_WHITE, Enum.Material.SmoothPlastic, false)
		box(m, "Flame", Vector3.new(0.15, 0.3, 0.15), at(x, 0.95, z), Color3.fromRGB(255, 170, 70), Enum.Material.Neon, false)
	end
	for _ = 1, 7 do
		box(m, "Rags", Vector3.new(rng:NextNumber(1.5, 3), 0.5, rng:NextNumber(1.5, 3)), at(rng:NextNumber(-1.8, 1.8), 0.25, rng:NextNumber(-1.8, 1.8), rng:NextNumber(0, 180)), Color3.fromRGB(35, 28, 26), Enum.Material.Fabric, false)
	end
	for i = 1, 4 do
		box(m, "Scratch", Vector3.new(0.15, 0.02, 3), at(-2.2 + i * 0.5, 0.07, -6, 15), Color3.fromRGB(90, 20, 20), Enum.Material.SmoothPlastic, false)
	end
	local glow = box(m, "Glow", Vector3.new(0.5, 0.5, 0.5), at(0, 2, 0), Color3.fromRGB(255, 40, 40), Enum.Material.Neon, false)
	glow.Transparency = 1
	light(glow, Color3.fromRGB(255, 50, 40), 18, 1.2, true)
	m.Parent = parent
	return m
end

return HouseDecor
