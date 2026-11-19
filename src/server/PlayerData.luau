-- Each player's progress, kept on the server: the only copy that can be trusted.
-- The client sees copies (leaderstats and attributes on the Player) but can never change these.
--
-- Saving: progress is loaded from a Roblox DataStore when a player joins and saved when they
-- leave, on a timer, and when the server shuts down. If loading ever fails we let the player
-- play on a fresh profile but DO NOT save over their real one, so a bad moment can't wipe them.
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Notify = require(script.Parent.Notify)

export type Data = {
	credits: number,
	drill: number, -- which entry in Config.Drills the player owns
	pack: number, -- which entry in Config.Packs the player owns
	zonesUnlocked: number, -- zones 1 up to this number are open
	cargo: { [string]: number }, -- ore name -> how many the player is carrying
}

local PlayerData = {}

-- Bump this name if you ever change the save format in a breaking way; old saves stay untouched
-- under the old name.
local SAVE_VERSION = 1
local AUTOSAVE_INTERVAL = 120 -- seconds between background saves

-- DataStores only work once the place is published to Roblox (and API access is enabled). In an
-- unpublished place GetDataStore even throws, so we try it safely: if it fails, `store` stays nil,
-- the game runs normally, and saving is simply switched off until the place is published.
local store: DataStore? = nil
do
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore("PlayerSave_v1")
	end)
	if ok then
		store = result
	else
		warn(`[PlayerData] Saving is off (publish the place and enable API access to turn it on): {result}`)
	end
end

local dataByPlayer: { [Player]: Data } = {}
local noSave: { [Player]: boolean } = {} -- players whose save failed to load; never write their key

local function defaultData(): Data
	return {
		credits = 0,
		drill = 1,
		pack = 1,
		zonesUnlocked = 1,
		cargo = {},
	}
end

-- Rebuild a clean Data from whatever came out of the store, keeping only valid values.
-- This guards against corrupted saves and makes old saves safe when Config changes.
local function sanitize(raw: any): Data
	local data = defaultData()
	if type(raw) == "table" then
		if type(raw.credits) == "number" and raw.credits == raw.credits then
			data.credits = math.max(0, math.floor(raw.credits))
		end
		if type(raw.drill) == "number" then
			data.drill = math.clamp(math.floor(raw.drill), 1, #Config.Drills)
		end
		if type(raw.pack) == "number" then
			data.pack = math.clamp(math.floor(raw.pack), 1, #Config.Packs)
		end
		if type(raw.zonesUnlocked) == "number" then
			data.zonesUnlocked = math.clamp(math.floor(raw.zonesUnlocked), 1, #Config.Zones)
		end
		if type(raw.cargo) == "table" then
			for ore, amount in raw.cargo do
				if type(ore) == "string" and type(amount) == "number" and amount > 0 then
					data.cargo[ore] = math.floor(amount)
				end
			end
		end
	end
	return data
end

function PlayerData.get(player: Player): Data?
	return dataByPlayer[player]
end

-- Yields until the player's save has loaded (or they leave / it times out). Other systems call
-- this so they never read progress before it exists.
function PlayerData.waitForData(player: Player, timeout: number?): Data?
	local deadline = os.clock() + (timeout or 15)
	while not dataByPlayer[player] and player.Parent and os.clock() < deadline do
		task.wait(0.1)
	end
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

local function keyFor(player: Player): string
	return `Player_{player.UserId}`
end

-- Read the save, retrying a few times for transient errors. Returns a Data on success (including
-- a fresh default for a brand-new player, where the store holds nothing), or nil if it truly failed.
local function loadData(player: Player): Data?
	if not store then
		return nil -- saving is off; caller gives the player a fresh profile that won't be saved
	end
	for attempt = 1, 3 do
		local ok, result = pcall(function()
			return store:GetAsync(keyFor(player))
		end)
		if ok then
			return sanitize(result)
		end
		warn(`[PlayerData] load attempt {attempt} failed for {player.Name}: {result}`)
		task.wait(attempt)
	end
	return nil
end

-- Write the save, retrying a few times. Skips players whose load failed so we never overwrite a
-- real save with a fresh profile.
local function saveData(player: Player): boolean
	local data = dataByPlayer[player]
	if not store or not data or noSave[player] then
		return false
	end
	local payload = {
		version = SAVE_VERSION,
		credits = data.credits,
		drill = data.drill,
		pack = data.pack,
		zonesUnlocked = data.zonesUnlocked,
		cargo = data.cargo,
	}
	for attempt = 1, 3 do
		local ok, err = pcall(function()
			store:SetAsync(keyFor(player), payload)
		end)
		if ok then
			return true
		end
		warn(`[PlayerData] save attempt {attempt} failed for {player.Name}: {err}`)
		task.wait(attempt)
	end
	return false
end

local function onPlayerAdded(player: Player)
	local data = loadData(player)
	if not data then
		-- Couldn't reach the store. Let them play, but don't save over their real profile.
		data = defaultData()
		noSave[player] = true
		task.delay(5, function()
			if player.Parent then
				Notify.send(player, "Couldn't load your save - progress won't be saved this session.", "error")
			end
		end)
	end

	if not player.Parent then
		return -- player left while we were loading
	end
	dataByPlayer[player] = data

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

local function onPlayerRemoving(player: Player)
	saveData(player)
	dataByPlayer[player] = nil
	noSave[player] = nil
end

function PlayerData.start()
	Players.PlayerAdded:Connect(function(player)
		task.spawn(onPlayerAdded, player)
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
	Players.PlayerRemoving:Connect(onPlayerRemoving)

	-- Background autosave so a crash loses at most a couple of minutes of progress.
	task.spawn(function()
		while true do
			task.wait(AUTOSAVE_INTERVAL)
			for _, player in Players:GetPlayers() do
				task.spawn(saveData, player)
			end
		end
	end)

	-- Last-chance save when the server shuts down. BindToClose holds the server open briefly
	-- so these saves can finish.
	game:BindToClose(function()
		for _, player in Players:GetPlayers() do
			task.spawn(saveData, player)
		end
		task.wait(3)
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
