-- Sends short on-screen messages from the server to one player ("Sold 10 ore", "Cargo full!").
-- This RemoteEvent only goes server -> client, so there is nothing for a cheater to abuse.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local remotes = Instance.new("Folder")
remotes.Name = "Remotes"
remotes.Parent = ReplicatedStorage

local notifyEvent = Instance.new("RemoteEvent")
notifyEvent.Name = "Notify"
notifyEvent.Parent = remotes

local Notify = {}

-- kind is "gain" (green), "error" (red) or nil (white); the client picks the color.
function Notify.send(player: Player, message: string, kind: string?)
	notifyEvent:FireClient(player, message, kind)
end

return Notify
