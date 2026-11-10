--!strict
-- Tank lifecycle: one tank per player, spawned with their character at their team's side
-- of the map, player seated as driver and given network ownership of the tank so driving
-- is responsive. When the driver dies (usually because the tank ran out of health) the
-- tank becomes a burning wreck that lingers briefly. There is no automatic respawn:
-- MatchService loads characters at the start of each round. While frozen (pre-round),
-- hulls are anchored on the server so nobody can move early; turrets still turn.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Combatant = require(script.Parent.Combatant)
local Config = require(ReplicatedStorage.Shared.Config)
local MapService = require(script.Parent.MapService)
local TeamInfo = require(ReplicatedStorage.Shared.TeamInfo)
local TeamService = require(script.Parent.TeamService)
local TankBuilder = require(script.Parent.TankBuilder)
local TankHealth = require(script.Parent.TankHealth)
local PlayerData = require(script.Parent.PlayerData)
local PlayerDataTypes = require(ReplicatedStorage.Shared.PlayerDataTypes)
local TankCatalog = require(ReplicatedStorage.Shared.TankCatalog)
local TankSchema = require(ReplicatedStorage.Shared.TankSchema)

-- position is nil if the hull fell out of the world.
export type DestroyedHandler = (victim: Combatant.Combatant, killer: Combatant.Combatant?, position: Vector3?) -> ()

type Record = {
	tank: TankBuilder.Tank,
	owner: Player?, -- the driving player; nil for bots and dummies
	combatant: Combatant.Combatant,
}

local TankService = {}

local NEUTRAL_COLOR = Color3.fromRGB(200, 200, 210)
local WRECK_COLOR = Color3.fromRGB(38, 36, 40)

local tanks: { [Player]: TankBuilder.Tank } = {}
local records: { [Model]: Record } = {}
local destroyedHandlers: { DestroyedHandler } = {}
local rng = Random.new()
local frozen = false

local function folder(name: string): Folder
	local existing = workspace:FindFirstChild(name)
	if existing and existing:IsA("Folder") then
		return existing
	end
	local created = Instance.new("Folder")
	created.Name = name
	created.Parent = workspace
	return created
end

