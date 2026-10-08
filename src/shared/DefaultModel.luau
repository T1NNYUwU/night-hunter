--!strict
-- The starter OpponentModel shipped with the game, used until the backend has fitted one
-- from real players. Fitted in the simulator (2026-10-08) from 54,003 steps of the four bot
-- policies (hider, collector, wanderer, decoy; seeds 5001-5040 each) with OpponentModel.fit.
-- "side" never happens in this house (a grid: neighbouring rooms are always one step closer
-- or farther from the hunter), so it keeps its prior value.
-- Reading it: with the hunter ONE room away (room1), players hide 21% of ticks and move away
-- 29%; in the hunter's own room (room0) they mostly flee (away 49%).

return {
	kind = "learned",
	version = "sim-mix-2026-10-08",
	samples = 54003,
	weights = {
		room0 = { stay = 0.4962, toward = 0.1400, away = 0.4932, side = 0.1400, hide = 0.0071, unhide = 0.0000 },
		room1 = { stay = 0.4079, toward = 0.0902, away = 0.2913, side = 0.1400, hide = 0.2113, unhide = 0.0000 },
		room2 = { stay = 0.7746, toward = 0.1021, away = 0.1183, side = 0.1400, hide = 0.0180, unhide = 0.0000 },
		room3 = { stay = 0.7346, toward = 0.1642, away = 0.0947, side = 0.1400, hide = 0.0313, unhide = 0.0000 },
		hide0 = { stay = 0.9995, toward = 0.0000, away = 0.0000, side = 0.0000, hide = 0.0000, unhide = 0.0005 },
		hide1 = { stay = 0.9998, toward = 0.0000, away = 0.0000, side = 0.0000, hide = 0.0000, unhide = 0.0002 },
		hide2 = { stay = 0.9512, toward = 0.0000, away = 0.0000, side = 0.0000, hide = 0.0000, unhide = 0.0488 },
		hide3 = { stay = 0.9760, toward = 0.0000, away = 0.0000, side = 0.0000, hide = 0.0000, unhide = 0.0240 },
	},
}
