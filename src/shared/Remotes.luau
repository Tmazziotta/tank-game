--!strict
-- Typed access to the RemoteEvents declared in default.project.json.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local folder = ReplicatedStorage:WaitForChild("Remotes")

return {
	-- client -> server: no arguments; the server decides everything from its own state.
	FireRequest = folder:WaitForChild("FireRequest") :: RemoteEvent,
	-- server -> all clients: (shooter: Player, report: CombatTypes.ShotReport)
	ShotFired = folder:WaitForChild("ShotFired") :: RemoteEvent,
	-- server -> all clients: (report: CombatTypes.DestroyedReport)
	TankDestroyed = folder:WaitForChild("TankDestroyed") :: RemoteEvent,
}
