--!nonstrict
-- Hiding: wardrobes (doors close behind you, you peek through the gap) and tables with a long
-- cloth (you peek out under it). The hunter is blind, so hiding is about NOT BEING HEARD:
--   entering    makes a sound by how fast you were moving: dive in at a run = the doors slam
--               (heard from the same room, it tells the hunter exactly WHICH spot); walk in =
--               a creak; sneak in = almost silent. So running into a wardrobe right in front of
--               the hunter gets you found.
--   breathing   while the hunter is in your room you breathe audibly (a small chance it hears
--               you each tick) unless you hold your breath (SPACE / BREATH button). Hold it too
--               long and you gasp — loud.
--   searching   the hunter opens a spot when it suspects it enough (its belief there passes a
--               threshold, or it heard the spot). Whoever is inside is caught. The hidden player
--               sees that suspicion as a meter (the hunter's real belief about their spot).
--   leaving     E / LEAVE: a soft creak.
-- One player per spot. A hidden player is invisible, anchored, and their flashlight is off.
--
-- Player attributes: Hidden (node id, 0 = not hidden), HideKind ("wardrobe"|"table"),
--   HideEye (CFrame for the client camera), Breath (0..1), HoldingBreath (bool), Suspicion (0..1)

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("NightHunter")
local Acoustics = require(Shared:WaitForChild("Acoustics"))
local HouseGraph = require(Shared:WaitForChild("HouseGraph"))
local Furniture = require(script.Parent.Furniture)

local TICK = 0.5
local BREATH_SECONDS = 6 -- how long you can hold your breath
local BREATH_RECOVER_SECONDS = 4 -- empty to full while breathing normally
local USE_COOLDOWN = 1
local DOOR_OPEN_DEGREES = 100
-- Entry noise uses the fastest speed of the last moments: you stop at the wardrobe to open it,
-- but you still came in at a run. Recent speed falls by this many studs/s every second.
local SPEED_MEMORY_DECAY = 15

local HideService = {}

-- ctx: { house, hunter (HunterService handle), kit (PlayerKit), isDowned(player), phase(),
--        telemetry? }
function HideService.start(ctx)
	local graph = ctx.house.graph
	local origin = ctx.house.origin
	local hunter = ctx.hunter

	local remotes = ReplicatedStorage:WaitForChild("NightHunterRemotes")
	local function remote(name)
		local r = Instance.new("RemoteEvent")
		r.Name = name
		r.Parent = remotes
		return r
	end
	local unhideRemote = remote("Unhide")
	local breathRemote = remote("HoldBreath")

	local spots = {} -- [node] = { model, kind, room, prompt, occupant, busy }
	local hiddenIn = {} -- [Player] = node
	local saved = {} -- [Player] = { [BasePart] = transparency }
	local lastUse = {}
	local recentSpeed = {} -- [Player] = fastest horizontal speed lately (decays)

	------------------------------------------------------------ animation

	local running = {} -- [Instance] = the tween animating it now (a new one cancels it)

	-- Swing a door model about its hinge (its PrimaryPart) by `degrees` (0 = closed).
	local function swing(door: Model?, degrees: number, seconds: number)
		if not door or not door.PrimaryPart then
			return
		end
		local closed = door:GetAttribute("ClosedPivot")
		if not closed then
			closed = door:GetPivot()
			door:SetAttribute("ClosedPivot", closed)
		end
		if running[door] then
			running[door]:Cancel()
		end
		local value = Instance.new("NumberValue")
		value.Value = door:GetAttribute("Angle") or 0
		value.Changed:Connect(function(a)
			door:PivotTo(closed * CFrame.Angles(0, math.rad(a), 0))
		end)
		value.Changed:Connect(function(a)
			door:SetAttribute("Angle", a)
		end)
		local tween = TweenService:Create(value, TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Value = degrees })
		tween.Completed:Connect(function()
			if running[door] == tween then
				running[door] = nil
			end
			value:Destroy()
		end)
		running[door] = tween
		tween:Play()
	end

	-- Open (true) or close the spot: wardrobe doors swing out; a table's cloth lifts.
	local function setOpen(spot, open: boolean, seconds: number)
		if spot.kind == "table" then
			local cloth = spot.model:FindFirstChild("Cloth", true)
			if cloth then
				local closed = cloth:GetAttribute("ClosedCFrame")
				if not closed then
					closed = cloth.CFrame
					cloth:SetAttribute("ClosedCFrame", closed)
				end
				local goal = if open then closed * CFrame.new(0, 0.9, 0) * CFrame.Angles(math.rad(12), 0, 0) else closed
				if running[cloth] then
					running[cloth]:Cancel()
				end
				local tween = TweenService:Create(cloth, TweenInfo.new(seconds, Enum.EasingStyle.Quad), { CFrame = goal })
				running[cloth] = tween
				tween:Play()
			end
			return
		end
		-- DoorL swings on its left hinge, DoorR on its right; both outward (toward -Z).
		swing(spot.model:FindFirstChild("DoorL"), if open then DOOR_OPEN_DEGREES else 0, seconds)
		swing(spot.model:FindFirstChild("DoorR"), if open then -DOOR_OPEN_DEGREES else 0, seconds)
	end

	local function flap(spot)
		setOpen(spot, true, 0.18)
		task.delay(0.3, function()
			if not spot.searching then
				setOpen(spot, false, 0.3)
			end
		end)
	end

	------------------------------------------------------------ spots

	for _, model in CollectionService:GetTagged(Furniture.HIDE_TAG) do
		if model:IsDescendantOf(ctx.house.root) then
			local node = model:GetAttribute("Node")
			local promptPart = model:FindFirstChild("PromptPart")
			if node and graph.nodes[node] and promptPart then
				local kind = model:GetAttribute("Kind") or "wardrobe"
				local p = Instance.new("ProximityPrompt")
				p.ActionText = "Hide"
				p.ObjectText = if kind == "table" then "Under the table" else "Wardrobe"
				p.HoldDuration = 0
				p.MaxActivationDistance = 6
				p.RequiresLineOfSight = false
				p.Parent = promptPart
				spots[node] = { model = model, kind = kind, room = graph.nodes[node].room, prompt = p, occupant = nil }
			end
		end
	end

	local function partsOf(character: Model)
		local list = {}
		for _, d in character:GetDescendants() do
			if d:IsA("BasePart") or d:IsA("Decal") then
				table.insert(list, d)
			end
		end
		return list
	end

	local function rootOf(player: Player): BasePart?
		return player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	end

	local function setBreath(player: Player, holding: boolean)
		player:SetAttribute("HoldingBreath", holding)
	end

	-- Take a player out of their spot. `quietly` = no creak (caught, night over).
	local function release(player: Player, quietly: boolean?)
		local node = hiddenIn[player]
		if not node then
			return
		end
		local spot = spots[node]
		hiddenIn[player] = nil
		spot.occupant = nil
		spot.prompt.Enabled = true
		player:SetAttribute("Hidden", 0)
		player:SetAttribute("HideKind", "")
		player:SetAttribute("Suspicion", 0)
		setBreath(player, false)

		local character = player.Character
		local root = rootOf(player)
		if character then
			for part, transparency in saved[player] or {} do
				if part.Parent then
					part.Transparency = transparency
				end
			end
		end
		saved[player] = nil
		if root then
			-- Step out in front of the spot (the side the Eye looks out of), facing away from it.
			local pivot = spot.model:GetPivot().Position
			local eye = spot.model.Eye.Position
			local dir = Vector3.new(eye.X - pivot.X, 0, eye.Z - pivot.Z).Unit
			local out = Vector3.new(eye.X, pivot.Y + 3, eye.Z) + dir * 1.8
			root.Anchored = false
			character:PivotTo(CFrame.lookAt(out, out + dir))
		end
		if not quietly then
			flap(spot)
			hunter.emitSound(spot.room, spot.model.PromptPart.Position, "unhide", node)
		end
		if ctx.telemetry then
			ctx.telemetry.event("unhide", player, { node = node })
		end
	end

	local function enter(player: Player, node: number)
		local spot = spots[node]
		local root = rootOf(player)
		local now = os.clock()
		if not spot or spot.occupant or spot.searching or not root or hiddenIn[player] or ctx.isDowned(player) then
			return
		end
		if now - (lastUse[player] or 0) < USE_COOLDOWN or ctx.phase() == "Waiting" then
			return
		end
		lastUse[player] = now

		-- How fast were they moving as they dived in? (physics, not what the client says)
		local stance = Acoustics.stanceFromSpeed(recentSpeed[player] or 0)
		local sound = Acoustics.hideEntry(stance)

		spot.occupant = player
		spot.prompt.Enabled = false
		hiddenIn[player] = node
		ctx.kit.lightOff(player)
		local list = {}
		for _, part in partsOf(player.Character) do
			list[part] = part.Transparency
			part.Transparency = 1
		end
		saved[player] = list
		root.Anchored = true
		player.Character:PivotTo(spot.model.Inside.CFrame)
		player:SetAttribute("Hidden", node)
		player:SetAttribute("HideKind", spot.kind)
		player:SetAttribute("HideEye", spot.model.Eye.CFrame)
		player:SetAttribute("Breath", player:GetAttribute("Breath") or 1)
		setBreath(player, false)

		flap(spot)
		hunter.emitSound(spot.room, spot.model.PromptPart.Position, sound, node)
		if ctx.telemetry then
			ctx.telemetry.event("hide", player, { node = node, sound = sound })
		end
	end

	for node, spot in spots do
		spot.prompt.Triggered:Connect(function(player)
			enter(player, node)
		end)
	end

	unhideRemote.OnServerEvent:Connect(function(player)
		if hiddenIn[player] and os.clock() - (lastUse[player] or 0) >= 0.4 then
			lastUse[player] = os.clock()
			release(player)
		end
	end)

	breathRemote.OnServerEvent:Connect(function(player, holding)
		if type(holding) ~= "boolean" or not hiddenIn[player] then
			return
		end
		if holding and (player:GetAttribute("Breath") or 0) < 0.15 then
			return -- not enough air to hold it again yet
		end
		setBreath(player, holding)
	end)

	------------------------------------------------------------ breathing + suspicion

	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		for _, player in Players:GetPlayers() do
			local root = not hiddenIn[player] and rootOf(player)
			local v = if root then root.AssemblyLinearVelocity else Vector3.zero
			local speed = Vector3.new(v.X, 0, v.Z).Magnitude
			recentSpeed[player] = math.max(speed, (recentSpeed[player] or 0) - SPEED_MEMORY_DECAY * dt)
			if RunService:IsStudio() then
				player:SetAttribute("DebugRecentSpeed", math.round(recentSpeed[player] * 10) / 10)
			end
		end
		acc += dt
		if acc < TICK then
			return
		end
		acc -= TICK
		local hunterRoom = hunter.hunterRoom()
		local awake = hunter.isActive()
		for player, node in hiddenIn do
			local spot = spots[node]
			local breath = player:GetAttribute("Breath") or 1
			local holding = player:GetAttribute("HoldingBreath") == true
			if holding then
				breath -= TICK / BREATH_SECONDS
				if breath <= 0 then
					breath = 0
					setBreath(player, false)
					hunter.emitSound(spot.room, spot.model.Eye.Position, "gasp", node)
					if ctx.telemetry then
						ctx.telemetry.event("gasp", player, { node = node })
					end
				end
			else
				breath = math.min(1, breath + TICK / BREATH_RECOVER_SECONDS)
				if awake and hunterRoom == spot.room then
					hunter.emitSound(spot.room, spot.model.Eye.Position, "breath", node)
				end
			end
			player:SetAttribute("Breath", breath)
			player:SetAttribute("Suspicion", if awake then hunter.suspicionAt(player, node) else 0)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		local node = hiddenIn[player]
		if node then
			spots[node].occupant = nil
			spots[node].prompt.Enabled = true
			hiddenIn[player] = nil
		end
		saved[player] = nil
		lastUse[player] = nil
		recentSpeed[player] = nil
	end)

	------------------------------------------------------------ handle

	local hide = {}

	-- The hunter opens spot `node`. Returns the players found inside (already pulled out).
	function hide.search(node: number): { Player }
		local spot = spots[node]
		if not spot then
			return {}
		end
		spot.searching = true
		setOpen(spot, true, 0.35)
		local found = {}
		if spot.occupant then
			local player = spot.occupant
			release(player, true)
			table.insert(found, player)
		end
		task.delay(1.6, function()
			spot.searching = false
			setOpen(spot, false, 0.5)
		end)
		if ctx.telemetry then
			ctx.telemetry.event("search", found[1], { node = node, found = #found })
		end
		return found
	end

	function hide.isHidden(player: Player): boolean
		return hiddenIn[player] ~= nil
	end

	-- Everyone out (new day, end of the run), without a sound.
	function hide.releaseAll()
		for player in hiddenIn do
			release(player, true)
		end
	end

	function hide.release(player: Player)
		release(player, true)
	end

	return hide
end

return HideService
