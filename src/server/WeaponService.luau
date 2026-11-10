--!strict
-- Server-authoritative firing. The client only asks to fire; the server checks the
-- cooldown and launches a shell from its own copy of the barrel. Shells fly (Ballistics:
-- speed + drop), stepped every frame with raycasts; on impact the server resolves armor
-- against any tank hit, applies the blast, and tells every client so they can draw it.
-- ShellFired (launch) lets clients animate the shell; ShotFired (impact) carries the result.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Armor = require(script.Parent.Armor)
local Ballistics = require(ReplicatedStorage.Shared.Ballistics)
local CombatTypes = require(ReplicatedStorage.Shared.CombatTypes)
local Combatant = require(script.Parent.Combatant)
local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local TankBuilder = require(script.Parent.TankBuilder)
local TankHealth = require(script.Parent.TankHealth)
local TankService = require(script.Parent.TankService)

export type ImpactHandler = (position: Vector3, radius: number, shooter: Combatant.Combatant) -> ()

local WeaponService = {}

local lastFired: { [Combatant.Combatant]: number } = setmetatable({}, { __mode = "k" }) :: any
local impactHandler: ImpactHandler? = nil
local enabled = true

type Shell = {
	id: number,
	shooter: Combatant.Combatant,
	origin: Vector3,
	velocity: Vector3, -- at launch
	age: number, -- seconds in flight
	damage: number,
	radius: number,
	params: RaycastParams,
}

local shells: { Shell } = {}
local nextShellId = 0
local land: (shell: Shell, result: RaycastResult, direction: Vector3) -> ()

local function isTurretPart(tank: TankBuilder.Tank, part: BasePart): boolean
	local root = part.AssemblyRootPart
	return root == tank.turret.AssemblyRootPart or root == tank.barrel.AssemblyRootPart
end

-- Resolve a shell striking a tank: armor, ricochet, damage.
local function hitTank(
	report: CombatTypes.ShotReport,
	model: Model,
	part: BasePart,
	direction: Vector3,
	normal: Vector3,
	damage: number,
	shooter: Combatant.Combatant
): boolean
	local tank, owner = TankService.getByModel(model)
	if not tank then
		report.kind = "World"
		return true
	end
	-- Turret plates face where the gun points; everything else faces with the hull.
	local facing = if isTurretPart(tank, part) then tank.muzzle.WorldCFrame.LookVector else tank.hull.CFrame.LookVector
	local result = Armor.evaluate(direction, normal, facing, tank.hull.CFrame.UpVector, damage, tank.spec)
	report.normal = normal
	report.zone = result.zone
	report.victim = owner
	local victim = TankService.combatantOf(model)
	local friendly = victim ~= nil and victim ~= shooter and victim.team ~= nil and victim.team == shooter.team
	if friendly or TankHealth.isProtected(model) then
		report.kind = "Shielded"
		return false
	elseif result.ricochet then
		report.kind = "Ricochet"
		return false
	end
	report.kind = "Hit"
	report.damage = TankHealth.damage(model, result.damage, shooter)
	return true
end

-- A shell struck something: resolve armor against any tank, apply the impact, and tell
-- every client.
function land(shell: Shell, result: RaycastResult, direction: Vector3)
	local report: CombatTypes.ShotReport = {
		id = shell.id,
		origin = shell.origin,
		hit = result.Position,
		kind = "World",
		radius = shell.radius,
	}
	local victim = TankHealth.findTank(result.Instance)
	local part = result.Instance
	local explodes = true
	if victim and part:IsA("BasePart") then
		explodes = hitTank(report, victim, part, direction, result.Normal, shell.damage, shell.shooter)
	end
	local onImpact = impactHandler
	if explodes and onImpact then
		onImpact(report.hit, shell.radius, shell.shooter)
	end
	Remotes.ShotFired:FireAllClients(shell.shooter.player, report)
end

-- Fire `tank`'s gun on behalf of `shooter`, if its reload is done. Returns whether it fired.
function WeaponService.fireFrom(tank: TankBuilder.Tank, shooter: Combatant.Combatant): boolean
	if not enabled then
		return false
	end
	local now = os.clock()
	local last = lastFired[shooter]
	if last and now - last < tank.spec.Cooldown then
		return false
	end
	lastFired[shooter] = now
	-- Shooting gives up spawn protection and commits you to this tank.
	TankHealth.endProtection(tank.model)
	TankHealth.markEngaged(tank.model)

	local muzzle = tank.muzzle.WorldCFrame
	local direction = muzzle.LookVector
	local velocity = Ballistics.launchVelocity(direction)

	-- Shells pass through drivers' bodies and their own tank.
	local exclude: { Instance } = { tank.model }
	for _, other in Players:GetPlayers() do
		if other.Character then
			table.insert(exclude, other.Character)
		end
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = exclude

	nextShellId += 1
	local shell: Shell = {
		id = nextShellId,
		shooter = shooter,
		origin = muzzle.Position,
		velocity = velocity,
		age = 0,
		damage = tank.spec.Damage, -- snapshot: the tank may be gone before the shell lands
		radius = tank.spec.BlastRadius,
		params = params,
	}
	-- First segment starts behind the muzzle so a barrel poking through a wall still hits it.
	local backOrigin = muzzle.Position - direction * Config.Weapon.RayBackOffset
	local result = workspace:Raycast(backOrigin, direction * Config.Weapon.RayBackOffset, params)
	if result then
		land(shell, result, direction)
	else
		table.insert(shells, shell)
	end
	Remotes.ShellFired:FireAllClients(shooter.player, { id = shell.id, origin = shell.origin, velocity = velocity })
	return true
end

-- Advance every shell in flight; resolve the ones that hit something or run out of range.
local function stepShells(dt: number)
	local maxTime = Ballistics.maxFlightTime()
	for i = #shells, 1, -1 do
		local shell = shells[i]
		local from = Ballistics.positionAt(shell.origin, shell.velocity, shell.age)
		shell.age = math.min(shell.age + dt, maxTime)
		local to = Ballistics.positionAt(shell.origin, shell.velocity, shell.age)
		local result = workspace:Raycast(from, to - from, shell.params)
		if result then
			table.remove(shells, i)
			land(shell, result, (to - from).Unit)
		elseif shell.age >= maxTime then
			table.remove(shells, i)
			local report: CombatTypes.ShotReport = {
				id = shell.id,
				origin = shell.origin,
				hit = to,
				kind = "Miss",
				radius = shell.radius,
			}
			Remotes.ShotFired:FireAllClients(shell.shooter.player, report)
		end
	end
end

-- A player asked to fire: only allowed while alive and seated in their own tank.
local function onFireRequest(player: Player)
	local tank = TankService.getTank(player)
	local character = player.Character
	if not tank or not character then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 or tank.seat.Occupant ~= humanoid then
		return
	end
	WeaponService.fireFrom(tank, Combatant.forPlayer(player))
end

-- Pre-round: no one can fire.
function WeaponService.setEnabled(on: boolean)
	enabled = on
end

function WeaponService.start(onImpact: ImpactHandler)
	impactHandler = onImpact
	-- Any arguments a client sends are ignored on purpose.
	Remotes.FireRequest.OnServerEvent:Connect(onFireRequest)
	RunService.Heartbeat:Connect(stepShells)
end

return WeaponService
