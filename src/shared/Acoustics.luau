--!strict
-- The hunter is blind: everything it knows comes from sound. This module is the single
-- source of truth for how loud things are and how far sound carries, shared by the game
-- (HunterService) and the simulator (Sim) so experiments match what players experience.

local Acoustics = {}

-- How loud each kind of sound is (1 = as loud as it gets).
Acoustics.LOUDNESS = {
	sprint = 1.0,
	walk = 0.45,
	crouch = 0.04,
	crate = 1.0, -- prying a supply crate open
	decoy = 1.0,
	revive = 0.6,
	click = 0.15, -- flashlight switch
}

-- How much of a sound survives per room boundary (index = rooms between the sound and the hunter).
Acoustics.FALLOFF = { [0] = 1, [1] = 0.7, [2] = 0.35, [3] = 0.12 }

-- Player movement speeds (studs/s) per stance.
Acoustics.SPEED = { crouch = 6, walk = 12, sprint = 20 }

-- Chance the hunter hears one sound event. `hearing` scales with the night (difficulty).
function Acoustics.hearChance(loudness: number, roomsAway: number, hearing: number): number
	local falloff = Acoustics.FALLOFF[roomsAway] or 0
	return math.clamp(loudness * falloff * hearing, 0, 1)
end

-- Stance from measured horizontal speed: the server trusts physics, not what the client claims.
function Acoustics.stanceFromSpeed(speed: number): string?
	if speed > 15 then
		return "sprint"
	elseif speed > 8 then
		return "walk"
	elseif speed > 1 then
		return "crouch"
	end
	return nil -- standing still is silent
end

return Acoustics
