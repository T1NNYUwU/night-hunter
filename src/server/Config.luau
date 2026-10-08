--!strict
-- Game-wide settings that change between builds (not per night).
--
-- Backend address and key are NOT kept here (this file is in git). Set them on the place:
--   ServerStorage attribute  TelemetryUrl  e.g. "https://night-hunter-api.example.com"
--   API key:  Roblox secret "nighthunter_api_key" (Game Settings → Security → Secrets),
--             or, for Studio testing only, ServerStorage attribute TelemetryKey.
-- With no URL, telemetry stays in memory and the hunter uses the built-in model.

return {
	-- "story":      the hunter grows smarter across the run (BRAIN_BY_NIGHT below).
	-- "experiment": every run gets ONE random condition for all its nights (playtest A/B);
	--               the condition is recorded in telemetry. Enable with the ServerStorage
	--               attribute HunterMode = "experiment" (no code change needed).
	hunterMode = "story",

	-- Story mode, night 1..7: { brain, useOpponentModel }
	BRAIN_BY_NIGHT = {
		{ "belief", false },
		{ "belief", false },
		{ "pomcp", false },
		{ "pomcp", false },
		{ "pomcp", false },
		{ "pomcp", false },
		{ "pomcp", true }, -- the finale: "it has learned how you move"
	},

	-- Experiment mode conditions (label → brain, useOpponentModel).
	CONDITIONS = {
		{ label = "rule", brain = "rule", model = false },
		{ label = "belief", brain = "belief", model = false },
		{ label = "pomcp", brain = "pomcp", model = false },
		{ label = "pomcp+model", brain = "pomcp", model = true },
	},

	telemetry = {
		maxQueue = 30, -- nights kept in memory while the backend is unreachable
		timeoutRetrySeconds = 60,
	},
}
