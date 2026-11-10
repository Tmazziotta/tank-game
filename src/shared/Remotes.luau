--!strict
-- Typed access to the RemoteEvents declared in default.project.json.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local folder = ReplicatedStorage:WaitForChild("Remotes")

return {
	-- client -> server: no arguments; the server decides everything from its own state.
	FireRequest = folder:WaitForChild("FireRequest") :: RemoteEvent,
	-- server -> all clients: (shooter: Player? (nil for bots), launch: CombatTypes.ShellLaunch)
	ShellFired = folder:WaitForChild("ShellFired") :: RemoteEvent,
	-- server -> all clients, when a shell lands: (shooter: Player?, report: CombatTypes.ShotReport)
	ShotFired = folder:WaitForChild("ShotFired") :: RemoteEvent,
	-- client -> server: (action: "Buy" | "Upgrade" | "Select", tankId: string, track: string?)
	-- returns (ok: boolean, message: string?). Validated against saved data and Config.
	GarageRequest = folder:WaitForChild("GarageRequest") :: RemoteFunction,
	-- server -> one client: (data: PlayerDataTypes.Data) whenever their saved data changes
	ProfileSync = folder:WaitForChild("ProfileSync") :: RemoteEvent,
	-- client -> server: no arguments; asks for a ProfileSync (sent once the client listens)
	ProfileRequest = folder:WaitForChild("ProfileRequest") :: RemoteEvent,
	-- server -> one client: ({reason: string, coins: number, xp: number, levelUp: number?})
	Reward = folder:WaitForChild("Reward") :: RemoteEvent,
	-- server -> all clients: (report: CombatTypes.DestroyedReport)
	TankDestroyed = folder:WaitForChild("TankDestroyed") :: RemoteEvent,
	-- server -> all clients: (kind: "Mine" | "Sink", position: Vector3) for effects
	HazardEvent = folder:WaitForChild("HazardEvent") :: RemoteEvent,
}
