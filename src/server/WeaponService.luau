--!strict
-- Server-authoritative firing. The client only asks to fire; the server checks the
-- cooldown, raycasts from its own copy of the barrel, applies the impact, and tells
-- every client what happened so they can draw it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local TankService = require(script.Parent.TankService)

export type ImpactHandler = (position: Vector3, shooter: Player) -> ()

local WeaponService = {}

local lastFired: { [Player]: number } = {}

local function fire(player: Player, onImpact: ImpactHandler)
	local tank = TankService.getTank(player)
	local character = player.Character
	if not tank or not character then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 or tank.seat.Occupant ~= humanoid then
		return
	end

	local now = os.clock()
	local last = lastFired[player]
	if last and now - last < Config.Weapon.Cooldown then
		return
	end
	lastFired[player] = now

	local muzzle = tank.muzzle.WorldCFrame
	local direction = muzzle.LookVector
	-- Start behind the muzzle so a barrel poking through a wall still hits that wall.
	local rayOrigin = muzzle.Position - direction * Config.Weapon.RayBackOffset

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { tank.model, character }
	local result = workspace:Raycast(rayOrigin, direction * (Config.Weapon.Range + Config.Weapon.RayBackOffset), params)

	local hitPosition = if result then result.Position else muzzle.Position + direction * Config.Weapon.Range
	if result then
		onImpact(hitPosition, player)
	end
	Remotes.ShotFired:FireAllClients(player, muzzle.Position, hitPosition, result ~= nil)
end

function WeaponService.start(onImpact: ImpactHandler)
	-- Any arguments a client sends are ignored on purpose.
	Remotes.FireRequest.OnServerEvent:Connect(function(player: Player)
		fire(player, onImpact)
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastFired[player] = nil
	end)
end

return WeaponService
