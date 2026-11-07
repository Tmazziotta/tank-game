--!strict
-- Typed access to the RemoteEvents declared in default.project.json.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local folder = ReplicatedStorage:WaitForChild("Remotes")

return {
	-- client -> server: no arguments; the server decides everything from its own state.
	FireRequest = folder:WaitForChild("FireRequest") :: RemoteEvent,
	-- server -> all clients: (shooter: Player, origin: Vector3, hitPosition: Vector3, didHit: boolean)
	ShotFired = folder:WaitForChild("ShotFired") :: RemoteEvent,
}
