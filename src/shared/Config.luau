-- All the numbers that shape the game live here, so balancing is just editing this file.
-- Shared by the server (which enforces them) and the client (which only displays them).
local Config = {}

-- How often a player can hit with their drill, and how close they must be (in studs).
Config.MineCooldown = 0.35
Config.MineRange = 12

-- Drills: each tier hits harder. Tier 1 is free; the rest are bought in order.
Config.Drills = {
	{ name = "Rusty Drill", power = 1, cost = 0, color = Color3.fromRGB(150, 110, 80) },
	{ name = "Twin Drill", power = 2, cost = 40, color = Color3.fromRGB(180, 180, 190) },
	{ name = "Plasma Drill", power = 4, cost = 200, color = Color3.fromRGB(80, 200, 255) },
	{ name = "Fusion Drill", power = 8, cost = 900, color = Color3.fromRGB(255, 140, 40) },
	{ name = "Quantum Drill", power = 16, cost = 3500, color = Color3.fromRGB(190, 90, 255) },
}

-- Cargo packs: how much ore you can carry before you have to go sell.
Config.Packs = {
	{ name = "Pocket Pouch", capacity = 15, cost = 0 },
	{ name = "Cargo Crate", capacity = 40, cost = 60 },
	{ name = "Hauler Pack", capacity = 100, cost = 300 },
	{ name = "Freighter Pod", capacity = 250, cost = 1200 },
	{ name = "Star Vault", capacity = 600, cost = 4000 },
}

-- Zones, in unlock order. Zone 1 is free. Later zones cost credits to unlock and have
-- tougher asteroids that drop more valuable ore.
Config.Zones = {
	{
		name = "Dusty Belt",
		unlockCost = 0,
		ore = "Space Rock",
		oreValue = 1, -- credits per ore when sold
		asteroidHealth = 3,
		orePerAsteroid = 1,
		asteroidCount = 14,
		respawnTime = 4,
		color = Color3.fromRGB(140, 120, 100),
		floorColor = Color3.fromRGB(70, 65, 60),
	},
	{
		name = "Frost Rings",
		unlockCost = 250,
		ore = "Frost Crystal",
		oreValue = 4,
		asteroidHealth = 10,
		orePerAsteroid = 2,
		asteroidCount = 14,
		respawnTime = 5,
		color = Color3.fromRGB(150, 220, 255),
		floorColor = Color3.fromRGB(60, 80, 110),
	},
	{
		name = "Ember Nebula",
		unlockCost = 2500,
		ore = "Ember Core",
		oreValue = 15,
		asteroidHealth = 30,
		orePerAsteroid = 3,
		asteroidCount = 14,
		respawnTime = 6,
		color = Color3.fromRGB(255, 110, 60),
		floorColor = Color3.fromRGB(90, 40, 35),
	},
}

return Config
