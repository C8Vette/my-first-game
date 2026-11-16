-- Runs on the server (ServerScriptService.Server.main). Starts every game system in order.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Greeting = require(ReplicatedStorage.Shared.Greeting)
local Mining = require(script.Parent.Mining)
local PlayerData = require(script.Parent.PlayerData)
local Shop = require(script.Parent.Shop)
local World = require(script.Parent.World)

local world = World.build()
PlayerData.start()
Mining.start(world)
Shop.start(world)

Players.PlayerAdded:Connect(function(player)
	print(Greeting.forPlayer(player.Name))
end)
