--!nonstrict
-- The doors of the mansion. Every doorway (HouseBuilder) has a Model "Leaf" tagged NightHunterDoor,
-- pivoting on its hinge. Shut, it blocks you; E swings it away from you and it comes to rest nearly flat
-- against the wall, so an open door is never in the way.
--
-- The hunter pushes through any shut door in its path (the creak is your warning). Doors are scenery for
-- the AI: the graph, the belief model and the simulator are unchanged. All doors are shut again each night.

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Sounds = require(game:GetService("ReplicatedStorage"):WaitForChild("NightHunter"):WaitForChild("Sounds"))

local OPEN_ANGLE = math.rad(158)
local SWING_TIME = 0.32
local HUNTER_REACH = 11

local DoorService = {}

local function swing(door, target: number)
	door.target = target
	if door.moving then
		return
	end
	door.moving = true
	door.slab.CanCollide = false
	door.creak:Play()
	task.spawn(function()
		while math.abs(door.angle - door.target) > 1e-3 do
			local dt = RunService.Heartbeat:Wait()
			local step = OPEN_ANGLE * dt / SWING_TIME
			door.angle += math.clamp(door.target - door.angle, -step, step)
			door.leaf:PivotTo(door.hinge * CFrame.Angles(0, door.angle, 0))
		end
		door.moving = false
		door.slab.CanCollide = true
	end)
end

-- Swings away from whoever stands at `from`.
local function open(door, from: Vector3)
	local z = door.hinge:PointToObjectSpace(from).Z
	-- the leaf reaches out along -side (local X), so a yaw of +a takes its tip toward local Z = side
	local away = if z >= 0 then -1 else 1
	door.isOpen = true
	door.prompt.ActionText = "Close"
	swing(door, away * door.side * OPEN_ANGLE)
end

local function close(door)
	door.isOpen = false
	door.prompt.ActionText = "Open"
	swing(door, 0)
end

function DoorService.start(house)
	local doors = {}
	for _, leaf in CollectionService:GetTagged("NightHunterDoor") do
		local promptPart = leaf:IsDescendantOf(house.root) and leaf.Parent:FindFirstChild("DoorPrompt")
		if promptPart then
			local prompt = Instance.new("ProximityPrompt")
			prompt.ActionText = "Open"
			prompt.ObjectText = "Door"
			prompt.KeyboardKeyCode = Enum.KeyCode.E
			prompt.MaxActivationDistance = 9
			prompt.RequiresLineOfSight = false
			prompt.Parent = promptPart
			local creak = Instance.new("Sound")
			creak.Name = "Creak"
			creak.SoundId = Sounds.door
			creak.Volume = 0.9
			creak.RollOffMinDistance = 10
			creak.RollOffMaxDistance = 90
			creak.Parent = promptPart
			local door = {
				leaf = leaf,
				hinge = leaf:GetPivot(),
				slab = leaf:FindFirstChild("Slab"),
				side = leaf:GetAttribute("Side"),
				prompt = prompt,
				creak = creak,
				at = promptPart.Position,
				angle = 0,
				target = 0,
				isOpen = false,
				moving = false,
			}
			prompt.Triggered:Connect(function(player)
				local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
				if door.isOpen then
					close(door)
				elseif root then
					open(door, root.Position)
				end
			end)
			table.insert(doors, door)
		end
	end

	local state = Workspace:WaitForChild("NightHunterState")
	state:GetAttributeChangedSignal("Phase"):Connect(function()
		if state:GetAttribute("Phase") == "Night" then
			for _, door in doors do
				if door.isOpen then
					close(door)
				end
			end
		end
	end)

	-- Now and then at night a shut door near someone swings open on its own, and shuts again.
	task.spawn(function()
		local rng = Random.new()
		while true do
			task.wait(rng:NextNumber(80, 200))
			if state:GetAttribute("Phase") == "Night" and state:GetAttribute("Peace") ~= true then
				local near = {}
				for _, player in game:GetService("Players"):GetPlayers() do
					local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
					for _, door in doors do
						local d = root and (door.at - root.Position).Magnitude
						if d and not door.isOpen and d > 12 and d < 60 then
							table.insert(near, { door = door, from = root.Position })
						end
					end
				end
				local pick = near[1] and near[rng:NextInteger(1, #near)]
				if pick then
					open(pick.door, pick.from)
					task.delay(6, function()
						if pick.door.isOpen then
							close(pick.door)
						end
					end)
				end
			end
		end
	end)

	task.spawn(function()
		while true do
			task.wait(0.15)
			local hunter = house.root:FindFirstChild("Hunter")
			if hunter and (state:GetAttribute("HunterMode") or "asleep") ~= "asleep" then
				local pos = hunter:GetPivot().Position
				for _, door in doors do
					local delta = door.at - pos
					if not door.isOpen and math.abs(delta.Y) < 8 and delta.Magnitude < HUNTER_REACH then
						open(door, pos)
					end
				end
			end
		end
	end)
end

return DoorService
