--!nonstrict
-- Coins and items. Everything is decided here; clients may only ask to Buy(itemId) or
-- UseItem(itemId), and every request is checked (phase, price, stock, cooldown, downed).
--
-- Player attributes (read by the HUD): Coins, Inv_<itemId> (count), AdrenalineUntil (server time)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("NightHunter")
local HouseGraph = require(Shared:WaitForChild("HouseGraph"))
local Items = require(Shared:WaitForChild("Items"))

local USE_COOLDOWN = 0.5
local THROW_DISTANCE = 18

local Economy = {}

local function inventoryKey(itemId: string): string
	return "Inv_" .. itemId
end

-- ctx = { house, hunter, phase: () -> string, isDowned: (Player) -> boolean }
function Economy.start(ctx)
	local house = ctx.house
	local remotes = ReplicatedStorage:FindFirstChild("NightHunterRemotes") or Instance.new("Folder")
	remotes.Name = "NightHunterRemotes"
	local buyRemote = Instance.new("RemoteEvent")
	buyRemote.Name = "Buy"
	buyRemote.Parent = remotes
	local useRemote = Instance.new("RemoteEvent")
	useRemote.Name = "UseItem"
	useRemote.Parent = remotes
	remotes.Parent = ReplicatedStorage

	local lastUse = {}
	local econ = {}

	local function resetPlayer(player: Player)
		player:SetAttribute("Coins", 0)
		player:SetAttribute("AdrenalineUntil", 0)
		for _, id in Items.order do
			player:SetAttribute(inventoryKey(id), 0)
		end
	end

	function econ.addCoins(player: Player, amount: number)
		player:SetAttribute("Coins", (player:GetAttribute("Coins") or 0) + amount)
	end

	-- A new run (night 1): everyone starts broke with empty pockets.
	function econ.resetRun()
		for _, player in Players:GetPlayers() do
			resetPlayer(player)
		end
	end

	-- Throw a noise maker ahead of the player; it clatters where it lands.
	local function throwDecoy(player: Player, root: BasePart)
		local flat = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
		if flat.Magnitude < 1e-3 then
			flat = Vector3.new(0, 0, -1)
		end
		local target = root.Position + flat.Unit * THROW_DISTANCE
		local localPos = target - house.origin
		local half = HouseGraph.ROOM_SIZE / 2 - 1
		local maxX = (HouseGraph.COLS - 1) * HouseGraph.ROOM_SIZE + half
		local maxZ = (HouseGraph.ROWS - 1) * HouseGraph.ROOM_SIZE + half
		localPos = Vector3.new(math.clamp(localPos.X, -half, maxX), 0, math.clamp(localPos.Z, -half, maxZ))
		local room = HouseGraph.roomAt(localPos)
		if not room then
			return
		end
		local landing = house.origin + localPos + Vector3.new(0, 0.3, 0)

		local can = Instance.new("Part")
		can.Name = "NoiseMaker"
		can.Size = Vector3.new(0.6, 0.9, 0.6)
		can.Color = Color3.fromRGB(150, 140, 120)
		can.Material = Enum.Material.Metal
		can.Anchored = true
		can.CanCollide = false
		can.CanQuery = false
		can.Position = root.Position + Vector3.new(0, 1, 0)
		can.Parent = house.root
		local fly = TweenService:Create(can, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = landing })
		fly.Completed:Once(function()
			ctx.hunter.emitSound(room, landing, "decoy")
			house.ping(room, Color3.fromRGB(170, 90, 255))
			task.delay(4, function()
				can:Destroy()
			end)
		end)
		fly:Play()
	end

	buyRemote.OnServerEvent:Connect(function(player, itemId)
		local item = type(itemId) == "string" and Items.list[itemId]
		if not item or ctx.phase() ~= "Day" then
			return
		end
		local coins = player:GetAttribute("Coins") or 0
		local owned = player:GetAttribute(inventoryKey(itemId)) or 0
		if coins < item.price or owned >= item.max then
			return
		end
		player:SetAttribute("Coins", coins - item.price)
		player:SetAttribute(inventoryKey(itemId), owned + 1)
	end)

	useRemote.OnServerEvent:Connect(function(player, itemId)
		local item = type(itemId) == "string" and Items.list[itemId]
		local now = os.clock()
		if not item or ctx.phase() ~= "Night" or ctx.isDowned(player) or now - (lastUse[player] or 0) < USE_COOLDOWN then
			return
		end
		local owned = player:GetAttribute(inventoryKey(itemId)) or 0
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if owned <= 0 or not root then
			return
		end
		lastUse[player] = now
		if itemId == "decoy" then
			throwDecoy(player, root)
		elseif itemId == "battery" then
			if (player:GetAttribute("Battery") or 1) >= 0.99 then
				return -- full already: keep it
			end
			player:SetAttribute("Battery", 1)
		elseif itemId == "adrenaline" then
			player:SetAttribute("AdrenalineUntil", Workspace:GetServerTimeNow() + Items.ADRENALINE_SECONDS)
		end
		player:SetAttribute(inventoryKey(itemId), owned - 1)
	end)

	Players.PlayerAdded:Connect(resetPlayer)
	for _, player in Players:GetPlayers() do
		resetPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		lastUse[player] = nil
	end)

	return econ
end

return Economy