-- The spawn point on the team's side farthest from every live tank, so teammates spread out.
local function chooseSpawn(team: string?): CFrame
	local map = MapService.current()
	local spawnPoints = map.sides[if team then TeamService.sideOf(team) else 1]
	local best = spawnPoints[rng:NextInteger(1, #spawnPoints)]
	local bestDistance = -math.huge
	for _, spawnPoint in spawnPoints do
		local nearest = math.huge
		for _, record in records do
			if record.tank.hull.Parent then
				nearest = math.min(nearest, (record.tank.hull.Position - spawnPoint.Position).Magnitude)
			end
		end
		-- Small jitter breaks ties (e.g. an empty arena) randomly.
		nearest += rng:NextNumber(0, 5)
		if nearest > bestDistance then
			best = spawnPoint
			bestDistance = nearest
		end
	end
	return best
end

local function colorFor(team: string?): Color3
	return if team then TeamInfo.color(team) else NEUTRAL_COLOR
end

-- Remove a tank without a wreck (player left, round reset).
local function despawn(player: Player)
	local tank = tanks[player]
	if tank then
		tanks[player] = nil
		records[tank.model] = nil
		TankHealth.unregister(tank.model)
		tank.model:Destroy()
	end
end

local function giveOwnership(tank: TankBuilder.Tank, owner: Player?)
	if tank.hull.Anchored then
		return -- anchored assemblies have no network owner; handed over on unfreeze
	end
	for _, part in { tank.hull, tank.turret, tank.barrel } do
		if part.Parent and part:CanSetNetworkOwnership() then
			part:SetNetworkOwner(owner)
		end
	end
end

local function burn(hull: BasePart)
	local fire = Instance.new("Fire")
	fire.Size = 8
	fire.Heat = 12
	fire.Parent = hull
	local smoke = Instance.new("Smoke")
	smoke.Color = Color3.fromRGB(40, 40, 45)
	smoke.Opacity = 0.4
	smoke.RiseVelocity = 8
	smoke.Size = 4
	smoke.Parent = hull
end

-- Turn a live tank into a burning wreck and announce its destruction.
local function wreck(tank: TankBuilder.Tank)
	local model = tank.model
	local record = records[model]
	if not record then
		return
	end
	records[model] = nil
	local owner = record.owner
	if owner and tanks[owner] == tank then
		tanks[owner] = nil
	end
	local killer = TankHealth.killerOf(model)
	TankHealth.unregister(model)
	model:SetAttribute(TankSchema.HealthAttribute, 0)

	local hull = tank.hull
	local position = if hull.Parent then hull.Position else nil
	model.Parent = folder(TankSchema.WrecksFolder)

	if position then
		-- Server takes the physics back so the driver's client can't keep driving it.
		tank.hull.Anchored = false
		giveOwnership(tank, nil)
		tank.drive.Enabled = false
		tank.steer.Enabled = false
		tank.upright.Enabled = false
		tank.barrelHinge.ActuatorType = Enum.ActuatorType.None
		tank.hinge:Destroy() -- the turret pops off
		tank.turret.CanCollide = true
		tank.barrel.CanCollide = true

		for _, descendant in model:GetDescendants() do
			if descendant:IsA("BasePart") then
				descendant.Color = descendant.Color:Lerp(WRECK_COLOR, 0.75)
				if descendant.Material == Enum.Material.Neon then
					descendant.Material = Enum.Material.SmoothPlastic
				end
			end
		end
		burn(hull)

		local up = hull.CFrame.UpVector
		local spin = Vector3.new(rng:NextNumber(-1, 1), 0, rng:NextNumber(-1, 1))
		hull:ApplyImpulse(up * Config.Respawn.WreckLaunchSpeed * hull.AssemblyMass)
		hull:ApplyAngularImpulse(spin * 3 * hull.AssemblyMass)
		local sideways = Vector3.new(rng:NextNumber(-1, 1), 0, rng:NextNumber(-1, 1)) * 12
		tank.turret:ApplyImpulse((Vector3.yAxis * Config.Respawn.TurretPopSpeed + sideways) * tank.turret.AssemblyMass)
	end

	task.delay(Config.Respawn.WreckLifetime, function()
		model:Destroy()
	end)

	for _, handler in destroyedHandlers do
		task.spawn(handler, record.combatant, killer, position)
	end
end

-- Seat with retries: Sit can silently fail if called the instant a character spawns.
local function seatDriver(tank: TankBuilder.Tank, humanoid: Humanoid): boolean
	for _ = 1, 10 do
		if tank.seat.Occupant == humanoid then
			return true
		end
		if humanoid.Health <= 0 or not tank.model.Parent then
			return false
		end
		tank.seat:Sit(humanoid)
		task.wait(0.2)
	end
	return tank.seat.Occupant == humanoid
end

local function buildTank(
	spawnCFrame: CFrame,
	color: Color3,
	tankId: string,
	upgrades: PlayerDataTypes.UpgradeLevels?,
	name: string,
	combatant: Combatant.Combatant,
	owner: Player?
): TankBuilder.Tank
	local tank = TankBuilder.build(spawnCFrame, color, tankId, upgrades)
	tank.model.Name = name
	if combatant.team then
		tank.model:SetAttribute(TeamInfo.Attribute, combatant.team)
	end
	if owner then
		tank.model:SetAttribute(TankSchema.OwnerAttribute, owner.UserId)
	end
	TankHealth.register(tank.model, tank.spec.MaxHealth, Config.Combat.SpawnProtection)
	records[tank.model] = { tank = tank, owner = owner, combatant = combatant }
	tank.model.Parent = folder(TankSchema.TanksFolder)
	-- Assembly mass is only right once the welds are live in the workspace.
	TankBuilder.sizeForces(tank)
	return tank
end

local function spawnTank(player: Player, character: Model)
	despawn(player)
	-- The tank (and its upgrades) come from saved data, so wait for it to load.
	local data = PlayerData.waitFor(player)
	if not data or player.Character ~= character then
		return
	end
	local combatant = Combatant.forPlayer(player)
	if not combatant.team then
		return -- not on a team: spectating
	end

	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	character:WaitForChild("HumanoidRootPart")
	-- No jumping: jumping is how a seated humanoid leaves its seat.
	humanoid.UseJumpPower = true
	humanoid.JumpPower = 0

	local tankId = TankCatalog.normalize(data.SelectedTank)
	local upgrades = PlayerData.upgradesFor(data, tankId)
	local tank = buildTank(chooseSpawn(combatant.team), colorFor(combatant.team), tankId, upgrades, "Tank_" .. player.Name, combatant, player)
	tanks[player] = tank

	if not seatDriver(tank, humanoid) then
		warn(`[TankService] could not seat {player.Name}`)
	end
	TankBuilder.sizeForces(tank)
	-- Anchor only after sizing forces: an anchored assembly's mass isn't meaningful.
	tank.hull.Anchored = frozen
	giveOwnership(tank, player)

	-- If the driver gets knocked out of the seat, put them back.
	tank.seat:GetPropertyChangedSignal("Occupant"):Connect(function()
		if tank.seat.Occupant == nil and tanks[player] == tank and humanoid.Health > 0 then
			task.delay(0.3, function()
				if tanks[player] == tank and humanoid.Health > 0 and seatDriver(tank, humanoid) then
					giveOwnership(tank, player)
				end
			end)
		end
	end)

	humanoid.Died:Connect(function()
		if tanks[player] == tank then
			wreck(tank)
		end
	end)
end

-- Out of health: kill the driver (whose death wrecks the tank) or wreck it directly.
local function onDepleted(model: Model, _killer: Combatant.Combatant?)
	local record = records[model]
	if not record then
		return
	end
	local owner = record.owner
	local character = owner and owner.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.Health > 0 and humanoid.SeatPart == record.tank.seat then
		humanoid.Health = 0
	end
	-- Covers drivers who were already out of their seat or dead.
	wreck(record.tank)
end

function TankService.getTank(player: Player): TankBuilder.Tank?
	return tanks[player]
end

-- Live tank (and its owner) for a tank model.
function TankService.getByModel(model: Model): (TankBuilder.Tank?, Player?)
	local record = records[model]
	if record then
		return record.tank, record.owner
	end
	return nil, nil
end

-- Who is fighting in a live tank model.
function TankService.combatantOf(model: Model): Combatant.Combatant?
	local record = records[model]
	return if record then record.combatant else nil
end

-- Pre-round freeze: anchor every live hull (and any spawned while frozen) so nothing
-- moves; on release, drivers get their network ownership back.
function TankService.setFrozen(on: boolean)
	frozen = on
	for _, record in records do
		local tank = record.tank
		if tank.hull.Parent then
			tank.hull.Anchored = on
			if not on then
				giveOwnership(tank, record.owner)
			end
		end
	end
end

function TankService.onDestroyed(handler: DestroyedHandler)
	table.insert(destroyedHandlers, handler)
end

-- Remove every wreck immediately (round reset).
function TankService.clearWrecks()
	folder(TankSchema.WrecksFolder):ClearAllChildren()
end

-- Every live tank with who is fighting in it.
function TankService.liveTanks(): { { tank: TankBuilder.Tank, combatant: Combatant.Combatant } }
	local list = {}
	for _, record in records do
		table.insert(list, { tank = record.tank, combatant = record.combatant })
	end
	return list
end

-- An AI-driven tank at its team's side. The server simulates it (no network owner).
function TankService.spawnBot(combatant: Combatant.Combatant, tankId: string): TankBuilder.Tank
	local tank = buildTank(chooseSpawn(combatant.team), colorFor(combatant.team), TankCatalog.normalize(tankId), nil, combatant.name, combatant, nil)
	tank.hull.Anchored = frozen
	giveOwnership(tank, nil)
	return tank
end

-- Remove a live tank without a wreck or a death (e.g. a bot being respawned for a new round).
function TankService.remove(model: Model)
	local record = records[model]
	if record then
		records[model] = nil
		TankHealth.unregister(model)
	end
	model:Destroy()
end

-- Studio testing: an ownerless, undriven tank to shoot at.
function TankService.spawnDummy(spawnCFrame: CFrame): Model
	local tank = buildTank(spawnCFrame, NEUTRAL_COLOR, Config.DefaultTank, nil, "Dummy", Combatant.bot("Dummy"), nil)
	giveOwnership(tank, nil)
	TankHealth.endProtection(tank.model)
	return tank.model
end

local function onPlayerAdded(player: Player)
	player.CharacterAdded:Connect(function(character)
		spawnTank(player, character)
	end)
	if player.Character then
		task.spawn(spawnTank, player, player.Character)
	end
end

-- Remove every player's tank without wrecks (match/round reset).
function TankService.despawnAll()
	for _, player in Players:GetPlayers() do
		despawn(player)
	end
end

function TankService.start()
	-- Characters (and so tanks) are loaded by MatchService each round; no auto-respawn.
	Players.CharacterAutoLoads = false
	TankHealth.onDepleted(onDepleted)
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(despawn)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
end

return TankService
