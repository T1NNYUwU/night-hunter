--!strict
-- Where might ONE player be? N particles, each a guess (a node id).
--   predict()          guesses drift along the graph like a player could walk
--   observe*()         each guess is re-weighted by how well it explains the evidence
--   resample()         draw a fresh set in proportion to the weights
-- There is no rule like "go to the noise": the hunter only ever reads the resulting belief.

local HouseGraph = require(script.Parent.HouseGraph)
local OpponentModel = require(script.Parent.OpponentModel)

export type Filter = {
	graph: HouseGraph.Graph,
	n: number,
	particles: { number },
	weights: { number },
	rng: Random,
}

local MOVE_PROB_ROOM = 0.35 -- per 0.5 s tick, chance a player standing in a room moves on
local MOVE_PROB_HIDE = 0.08 -- hidden players tend to stay hidden
local MISS_LIKELIHOOD = 0.02 -- "I can see this node and nobody is there"
local INJECT_RATIO = 0.03 -- a few random guesses per tick, so a wrong belief can recover

local ParticleFilter = {}

function ParticleFilter.new(graph: HouseGraph.Graph, n: number, rng: Random, startNode: number?): Filter
	local filter: Filter = { graph = graph, n = n, particles = table.create(n, 0), weights = table.create(n, 1), rng = rng }
	for i = 1, n do
		filter.particles[i] = startNode or rng:NextInteger(1, #graph.nodes)
	end
	return filter
end

function ParticleFilter.reset(filter: Filter, node: number)
	for i = 1, filter.n do
		filter.particles[i] = node
		filter.weights[i] = 1
	end
end

-- `model` (an OpponentModel) and `hunterRoom` are optional: with them, guesses move the way
-- players were seen to move relative to the hunter; without, a fixed random walk.
function ParticleFilter.predict(filter: Filter, model: any?, hunterRoom: number?)
	local graph = filter.graph
	if model and hunterRoom then
		for i = 1, filter.n do
			filter.particles[i] = OpponentModel.step(model, graph, filter.rng, filter.particles[i], hunterRoom)
		end
		return
	end
	for i = 1, filter.n do
		local node = filter.particles[i]
		local moveProb = if graph.nodes[node].kind == "hide" then MOVE_PROB_HIDE else MOVE_PROB_ROOM
		if filter.rng:NextNumber() < moveProb then
			local options = graph.neighbors[node]
			filter.particles[i] = options[filter.rng:NextInteger(1, #options)]
		end
	end
end

-- Negative information: the hunter checked `nodes` and found nobody. `likelihood` is how
-- likely that is if the player WAS there: ~0 for an opened closet, ~0.5 for "listened to
-- this room and heard nothing" (a crouching player can be there and stay silent).
function ParticleFilter.observeNotSeen(filter: Filter, nodes: { [number]: boolean }, likelihood: number?)
	local l = likelihood or MISS_LIKELIHOOD
	for i = 1, filter.n do
		if nodes[filter.particles[i]] then
			filter.weights[i] *= l
		end
	end
end

function ParticleFilter.observeSeen(filter: Filter, node: number)
	ParticleFilter.reset(filter, node)
end

-- A noise was heard in room node `node`. `trust` is how likely the noise really came from
-- this player (another player or a decoy could have made it), so far guesses survive.
function ParticleFilter.observeNoise(filter: Filter, node: number, trust: number)
	local dist = filter.graph.dist[node]
	for i = 1, filter.n do
		local d = dist[filter.particles[i]]
		filter.weights[i] *= (1 - trust) + trust * math.exp(-0.5 * d * d)
	end
end

-- Systematic resampling: one random offset, then evenly spaced picks along the weight line.
function ParticleFilter.resample(filter: Filter)
	local n = filter.n
	local nodeCount = #filter.graph.nodes
	local weights = filter.weights
	local total = 0
	for i = 1, n do
		total += weights[i]
	end
	if total <= 1e-9 then
		-- Every guess was ruled out (e.g. the player teleported): start over from scratch.
		for i = 1, n do
			filter.particles[i] = filter.rng:NextInteger(1, nodeCount)
			weights[i] = 1
		end
		return
	end

	local step = total / n
	local target = filter.rng:NextNumber() * step
	local out = table.create(n, 0)
	local i, acc = 1, weights[1]
	for k = 1, n do
		while acc < target and i < n do
			i += 1
			acc += weights[i]
		end
		out[k] = filter.particles[i]
		target += step
	end
	for _ = 1, math.floor(n * INJECT_RATIO) do
		out[filter.rng:NextInteger(1, n)] = filter.rng:NextInteger(1, nodeCount)
	end
	filter.particles = out
	for k = 1, n do
		weights[k] = 1
	end
end

-- Adds this filter's probability mass per node into `mass` (indexed by node id).
function ParticleFilter.addBelief(filter: Filter, mass: { number })
	local w = 1 / filter.n
	for i = 1, filter.n do
		local node = filter.particles[i]
		mass[node] += w
	end
end

return ParticleFilter
