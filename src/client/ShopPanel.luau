--!nonstrict
-- Day-time shop: one row per item with price, what it does, how many you carry, and BUY.
-- Opened with V (or the SHOP button); only usable during the day, closes itself at night.
-- Its buttons are Modal, so the mouse is free while it is open (the game is first person).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Items = require(ReplicatedStorage:WaitForChild("NightHunter"):WaitForChild("Items"))

local ShopPanel = {}

function ShopPanel.mount(gui: ScreenGui, state: Instance, player: Player, remotes: Folder)
	local panel = Instance.new("Frame")
	panel.Name = "Shop"
	panel.Size = UDim2.fromOffset(340, 74 + #Items.order * 84)
	panel.AnchorPoint = Vector2.new(1, 0.5)
	panel.Position = UDim2.new(1, -16, 0.5, 0)
	panel.BackgroundColor3 = Color3.fromRGB(16, 12, 14)
	panel.BackgroundTransparency = 0.1
	panel.Visible = false
	panel.ZIndex = 10
	panel.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = panel

	local header = Instance.new("TextLabel")
	header.BackgroundTransparency = 1
	header.Size = UDim2.new(1, -20, 0, 34)
	header.Position = UDim2.fromOffset(10, 8)
	header.Font = Enum.Font.GothamBold
	header.TextSize = 20
	header.TextColor3 = Color3.fromRGB(255, 220, 150)
	header.TextXAlignment = Enum.TextXAlignment.Left
	header.ZIndex = 11
	header.Parent = panel

	local close = Instance.new("TextButton")
	close.Size = UDim2.fromOffset(32, 32)
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, -8, 0, 8)
	close.BackgroundColor3 = Color3.fromRGB(60, 40, 40)
	close.TextColor3 = Color3.new(1, 1, 1)
	close.Font = Enum.Font.GothamBold
	close.TextSize = 18
	close.Text = "X"
	close.Modal = true
	close.ZIndex = 11
	close.Parent = panel

	local rows = {}
	for i, id in Items.order do
		local item = Items.list[id]
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, -20, 0, 76)
		row.Position = UDim2.fromOffset(10, 48 + (i - 1) * 84)
		row.BackgroundColor3 = Color3.fromRGB(30, 24, 28)
		row.ZIndex = 11
		row.Parent = panel

		local title = Instance.new("TextLabel")
		title.BackgroundTransparency = 1
		title.Size = UDim2.new(1, -110, 0, 22)
		title.Position = UDim2.fromOffset(8, 4)
		title.Font = Enum.Font.GothamBold
		title.TextSize = 16
		title.TextColor3 = Color3.new(1, 1, 1)
		title.TextXAlignment = Enum.TextXAlignment.Left
		title.ZIndex = 12
		title.Parent = row

		local desc = Instance.new("TextLabel")
		desc.BackgroundTransparency = 1
		desc.Size = UDim2.new(1, -110, 0, 44)
		desc.Position = UDim2.fromOffset(8, 26)
		desc.Font = Enum.Font.Gotham
		desc.TextSize = 12
		desc.TextWrapped = true
		desc.TextColor3 = Color3.fromRGB(190, 185, 180)
		desc.TextXAlignment = Enum.TextXAlignment.Left
		desc.TextYAlignment = Enum.TextYAlignment.Top
		desc.Text = item.desc
		desc.ZIndex = 12
		desc.Parent = row

		local buy = Instance.new("TextButton")
		buy.Size = UDim2.fromOffset(92, 40)
		buy.AnchorPoint = Vector2.new(1, 0.5)
		buy.Position = UDim2.new(1, -8, 0.5, 0)
		buy.BackgroundColor3 = Color3.fromRGB(150, 40, 40)
		buy.TextColor3 = Color3.new(1, 1, 1)
		buy.Font = Enum.Font.GothamBold
		buy.TextSize = 15
		buy.Modal = true
		buy.ZIndex = 12
		buy.Parent = row
		buy.Activated:Connect(function()
			remotes.Buy:FireServer(id)
		end)

		rows[id] = { title = title, buy = buy }
	end

	local open = false
	close.Activated:Connect(function()
		open = false
	end)

	local shop = {}

	function shop.toggle()
		if state:GetAttribute("Phase") == "Day" then
			open = not open
		end
	end

	function shop.update()
		local isDay = state:GetAttribute("Phase") == "Day"
		if not isDay then
			open = false
		end
		panel.Visible = open
		if not open then
			return
		end
		local coins = player:GetAttribute("Coins") or 0
		header.Text = ("SHOP   ·   %d coins"):format(coins)
		for id, row in rows do
			local item = Items.list[id]
			local owned = player:GetAttribute("Inv_" .. id) or 0
			row.title.Text = ("%s  [%s]   %d/%d"):format(item.name, item.key, owned, item.max)
			local canBuy = coins >= item.price and owned < item.max
			row.buy.Text = if owned >= item.max then "FULL" else ("%d c"):format(item.price)
			row.buy.BackgroundColor3 = if canBuy then Color3.fromRGB(150, 40, 40) else Color3.fromRGB(60, 56, 58)
			row.buy.AutoButtonColor = canBuy
		end
	end

	return shop
end

return ShopPanel
