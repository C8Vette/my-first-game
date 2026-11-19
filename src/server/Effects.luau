-- Visual and audio feedback for mining. Everything is built from code and Roblox's built-in
-- particle textures (no uploaded assets needed except the two sounds in Config). Effects are
-- created on the server so every nearby player sees and hears them, then cleaned up by Debris.
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)

local Effects = {}

-- A built-in sparkle texture that ships with Roblox, so it always loads.
local SPARK_TEXTURE = "rbxasset://textures/particles/sparkles_main.dds"

-- A tiny invisible part placed at a point to carry a sound and particles for a moment.
local function makeAnchor(position: Vector3, lifetime: number): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Transparency = 1
	part.Size = Vector3.one
	part.CFrame = CFrame.new(position)
	part.Parent = workspace
	Debris:AddItem(part, lifetime)
	return part
end

local function playSound(parent: Instance, soundId: string, volume: number)
	local sound = Instance.new("Sound")
	sound.SoundId = soundId
	sound.Volume = volume
	sound.RollOffMinDistance = 8 -- full volume within 8 studs
	sound.RollOffMaxDistance = 90 -- fades to nothing by 90 studs
	sound.Parent = parent
	sound:Play()
end

local function makeSparks(parent: Instance, color: Color3, maxSize: number): ParticleEmitter
	local sparks = Instance.new("ParticleEmitter")
	sparks.Texture = SPARK_TEXTURE
	sparks.Color = ColorSequence.new(color)
	sparks.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(1, 1), -- fade out over each particle's life
	})
	sparks.Size = NumberSequence.new(maxSize, 0)
	sparks.LightEmission = 0.7
	sparks.Rate = 0 -- no steady stream; we fire one-off bursts with :Emit()
	sparks.SpreadAngle = Vector2.new(180, 180) -- spray in all directions
	sparks.Parent = parent
	return sparks
end

-- A small spark burst and impact sound for a hit that does not break the asteroid.
function Effects.hit(position: Vector3, color: Color3)
	local anchor = makeAnchor(position, 1)
	playSound(anchor, Config.Sounds.hit, 0.5)

	local sparks = makeSparks(anchor, color, 0.3)
	sparks.Lifetime = NumberRange.new(0.2, 0.45)
	sparks.Speed = NumberRange.new(6, 12)
	sparks:Emit(10)
end

-- A bigger debris burst, an expanding flash and a crack sound when an asteroid breaks.
-- `size` is the asteroid's diameter in studs, so the effect scales with the rock.
function Effects.shatter(position: Vector3, color: Color3, size: number)
	local anchor = makeAnchor(position, 2)
	playSound(anchor, Config.Sounds.shatter, 0.7)

	local sparks = makeSparks(anchor, color, size * 0.18)
	sparks.Lifetime = NumberRange.new(0.4, 0.85)
	sparks.Speed = NumberRange.new(10, 24)
	sparks:Emit(26)

	-- A neon ball that quickly swells and fades for a satisfying "pop".
	local flash = Instance.new("Part")
	flash.Shape = Enum.PartType.Ball
	flash.Material = Enum.Material.Neon
	flash.Color = color
	flash.Anchored = true
	flash.CanCollide = false
	flash.CanQuery = false
	flash.CanTouch = false
	flash.Size = Vector3.one * size * 0.6
	flash.CFrame = CFrame.new(position)
	flash.Transparency = 0.2
	flash.Parent = workspace
	Debris:AddItem(flash, 0.5)
	TweenService:Create(flash, TweenInfo.new(0.4), {
		Size = Vector3.one * size * 1.8,
		Transparency = 1,
	}):Play()
end

return Effects
