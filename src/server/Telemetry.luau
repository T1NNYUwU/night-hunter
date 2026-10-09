--!nonstrict
-- Telemetry: one record per night, sent to the backend in a batch when the night ends
-- (HttpService has a per-server request limit, so never one request per event).
--
-- A night record holds:
--   what was played   run id, night, objective, goal, hunter brain/condition, model version
--   how it went       outcome, duration, progress, downs/revives (with time + node), items used
--   trajectories      every 0.5 s: the hunter's room and each player's graph node (0 = not in
--                     play). The backend fits the OpponentModel from these: the hunter learns
--                     how real players move. They are only read AFTER the night, never by the
--                     hunter while hunting, so the hunter still does not cheat.
--   performance       decisions, average / max planning time (ms)
-- Privacy: no user ids or names leave the server. Players are "p1".."p4" within one run.
--
-- With no backend configured (or HttpService disabled) records stay in a small in-memory
-- queue and one warning is printed; the game is unaffected.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")

local Config = require(script.Parent.Config)

local SCHEMA = 1
local SECRET_NAME = "nighthunter_api_key"

local Telemetry = {}

-- status: an Instance that gets TelemetryQueued / TelemetrySent / TelemetryError attributes.
function Telemetry.start(status: Instance?)
	local tel = { queue = {}, sent = 0, lastError = nil }

	local function publish()
		if status then
			status:SetAttribute("TelemetryQueued", #tel.queue)
			status:SetAttribute("TelemetrySent", tel.sent)
			status:SetAttribute("TelemetryError", tel.lastError or "")
		end
	end
	local runId = HttpService:GenerateGUID(false)
	local slots = {} -- [Player] = "p1".. for this run
	local slotCount = 0
	local current = nil
	local startClock = 0
	local warned = false

	local function baseUrl(): string?
		local url = ServerStorage:GetAttribute("TelemetryUrl")
		if type(url) == "string" and url ~= "" then
			return (url:gsub("/+$", ""))
		end
		return nil
	end

	local function apiKey()
		local ok, secret = pcall(function()
			return HttpService:GetSecret(SECRET_NAME)
		end)
		if ok and secret then
			return secret
		end
		local key = ServerStorage:GetAttribute("TelemetryKey")
		return if type(key) == "string" and key ~= "" then key else nil
	end

	local function warnOnce(message: string)
		tel.lastError = message
		if not warned then
			warned = true
			warn("[NightHunter] Telemetry offline (game unaffected): " .. message)
		end
	end

	local function request(method: string, path: string, body: string?)
		local url = baseUrl()
		if not url then
			return false, "no TelemetryUrl set"
		end
		local headers = { ["Content-Type"] = "application/json" }
		local key = apiKey()
		if key then
			headers["X-Api-Key"] = key
		end
		local ok, response = pcall(function()
			return HttpService:RequestAsync({ Url = url .. path, Method = method, Headers = headers, Body = body })
		end)
		if not ok then
			return false, tostring(response)
		elseif not response.Success then
			return false, ("HTTP %d %s"):format(response.StatusCode, response.StatusMessage)
		end
		return true, response.Body
	end

	local function slotOf(player: Player): string
		local slot = slots[player]
		if not slot then
			slotCount += 1
			slot = "p" .. slotCount
			slots[player] = slot
		end
		return slot
	end

	local function elapsed(): number
		return math.round((os.clock() - startClock) * 10) / 10
	end

	function tel.beginRun()
		runId = HttpService:GenerateGUID(false)
		slots, slotCount = {}, 0
	end

	-- info: { night, objective, goal, condition, hunterMode, players }
	function tel.beginNight(info)
		startClock = os.clock()
		current = {
			schema = SCHEMA,
			runId = runId,
			server = if game.JobId ~= "" then game.JobId else "studio",
			placeVersion = game.PlaceVersion,
			startedAt = DateTime.now().UnixTimestamp,
			night = info.night,
			objective = info.objective,
			goal = info.goal,
			condition = info.condition,
			hunterMode = info.hunterMode,
			playersAtStart = #Players:GetPlayers(),
			events = {},
			tickSeconds = 0.5,
			hunterRooms = {},
			trajectories = {}, -- [slot] = { node per tick }
		}
	end

	-- Called by HunterService every 0.5 s (only while the hunter is awake).
	function tel.onTick(sample)
		if not current then
			return
		end
		table.insert(current.hunterRooms, sample.hunterRoom)
		local tick = #current.hunterRooms
		for player, node in sample.nodes do
			local slot = slotOf(player)
			local traj = current.trajectories[slot]
			if not traj then
				traj = table.create(tick - 1, 0) -- joined late: 0 = not in play before
				current.trajectories[slot] = traj
			end
			while #traj < tick - 1 do
				table.insert(traj, 0)
			end
			table.insert(traj, node)
		end
	end

	-- kind: "down" | "revive" | "objective" | "item" | "escape" | "hide" | "unhide" | "gasp" | "search"; data: small table of numbers/strings
	function tel.event(kind: string, player: Player?, data)
		if not current then
			return
		end
		local e = { t = elapsed(), kind = kind, tick = #current.hunterRooms }
		if player then
			e.player = slotOf(player)
		end
		for k, v in data or {} do
			e[k] = v
		end
		table.insert(current.events, e)
	end

	function tel.flush()
		if #tel.queue == 0 then
			return true
		end
		local body = HttpService:JSONEncode({ nights = tel.queue })
		local ok, err = request("POST", "/v1/nights", body)
		if ok then
			tel.sent += #tel.queue
			table.clear(tel.queue)
			tel.lastError = nil
		else
			warnOnce(err)
		end
		publish()
		return ok
	end

	-- result: { outcome = "Win"|"Fail"|"Complete", progress, downs, hunter = HunterService stats() }
	function tel.endNight(result)
		if not current then
			return
		end
		local tick = #current.hunterRooms
		for _, traj in current.trajectories do
			while #traj < tick do
				table.insert(traj, 0) -- left early
			end
		end
		current.outcome = result.outcome
		current.durationS = elapsed()
		current.progress = result.progress
		current.downs = result.downs
		current.hunter = result.hunter
		current.playersAtEnd = #Players:GetPlayers()
		table.insert(tel.queue, current)
		while #tel.queue > Config.telemetry.maxQueue do
			table.remove(tel.queue, 1)
		end
		current = nil
		publish()
		task.spawn(tel.flush)
	end

	-- The latest opponent model the backend fitted from real players (decoded JSON), or nil.
	function tel.fetchModelParams()
		local ok, body = request("GET", "/v1/params/latest", nil)
		if not ok then
			warnOnce(body)
			return nil
		end
		local decoded, params = pcall(function()
			return HttpService:JSONDecode(body)
		end)
		return if decoded then params else nil
	end

	function tel.isConfigured(): boolean
		return baseUrl() ~= nil
	end

	game:BindToClose(function()
		if #tel.queue > 0 then
			tel.flush()
		end
	end)

	return tel
end

return Telemetry
