-- A ModuleScript shared by the server and the client (lives in ReplicatedStorage.Shared).
local Greeting = {}

function Greeting.forPlayer(name: string): string
	return `Welcome to the game, {name}!`
end

return Greeting
