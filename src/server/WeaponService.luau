--!strict
-- Server-authoritative firing. The client only asks to fire; the server checks the
-- cooldown, raycasts from its own copy of the barrel, resolves armor against any tank it
-- hits, applies the impact, and tells every client what happened so they can draw it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Armor = require(script.Parent.Armor)
local CombatTypes = require(ReplicatedStorage.Shared.CombatTypes)
local Combatant = require(script.Parent.Combatant)
local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local TankBuilder = require(script.Parent.TankBuilder)
local TankHealth = require(script.Parent.TankHealth)
local TankService = require(script.Parent.TankService)

export type ImpactHandler = (position: Vector3, shooter: Combatant.Combatant) -> ()

local WeaponService = {}

local lastFired: { [Combatant.Combatant]: number } = setmetatable({}, { __mode = "k" }) :: any
local impactHandler: ImpactHandler? = nil

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
	shooter: Combatant.Combatant
): boolean
	local tank, owner = TankService.getByModel(model)
	if not tank then
		report.kind = "World"
		return true
	end
	-- Turret plates face where the gun points; everything else faces with the hull.
	local facing = if isTurretPart(tank, part) then tank.muzzle.WorldCFrame.LookVector else tank.hull.CFrame.LookVector
	local result = Armor.evaluate(direction, normal, facing, tank.hull.CFrame.UpVector)
	report.normal = normal
	report.zone = result.zone
	report.victim = owner
	if TankHealth.isProtected(model) then
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

-- Fire `tank`'s gun on behalf of `shooter`, if its reload is done. Returns whether it fired.
function WeaponService.fireFrom(tank: TankBuilder.Tank, shooter: Combatant.Combatant): boolean
	local now = os.clock()
	local last = lastFired[shooter]
	if last and now - last < Config.Weapon.Cooldown then
		return false
	end
	lastFired[shooter] = now
	-- Shooting gives up spawn protection.
	TankHealth.endProtection(tank.model)

	local muzzle = tank.muzzle.WorldCFrame
	local direction = muzzle.LookVector
	-- Start behind the muzzle so a barrel poking through a wall still hits that wall.
	local rayOrigin = muzzle.Position - direction * Config.Weapon.RayBackOffset

	-- Shells pass through drivers' bodies and strike the tank they sit in.
	local exclude: { Instance } = { tank.model }
	for _, other in Players:GetPlayers() do
		if other.Character then
			table.insert(exclude, other.Character)
		end
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = exclude
	local result = workspace:Raycast(rayOrigin, direction * (Config.Weapon.Range + Config.Weapon.RayBackOffset), params)

	local report: CombatTypes.ShotReport = {
		origin = muzzle.Position,
		hit = if result then result.Position else muzzle.Position + direction * Config.Weapon.Range,
		kind = "Miss",
	}
	if result then
		local victim = TankHealth.findTank(result.Instance)
		local part = result.Instance
		local explodes = true
		if victim and part:IsA("BasePart") then
			explodes = hitTank(report, victim, part, direction, result.Normal, shooter)
		else
			report.kind = "World"
		end
		local onImpact = impactHandler
		if explodes and onImpact then
			onImpact(report.hit, shooter)
		end
	end
	Remotes.ShotFired:FireAllClients(shooter.player, report)
	return true
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

function WeaponService.start(onImpact: ImpactHandler)
	impactHandler = onImpact
	-- Any arguments a client sends are ignored on purpose.
	Remotes.FireRequest.OnServerEvent:Connect(onFireRequest)
end

return WeaponService
