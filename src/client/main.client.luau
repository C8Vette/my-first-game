-- Runs on each player's device: draws the HUD, shows messages from the server, and labels
-- the shop prompts with prices. It only *displays* things; every decision happens on the server.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)

local player = Players.LocalPlayer
local notifyEvent = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Notify") :: RemoteEvent

-- HUD layout -----------------------------------------------------------------

local gui = Instance.new("ScreenGui")
gui.Name = "HUD"
gui.ResetOnSpawn = false -- keep the HUD when the character respawns

local panel = Instance.new("Frame")
panel.AnchorPoint = Vector2.new(0, 0.5)
panel.Position = UDim2.new(0, 12, 0.5, 0)
panel.Size = UDim2.fromOffset(260, 0)
panel.AutomaticSize = Enum.AutomaticSize.Y
panel.BackgroundColor3 = Color3.fromRGB(15, 18, 30)
panel.BackgroundTransparency = 0.25
panel.Parent = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = panel

local padding = Instance.new("UIPadding")
padding.PaddingTop = UDim.new(0, 10)
padding.PaddingBottom = UDim.new(0, 10)
padding.PaddingLeft = UDim.new(0, 12)
padding.PaddingRight = UDim.new(0, 12)
padding.Parent = panel

local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 4)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = panel

local rowCount = 0
local function makeRow(textSize: number, color: Color3): TextLabel
	rowCount += 1
	local label = Instance.new("TextLabel")
	label.LayoutOrder = rowCount
	label.Size = UDim2.new(1, 0, 0, 0)
	label.AutomaticSize = Enum.AutomaticSize.Y
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextSize = textSize
	label.TextColor3 = color
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextWrapped = true
	label.Parent = panel
	return label
end

local WHITE = Color3.new(1, 1, 1)
local MUTED = Color3.fromRGB(170, 180, 210)
local GREEN = Color3.fromRGB(110, 240, 130)
local RED = Color3.fromRGB(255, 100, 100)

local creditsLabel = makeRow(22, Color3.fromRGB(255, 220, 90))
local cargoLabel = makeRow(18, WHITE)
local drillLabel = makeRow(15, WHITE)
local packLabel = makeRow(15, WHITE)
local goalsLabel = makeRow(13, MUTED)

local toast = Instance.new("TextLabel")
toast.AnchorPoint = Vector2.new(0.5, 1)
toast.Position = UDim2.new(0.5, 0, 1, -120)
toast.Size = UDim2.fromOffset(600, 40)
toast.BackgroundTransparency = 1
toast.Font = Enum.Font.GothamBold
toast.TextSize = 26
toast.TextStrokeTransparency = 0.3
toast.TextTransparency = 1
toast.Parent = gui

gui.Parent = player:WaitForChild("PlayerGui")

-- Keeping the HUD up to date --------------------------------------------------

local function stat(name: string): number
	return player:GetAttribute(name) or 1
end

-- Prompts are shared by everyone, but changing their text here only changes it on this
-- player's screen, so each player sees their own next price.
local function updatePrompt(prompt: ProximityPrompt)
	local kind = prompt:GetAttribute("Kind")
	if kind == "Drill" then
		local nextDrill = Config.Drills[stat("Drill") + 1]
		prompt.ActionText = if nextDrill then `Buy {nextDrill.name} ({nextDrill.cost})` else "Max drill"
	elseif kind == "Pack" then
		local nextPack = Config.Packs[stat("Pack") + 1]
		prompt.ActionText = if nextPack then `Buy {nextPack.name} ({nextPack.cost})` else "Max pack"
	elseif kind == "Launch" then
		local zoneIndex = prompt:GetAttribute("Zone") :: number
		local unlocked = stat("ZonesUnlocked")
		if zoneIndex <= unlocked then
			prompt.ActionText = "Launch"
		elseif zoneIndex == unlocked + 1 then
			prompt.ActionText = `Unlock ({Config.Zones[zoneIndex].unlockCost} credits)`
		else
			prompt.ActionText = "Locked"
		end
	end
end

local trackedPrompts: { [ProximityPrompt]: boolean } = {}

local function track(instance: Instance)
	if instance:IsA("ProximityPrompt") and instance:GetAttribute("Kind") then
		trackedPrompts[instance] = true
		updatePrompt(instance)
	end
end

local function refresh()
	local credits = player:GetAttribute("Credits") or 0
	local cargo = player:GetAttribute("Cargo") or 0
	local capacity = player:GetAttribute("Capacity") or 0
	local drill = Config.Drills[stat("Drill")]
	local pack = Config.Packs[stat("Pack")]

	creditsLabel.Text = `Credits: {credits}`
	cargoLabel.Text = if cargo >= capacity then `Cargo: {cargo} / {capacity}  FULL` else `Cargo: {cargo} / {capacity}`
	cargoLabel.TextColor3 = if cargo >= capacity then RED else WHITE
	drillLabel.Text = `Drill: {drill.name} (power {drill.power})`
	packLabel.Text = `Pack: {pack.name}`

	local goals = {}
	local nextDrill = Config.Drills[stat("Drill") + 1]
	if nextDrill then
		table.insert(goals, `Next drill: {nextDrill.name} - {nextDrill.cost}`)
	end
	local nextPack = Config.Packs[stat("Pack") + 1]
	if nextPack then
		table.insert(goals, `Next pack: {nextPack.name} - {nextPack.cost}`)
	end
	local nextZone = Config.Zones[stat("ZonesUnlocked") + 1]
	if nextZone then
		table.insert(goals, `Next zone: {nextZone.name} - {nextZone.unlockCost}`)
	end
	goalsLabel.Text = table.concat(goals, "\n")

	for prompt in trackedPrompts do
		if prompt.Parent then
			updatePrompt(prompt)
		else
			trackedPrompts[prompt] = nil
		end
	end
end

for _, attribute in { "Credits", "Cargo", "Capacity", "Drill", "Pack", "ZonesUnlocked" } do
	player:GetAttributeChangedSignal(attribute):Connect(refresh)
end

-- Parts far away load in later (streaming), so catch prompts as they arrive.
workspace.DescendantAdded:Connect(track)
for _, instance in workspace:GetDescendants() do
	track(instance)
end
refresh()

-- Messages from the server ----------------------------------------------------

local toastVersion = 0
notifyEvent.OnClientEvent:Connect(function(message: string, kind: string?)
	toastVersion += 1
	local myVersion = toastVersion
	toast.Text = message
	toast.TextColor3 = if kind == "gain" then GREEN elseif kind == "error" then RED else WHITE
	toast.TextTransparency = 0
	toast.TextStrokeTransparency = 0.3
	task.delay(1.8, function()
		-- Only fade if no newer message replaced this one in the meantime.
		if myVersion == toastVersion then
			local fade = TweenInfo.new(0.5)
			TweenService:Create(toast, fade, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		end
	end)
end)
