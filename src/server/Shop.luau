-- Station services: selling ore, buying upgrades and travelling between zones.
-- They all work through ProximityPrompts, and the server re-checks everything
-- (distance, prices, unlocks) before doing anything.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Mining = require(script.Parent.Mining)
local Notify = require(script.Parent.Notify)
local PlayerData = require(script.Parent.PlayerData)
local World = require(script.Parent.World)

local Shop = {}

-- Ore name -> credits per ore, built from the zone list.
local oreValues: { [string]: number } = {}
for _, zone in Config.Zones do
	oreValues[zone.ore] = zone.oreValue
end

-- Don't trust that a prompt was really used up close: check the distance ourselves.
local function isNear(player: Player, prompt: ProximityPrompt): boolean
	local character = player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local part = prompt.Parent
	if not rootPart or not part or not part:IsA("BasePart") then
		return false
	end
	return (rootPart.Position - part.Position).Magnitude <= prompt.MaxActivationDistance + 6
end

local function teleport(player: Player, destination: CFrame)
	-- Load the area around the destination first so the player doesn't land before the floor exists.
	pcall(function()
		player:RequestStreamAroundAsync(destination.Position, 3)
	end)
	local character = player.Character
	if character then
		character:PivotTo(destination)
	end
end

local function onPromptUsed(prompt: ProximityPrompt, handler: (Player, PlayerData.Data) -> ())
	prompt.Triggered:Connect(function(player)
		local data = PlayerData.get(player)
		if data and isNear(player, prompt) then
			handler(player, data)
		end
	end)
end

local function sell(player: Player, data: PlayerData.Data)
	local sold, earned = 0, 0
	for ore, amount in data.cargo do
		sold += amount
		earned += amount * (oreValues[ore] or 0)
	end
	if sold == 0 then
		Notify.send(player, "Your cargo is empty. Go drill some asteroids!", "error")
		return
	end
	data.cargo = {}
	data.credits += earned
	PlayerData.publish(player)
	Notify.send(player, `Sold {sold} ore for {earned} credits`, "gain")
end

local function buyDrill(player: Player, data: PlayerData.Data)
	local nextDrill = Config.Drills[data.drill + 1]
	if not nextDrill then
		Notify.send(player, "You already have the best drill!")
		return
	end
	if data.credits < nextDrill.cost then
		Notify.send(player, `{nextDrill.name} costs {nextDrill.cost} credits. You have {data.credits}.`, "error")
		return
	end
	data.credits -= nextDrill.cost
	data.drill += 1
	PlayerData.publish(player)
	Mining.refreshDrill(player)
	Notify.send(player, `Bought the {nextDrill.name}! Power {nextDrill.power}`, "gain")
end

local function buyPack(player: Player, data: PlayerData.Data)
	local nextPack = Config.Packs[data.pack + 1]
	if not nextPack then
		Notify.send(player, "You already have the biggest pack!")
		return
	end
	if data.credits < nextPack.cost then
		Notify.send(player, `{nextPack.name} costs {nextPack.cost} credits. You have {data.credits}.`, "error")
		return
	end
	data.credits -= nextPack.cost
	data.pack += 1
	PlayerData.publish(player)
	Notify.send(player, `Bought the {nextPack.name}! Holds {nextPack.capacity} ore`, "gain")
end

function Shop.start(world: World.World)
	onPromptUsed(world.sellPrompt, sell)
	onPromptUsed(world.drillPrompt, buyDrill)
	onPromptUsed(world.packPrompt, buyPack)

	for index, prompt in world.launchPrompts do
		onPromptUsed(prompt, function(player, data)
			local zone = Config.Zones[index]
			if index > data.zonesUnlocked then
				-- Zones unlock in order, and cost credits.
				if index > data.zonesUnlocked + 1 then
					Notify.send(player, `Unlock {Config.Zones[index - 1].name} first.`, "error")
					return
				end
				if data.credits < zone.unlockCost then
					Notify.send(player, `{zone.name} costs {zone.unlockCost} credits to unlock.`, "error")
					return
				end
				data.credits -= zone.unlockCost
				data.zonesUnlocked = index
				PlayerData.publish(player)
				Notify.send(player, `Unlocked {zone.name}!`, "gain")
			end
			teleport(player, world.zones[index].arrival)
		end)
	end

	for _, prompt in world.returnPrompts do
		onPromptUsed(prompt, function(player)
			teleport(player, world.stationArrival)
		end)
	end
end

return Shop
