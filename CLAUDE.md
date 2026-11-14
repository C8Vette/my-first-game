# my-first-game (Roblox)

Beginner Roblox project. Code is Luau, kept on disk and synced into Roblox Studio with Rojo.

## Layout
- `src/server` → ServerScriptService.Server (server scripts, `*.server.luau`)
- `src/client` → StarterPlayer.StarterPlayerScripts.Client (client scripts, `*.client.luau`)
- `src/shared` → ReplicatedStorage.Shared (ModuleScripts used by both, plain `*.luau`)
- `default.project.json` is the Rojo map from folders to the Studio tree.

## Workflow
- `rojo serve` while Studio is open, then click Connect in the Rojo plugin; edits to files sync live.
- Edit code here on disk, not in Studio, or Rojo will overwrite Studio edits.
- The Roblox Studio MCP server is connected: use it to inspect the place, playtest, and read console output to check changes.
- Before finishing a change: `stylua src` then `selene src`.

## Rules
- Never trust the client: validate everything that arrives through RemoteEvents/RemoteFunctions on the server.
- Explain changes in plain language; the developer is new to Roblox.
