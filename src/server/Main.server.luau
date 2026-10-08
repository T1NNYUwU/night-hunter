local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HouseGraph = require(ReplicatedStorage:WaitForChild("NightHunter"):WaitForChild("HouseGraph"))
local HouseBuilder = require(script.Parent.HouseBuilder)
local NightCycle = require(script.Parent.NightCycle)

local graph = HouseGraph.build()
local house = HouseBuilder.ensure(graph)
house.graph = graph
NightCycle.start(house)
