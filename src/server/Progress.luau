--!nonstrict
-- Saved per-player progress (DataStore): the furthest night reached and how many times they
-- escaped. Shown on the title screen through the BestNight / Escapes player attributes.
-- If DataStores are unavailable (e.g. Studio without "Enable Studio Access to API Services"),
-- the game still runs; progress is just not saved, and one warning is printed.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local STORE_NAME = "NightHunterProgress_v1"

local Progress = {}

local store = nil
local warned = false

local function getStore()
	if store == nil then
		local ok, result = pcall(function()
			return DataStoreService:GetDataStore(STORE_NAME)
		end)
		store = if ok then result else false
	end
	return store or nil
end

local function warnOnce(err)
	if not warned then
		warned = true
		warn("[NightHunter] Progress is not being saved: " .. tostring(err))
	end
end

local function keyFor(player: Player): string
	return "u_" .. player.UserId
end

local function apply(player: Player, data)
	player:SetAttribute("BestNight", data.bestNight or 0)
	player:SetAttribute("Escapes", data.escapes or 0)
end

function Progress.load(player: Player)
	apply(player, {})
	local ds = getStore()
	if not ds then
		return
	end
	task.spawn(function()
		local ok, data = pcall(function()
			return ds:GetAsync(keyFor(player))
		end)
		if ok and type(data) == "table" and player.Parent then
			apply(player, data)
		elseif not ok then
			warnOnce(data)
		end
	end)
end

-- Record a finished run for everyone in the server: `nightReached` = the night they got to,
-- `escaped` = they beat night 7.
function Progress.recordRun(nightReached: number, escaped: boolean)
	local ds = getStore()
	for _, player in Players:GetPlayers() do
		local best = math.max(player:GetAttribute("BestNight") or 0, nightReached)
		local escapes = (player:GetAttribute("Escapes") or 0) + (if escaped then 1 else 0)
		apply(player, { bestNight = best, escapes = escapes })
		if ds then
			task.spawn(function()
				local ok, err = pcall(function()
					ds:UpdateAsync(keyFor(player), function(old)
						old = type(old) == "table" and old or {}
						return {
							bestNight = math.max(old.bestNight or 0, nightReached),
							escapes = (old.escapes or 0) + (if escaped then 1 else 0),
						}
					end)
				end)
				if not ok then
					warnOnce(err)
				end
			end)
		end
	end
end

function Progress.start()
	Players.PlayerAdded:Connect(Progress.load)
	for _, player in Players:GetPlayers() do
		Progress.load(player)
	end
end

return Progress
