-- Builds the space station hub and every mining zone from code when the server starts.
-- Because the layout lives in this file, it is saved with your project (and git), not in the place.
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local World = {}

local STATION_SIZE = 90
local ZONE_SIZE = 160
local ZONE_SPACING = 400 -- studs between platforms; you travel by launch pad, not on foot

local function makePart(properties: { [string]: any }): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	local anyPart: any = part
	for key, value in properties do
		anyPart[key] = value
	end
	return part
end

-- A floating text label above a part.
local function addLabel(part: BasePart, text: string, color: Color3, height: number)
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(240, 50)
	billboard.StudsOffset = Vector3.new(0, height, 0)
	billboard.MaxDistance = 150

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.2
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.Parent = billboard

	billboard.Parent = part
end

-- The "press E" prompt. The Kind/Zone attributes let the client find it to show prices.
local function addPrompt(part: BasePart, actionText: string, objectText: string, kind: string, zone: number?)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = actionText
	prompt.ObjectText = objectText
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("Kind", kind)
	if zone then
		prompt:SetAttribute("Zone", zone)
	end
	prompt.Parent = part
	return prompt
end

local function setUpSpace()
	Lighting.ClockTime = 0 -- night sky = stars
	Lighting.Brightness = 1
	Lighting.Ambient = Color3.fromRGB(110, 110, 140)
	Lighting.OutdoorAmbient = Color3.fromRGB(110, 110, 140)
	workspace.Gravity = 110 -- normal is 196.2; lower gravity gives floaty space jumps
end

function World.build()
	setUpSpace()

	local root = Instance.new("Folder")
	root.Name = "SpaceWorld"

	-- The station: spawn point, sell kiosk, shops and launch pads.
	local station = Instance.new("Model")
	station.Name = "Station"
	station.Parent = root

	makePart({
		Name = "Floor",
		Size = Vector3.new(STATION_SIZE, 4, STATION_SIZE),
		Position = Vector3.new(0, -2, 0),
		Material = Enum.Material.DiamondPlate,
		Color = Color3.fromRGB(90, 95, 110),
	}).Parent =
		station

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Spawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(10, 1, 10)
	spawn.Position = Vector3.new(0, 0.5, 25)
	spawn.Neutral = true
	spawn.Duration = 0 -- no force field bubble on spawn
	spawn.Material = Enum.Material.Neon
	spawn.Color = Color3.fromRGB(60, 120, 255)
	spawn.Parent = station

	local function makeKiosk(name: string, text: string, color: Color3, position: Vector3): Part
		local kiosk = makePart({
			Name = name,
			Size = Vector3.new(8, 6, 8),
			Position = position,
			Material = Enum.Material.Metal,
			Color = color,
		})
		addLabel(kiosk, text, Color3.new(1, 1, 1), 5)
		kiosk.Parent = station
		return kiosk
	end

	local sellKiosk = makeKiosk("SellKiosk", "SELL ORE", Color3.fromRGB(60, 200, 90), Vector3.new(-28, 3, 5))
	local drillShop = makeKiosk("DrillShop", "DRILLS", Color3.fromRGB(60, 140, 255), Vector3.new(28, 3, -5))
	local packShop = makeKiosk("PackShop", "CARGO PACKS", Color3.fromRGB(255, 150, 50), Vector3.new(28, 3, 15))

	local world = {
		root = root,
		stationArrival = CFrame.new(0, 4, 25),
		sellPrompt = addPrompt(sellKiosk, "Sell Cargo", "Ore Exchange", "Sell"),
		drillPrompt = addPrompt(drillShop, "Upgrade Drill", "Drill Shop", "Drill"),
		packPrompt = addPrompt(packShop, "Upgrade Pack", "Pack Shop", "Pack"),
		launchPrompts = {} :: { ProximityPrompt },
		returnPrompts = {} :: { ProximityPrompt },
		zones = {} :: { { center: Vector3, arrival: CFrame } },
		asteroidFolder = Instance.new("Folder"),
	}

	-- One launch pad on the station and one floating platform per zone.
	local zoneCount = #Config.Zones
	for index, zone in Config.Zones do
		local padX = (index - (zoneCount + 1) / 2) * 18
		local launchPad = makePart({
			Name = `LaunchPad{index}`,
			Size = Vector3.new(10, 1, 10),
			Position = Vector3.new(padX, 0.5, -32),
			Material = Enum.Material.Neon,
			Color = zone.color,
		})
		addLabel(launchPad, zone.name, zone.color, 4)
		launchPad.Parent = station
		world.launchPrompts[index] = addPrompt(launchPad, "Launch", zone.name, "Launch", index)

		local center = Vector3.new(0, 0, -ZONE_SPACING * index)
		local zoneModel = Instance.new("Model")
		zoneModel.Name = `Zone{index}`

		makePart({
			Name = "Floor",
			Size = Vector3.new(ZONE_SIZE, 4, ZONE_SIZE),
			Position = center + Vector3.new(0, -2, 0),
			Material = Enum.Material.Slate,
			Color = zone.floorColor,
		}).Parent =
			zoneModel

		local returnPad = makePart({
			Name = "ReturnPad",
			Size = Vector3.new(10, 1, 10),
			Position = center + Vector3.new(0, 0.5, ZONE_SIZE / 2 - 10),
			Material = Enum.Material.Neon,
			Color = Color3.fromRGB(60, 120, 255),
		})
		addLabel(returnPad, "BACK TO STATION", Color3.new(1, 1, 1), 4)
		returnPad.Parent = zoneModel
		world.returnPrompts[index] = addPrompt(returnPad, "Return", "Station", "Return", index)

		zoneModel.Parent = root
		world.zones[index] = {
			center = center,
			arrival = CFrame.new(center + Vector3.new(0, 4, ZONE_SIZE / 2 - 22)),
		}
	end

	world.asteroidFolder.Name = "Asteroids"
	world.asteroidFolder.Parent = root

	root.Parent = workspace
	return world
end

export type World = typeof(World.build())

return World
