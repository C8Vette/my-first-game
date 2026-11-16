-- Each player's progress, kept on the server: the only copy that can be trusted.
-- The client sees copies (leaderstats and attributes on the Player) but can never change these.
-- Note: progress is not saved between sessions yet; that comes later with DataStores.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Config = require(ReplicatedStorage.Shared.Config)

export type Data = {
	credits: number,
	drill: number, -- which entry in Config.Drills the player owns
	pack: number, -- which entry in Config.Packs the player owns
	zonesUnlocked: number, -- zones 1 up to this number are open
	cargo: { [string]: number }, -- ore name -> how many the player is carrying
}

local PlayerData = {}

local dataByPlayer: { [Player]: Data } = {}

function PlayerData.get(player: Player): Data?
	return dataByPlayer[player]
end

function PlayerData.cargoTotal(data: Data): number
	local total = 0
	for _, amount in data.cargo do
		total += amount
	end
	return total
end

function PlayerData.capacity(data: Data): number
	return Config.Packs[data.pack].capacity
end

-- Copy the server's numbers to where the client can read them. Call this after every change.
function PlayerData.publish(player: Player)
	local data = dataByPlayer[player]
	if not data then
		return
	end
	local cargo = PlayerData.cargoTotal(data)

	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		local creditsValue = leaderstats:FindFirstChild("Credits") :: IntValue
		local cargoValue = leaderstats:FindFirstChild("Cargo") :: IntValue
		creditsValue.Value = data.credits
		cargoValue.Value = cargo
	end

	player:SetAttribute("Credits", data.credits)
	player:SetAttribute("Cargo", cargo)
	player:SetAttribute("Capacity", PlayerData.capacity(data))
	player:SetAttribute("Drill", data.drill)
	player:SetAttribute("Pack", data.pack)
	player:SetAttribute("ZonesUnlocked", data.zonesUnlocked)
end

local function onPlayerAdded(player: Player)
	dataByPlayer[player] = {
		credits = 0,
		drill = 1,
		pack = 1,
		zonesUnlocked = 1,
		cargo = {},
	}

	-- "leaderstats" is a special folder name: Roblox shows its values in the player list.
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	for _, statName in { "Credits", "Cargo" } do
		local value = Instance.new("IntValue")
		value.Name = statName
		value.Parent = leaderstats
	end
	leaderstats.Parent = player

	PlayerData.publish(player)
end

function PlayerData.start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		dataByPlayer[player] = nil
	end)

	-- Testing helper, only created inside Studio (never in the real game). During a playtest,
	-- switch the command bar to Server and run:
	--   game.ServerStorage.DevGiveCredits:Invoke(game.Players:GetPlayers()[1], 500)
	if RunService:IsStudio() then
		local giveCredits = Instance.new("BindableFunction")
		giveCredits.Name = "DevGiveCredits"
		giveCredits.OnInvoke = function(player: Player, amount: number)
			local data = dataByPlayer[player]
			if not data then
				return nil
			end
			data.credits += amount
			PlayerData.publish(player)
			return data.credits
		end
		giveCredits.Parent = ServerStorage
	end
end

return PlayerData
