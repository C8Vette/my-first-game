-- Asteroids and drills. Spawns asteroids in every zone, gives each player a drill, and
-- handles drilling. The client only tells us "I clicked"; the server decides which asteroid
-- is in reach, how much damage it takes and how much ore that earns.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Notify = require(script.Parent.Notify)
local PlayerData = require(script.Parent.PlayerData)
local World = require(script.Parent.World)

local Mining = {}

local random = Random.new()
local asteroidFolder: Folder
local zoneCenters: { Vector3 } = {}
local lastSwing: { [Player]: number } = {}
local lastFullWarning: { [Player]: number } = {}

local function spawnAsteroid(zoneIndex: number)
	local zone = Config.Zones[zoneIndex]
	local center = zoneCenters[zoneIndex]
	local size = random:NextNumber(4, 7)

	local asteroid = Instance.new("Part")
	asteroid.Name = `{zone.ore} Asteroid`
	asteroid.Shape = Enum.PartType.Ball
	asteroid.Size = Vector3.new(size, size, size)
	asteroid.Material = Enum.Material.Slate
	asteroid.Color = zone.color
	asteroid.Anchored = true
	-- Somewhere on the zone platform, hovering a little above the floor.
	asteroid.Position = center + Vector3.new(random:NextNumber(-65, 65), size / 2 + 1, random:NextNumber(-65, 35))
	asteroid:SetAttribute("Zone", zoneIndex)
	asteroid:SetAttribute("Health", zone.asteroidHealth)

	-- A small health bar that appears once the asteroid has been hit.
	local healthBar = Instance.new("BillboardGui")
	healthBar.Name = "HealthBar"
	healthBar.Size = UDim2.fromOffset(80, 10)
	healthBar.StudsOffset = Vector3.new(0, size / 2 + 1.5, 0)
	healthBar.MaxDistance = 60
	healthBar.Enabled = false

	local back = Instance.new("Frame")
	back.Size = UDim2.fromScale(1, 1)
	back.BackgroundColor3 = Color3.new(0, 0, 0)
	back.BackgroundTransparency = 0.3
	back.BorderSizePixel = 0
	back.Parent = healthBar

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Color3.fromRGB(90, 230, 110)
	fill.BorderSizePixel = 0
	fill.Parent = back

	healthBar.Parent = asteroid
	asteroid.Parent = asteroidFolder
end

local function showDamage(asteroid: BasePart, healthFraction: number, color: Color3)
	local healthBar = asteroid:FindFirstChild("HealthBar") :: BillboardGui
	local fill = healthBar:FindFirstChild("Fill", true) :: Frame
	healthBar.Enabled = true
	fill.Size = UDim2.fromScale(healthFraction, 1)

	-- Quick white flash so the hit feels like it landed.
	asteroid.Color = Color3.new(1, 1, 1)
	task.delay(0.08, function()
		if asteroid.Parent then
			asteroid.Color = color
		end
	end)
end

-- The closest asteroid within reach, in a zone this player has unlocked.
local function findTarget(data: PlayerData.Data, rootPart: BasePart): BasePart?
	local best: BasePart? = nil
	local bestDistance = Config.MineRange
	for _, asteroid in asteroidFolder:GetChildren() do
		local zoneIndex = asteroid:GetAttribute("Zone")
		if asteroid:IsA("BasePart") and typeof(zoneIndex) == "number" and zoneIndex <= data.zonesUnlocked then
			-- Measure to the asteroid's surface, not its center, so big ones aren't harder to reach.
			local distance = (asteroid.Position - rootPart.Position).Magnitude - asteroid.Size.X / 2
			if distance <= bestDistance then
				best = asteroid
				bestDistance = distance
			end
		end
	end
	return best
end

local function onDrillUsed(player: Player)
	-- Cooldown: ignore clicks that come faster than the drill allows.
	local now = os.clock()
	if now - (lastSwing[player] or 0) < Config.MineCooldown then
		return
	end
	lastSwing[player] = now

	local data = PlayerData.get(player)
	local character = player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not data or not rootPart or not humanoid or humanoid.Health <= 0 then
		return
	end

	local space = PlayerData.capacity(data) - PlayerData.cargoTotal(data)
	if space <= 0 then
		if now - (lastFullWarning[player] or 0) > 2 then
			lastFullWarning[player] = now
			Notify.send(player, "Cargo full! Sell your ore at the station.", "error")
		end
		return
	end

	local asteroid = findTarget(data, rootPart)
	if not asteroid then
		return
	end

	local zoneIndex = asteroid:GetAttribute("Zone") :: number
	local zone = Config.Zones[zoneIndex]
	local health = (asteroid:GetAttribute("Health") :: number) - Config.Drills[data.drill].power
	if health > 0 then
		asteroid:SetAttribute("Health", health)
		showDamage(asteroid, health / zone.asteroidHealth, zone.color)
		return
	end

	-- Broken! Remove it, schedule a replacement, and pay out ore (up to the free space).
	asteroid:Destroy()
	task.delay(zone.respawnTime, spawnAsteroid, zoneIndex)

	local amount = math.min(zone.orePerAsteroid, space)
	data.cargo[zone.ore] = (data.cargo[zone.ore] or 0) + amount
	PlayerData.publish(player)
	Notify.send(player, `+{amount} {zone.ore}`, "gain")
end

local function styleDrill(tool: Tool, tier: number)
	local drill = Config.Drills[tier]
	tool.Name = drill.name
	tool.ToolTip = `Power {drill.power}`
	local handle = tool:FindFirstChild("Handle") :: BasePart
	handle.Color = drill.color
end

local function giveDrill(player: Player)
	local data = PlayerData.get(player)
	if not data then
		return
	end

	local tool = Instance.new("Tool")
	tool.CanBeDropped = false
	tool:SetAttribute("IsDrill", true)

	local handle = Instance.new("Part")
	handle.Name = "Handle" -- Roblox attaches the part named "Handle" to the character's hand
	handle.Size = Vector3.new(0.8, 0.8, 3)
	handle.Material = Enum.Material.Neon
	handle.CanCollide = false
	handle.Massless = true
	handle.Parent = tool

	styleDrill(tool, data.drill)
	-- Activated fires on the server when the owner clicks with the tool equipped.
	tool.Activated:Connect(function()
		onDrillUsed(player)
	end)
	tool.Parent = player:WaitForChild("Backpack")
end

-- After buying a drill upgrade, update the drill the player already has.
function Mining.refreshDrill(player: Player)
	local data = PlayerData.get(player)
	if not data then
		return
	end
	local function restyleIn(container: Instance?)
		if not container then
			return
		end
		for _, item in container:GetChildren() do
			if item:IsA("Tool") and item:GetAttribute("IsDrill") then
				styleDrill(item, data.drill)
			end
		end
	end
	restyleIn(player:FindFirstChildOfClass("Backpack"))
	restyleIn(player.Character)
end

function Mining.start(world: World.World)
	asteroidFolder = world.asteroidFolder
	for index, zone in world.zones do
		zoneCenters[index] = zone.center
	end
	for index, zone in Config.Zones do
		for _ = 1, zone.asteroidCount do
			spawnAsteroid(index)
		end
	end

	local function onPlayerAdded(player: Player)
		player.CharacterAdded:Connect(function()
			giveDrill(player)
		end)
		if player.Character then
			giveDrill(player)
		end
	end
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		lastSwing[player] = nil
		lastFullWarning[player] = nil
	end)
end

return Mining
