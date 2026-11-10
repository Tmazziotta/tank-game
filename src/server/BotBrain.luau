--!strict
-- One AI tank's behavior, stepped every server frame. It targets the nearest enemy-team tank
-- (preferring ones in sight), closes to fighting range, then circles at an angle so its
-- armor is angled; backs off when too close; steers around walls; reverses out when stuck;
-- fires when its gun is on target with a clear line of sight, and blasts through walls
-- between it and an unseen target. Deliberately imperfect
-- (reaction delay, aim scatter) so it makes a fair sparring partner.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BuildingGenerator = require(script.Parent.BuildingGenerator)
local Combatant = require(script.Parent.Combatant)
local Config = require(ReplicatedStorage.Shared.Config)
local MapService = require(script.Parent.MapService)
local TankBuilder = require(script.Parent.TankBuilder)
local TankDrive = require(ReplicatedStorage.Shared.TankDrive)
local TankHealth = require(script.Parent.TankHealth)
local TankService = require(script.Parent.TankService)
local WeaponService = require(script.Parent.WeaponService)

export type Brain = {
	tank: TankBuilder.Tank,
	refs: TankDrive.Refs,
	combatant: Combatant.Combatant,
	rng: Random,
	target: Model?,
	targetHull: BasePart?,
	targetVisible: boolean,
	inSightSince: number, -- when the current target came into view (math.huge if not)
	nextRetarget: number,
	orbitSign: number,
	backingOff: boolean,
	nextOrbitFlip: number,
	waypoint: Vector3?,
	stuckFor: number,
	unstickUntil: number,
	unstickTurn: number,
	unstickThrottle: number,
	avoidSide: number, -- 1 = left, -1 = right
	avoidSideUntil: number,
	aimOffset: Vector3,
}

local BotBrain = {}

-- Current decision, mirrored to the tank model for debugging (Studio properties / MCP).
local STATE_ATTRIBUTE = "BotState"

local function setState(brain: Brain, state: string)
	if brain.tank.model:GetAttribute(STATE_ATTRIBUTE) ~= state then
		brain.tank.model:SetAttribute(STATE_ATTRIBUTE, state)
	end
end

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function scatter(rng: Random): Vector3
	local r = Config.Bots.AimScatter
	return Vector3.new(rng:NextNumber(-r, r), rng:NextNumber(-r, r) * 0.5, rng:NextNumber(-r, r))
end

-- Raycast params that ignore this bot's own tank, everyone's character bodies, and
-- crushable props (bots plow through those, and shoot through them).
local function queryParams(brain: Brain): RaycastParams
	local exclude: { Instance } = { brain.tank.model }
	local props = MapService.getPropsFolder()
	if props then
		table.insert(exclude, props)
	end
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(exclude, player.Character)
		end
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = exclude
	return params
end

-- Can the gun see `target`? Ray from the muzzle to its hull must strike the target first.
local function canSee(brain: Brain, target: Model, hull: BasePart, params: RaycastParams): boolean
	local origin = brain.refs.muzzle.WorldPosition
	local result = workspace:Raycast(origin, hull.Position - origin, params)
	return result ~= nil and TankHealth.findTank(result.Instance) == target
end

local function retarget(brain: Brain, now: number, params: RaycastParams)
	local myPosition = brain.tank.hull.Position
	local best: Model?, bestHull: BasePart?, bestVisible = nil, nil, false
	local bestScore = math.huge
	for _, entry in TankService.liveTanks() do
		local hull = entry.tank.hull
		local enemy = brain.combatant.team == nil or entry.combatant.team ~= brain.combatant.team
		if entry.tank ~= brain.tank and enemy and hull.Parent then
			local visible = canSee(brain, entry.tank.model, hull, params)
			local score = (hull.Position - myPosition).Magnitude
			if not visible then
				score += Config.Bots.HiddenTargetPenalty
			end
			if score < bestScore then
				best, bestHull, bestVisible, bestScore = entry.tank.model, hull, visible, score
			end
		end
	end
	if best ~= brain.target then
		brain.target = best
		brain.inSightSince = math.huge
	end
	brain.targetHull = bestHull
	brain.targetVisible = bestVisible
	if bestVisible and brain.inSightSince == math.huge then
		brain.inSightSince = now
	elseif not bestVisible then
		brain.inSightSince = math.huge
	end
end

-- Where to head and how hard: (world heading, throttle).
local function chooseMove(brain: Brain, now: number): (Vector3, number)
	local cfg = Config.Bots
	local hull = brain.tank.hull
	local targetHull = brain.targetHull
	if targetHull and targetHull.Parent then
		local toTarget = flat(targetHull.Position - hull.Position)
		local distance = toTarget.Magnitude
		local dir = if distance > 1e-3 then toTarget.Unit else hull.CFrame.LookVector
		if not brain.targetVisible or distance > cfg.MaxRange then
			setState(brain, "chase")
			return dir, 1
		end
		-- Too close: keep the front plate toward the enemy and back away, until comfortably
		-- clear (hysteresis stops it flickering between backing off and circling).
		if distance < cfg.MinRange or (brain.backingOff and distance < cfg.MinRange + cfg.BackoffMargin) then
			brain.backingOff = true
			setState(brain, "backoff")
			return dir, -0.8
		end
		brain.backingOff = false
		setState(brain, "circle")
		if now >= brain.nextOrbitFlip then
			brain.orbitSign = -brain.orbitSign
			brain.nextOrbitFlip = now + brain.rng:NextNumber(cfg.OrbitFlipMin, cfg.OrbitFlipMax)
		end
		local orbit = CFrame.Angles(0, cfg.OrbitAngle * brain.orbitSign, 0):VectorToWorldSpace(dir)
		return orbit, cfg.CircleThrottle
	end

	-- Nobody to fight: wander between random points around the arena.
	setState(brain, "wander")
	local waypoint = brain.waypoint
	if not waypoint or flat(waypoint - hull.Position).Magnitude < 10 then
		local angle = brain.rng:NextNumber(0, 2 * math.pi)
		local map = MapService.current()
		local radius = brain.rng:NextNumber(0, map.wanderRadius)
		waypoint = map.center + Vector3.new(math.cos(angle), 0, math.sin(angle)) * radius
		brain.waypoint = waypoint
	end
	local toWaypoint = flat((waypoint :: Vector3) - hull.Position)
	return (if toWaypoint.Magnitude > 1e-3 then toWaypoint.Unit else hull.CFrame.LookVector), 0.8
end

-- Steer around walls: try the wanted heading, then progressively wider swerves, favouring
-- the side we last swerved to so the bot follows a wall around instead of dithering.
-- A tank-wide sphere cast stops the hull's edges clipping corners.
local AVOID_ANGLES = { 30, 60, 90, 120, 150 }

local function avoidWalls(brain: Brain, heading: Vector3, throttle: number, now: number, params: RaycastParams): Vector3
	if throttle <= 0 then
		return heading
	end
	local cfg = Config.Bots
	local origin = brain.tank.hull.Position + Vector3.yAxis * 1.5
	local function clear(dir: Vector3): boolean
		return workspace:Spherecast(origin, cfg.AvoidRadius, dir * cfg.AvoidDistance, params) == nil
	end
	if clear(heading) then
		return heading
	end
	local side = if now < brain.avoidSideUntil then brain.avoidSide else (if brain.rng:NextNumber() < 0.5 then -1 else 1)
	for _, degrees in AVOID_ANGLES do
		for _, sign in { side, -side } do
			local dir = CFrame.Angles(0, math.rad(degrees) * sign, 0):VectorToWorldSpace(heading)
			if clear(dir) then
				brain.avoidSide = sign
				brain.avoidSideUntil = now + cfg.AvoidCommitTime
				setState(brain, if sign > 0 then "avoid-left" else "avoid-right")
				return dir
			end
		end
	end
	-- Boxed in: the stuck detector will back us out.
	setState(brain, "boxed-in")
	return heading
end

local function isBuildingChunk(instance: Instance): boolean
	return instance:GetAttribute(BuildingGenerator.CHUNK_ATTRIBUTE) == true
end

-- Fire when the barrel is on the aim point and either (a) the line hits the target, or
-- (b) the target is out of sight and a destructible wall close ahead is in the way:
-- blast through it rather than getting stuck behind or inside buildings.
local function fireIfReady(brain: Brain, now: number, aimPoint: Vector3, params: RaycastParams)
	local target = brain.target
	if not target or TankHealth.isProtected(target) then
		return
	end
	local muzzle = brain.refs.muzzle.WorldCFrame
	local toAim = aimPoint - muzzle.Position
	if toAim.Magnitude < 1e-3 or muzzle.LookVector:Angle(toAim) > Config.Bots.AimTolerance then
		return
	end
	local result = workspace:Raycast(muzzle.Position, muzzle.LookVector * Config.Weapon.Range, params)
	if not result then
		return
	end
	local onTarget = TankHealth.findTank(result.Instance) == target
	local shoot
	if onTarget then
		shoot = brain.targetVisible and now - brain.inSightSince >= Config.Bots.ReactionTime
	else
		shoot = not brain.targetVisible
			and result.Distance <= Config.Bots.BreachRange
			and isBuildingChunk(result.Instance)
		if shoot then
			setState(brain, "breach")
		end
	end
	if shoot and WeaponService.fireFrom(brain.tank, brain.combatant) then
		brain.aimOffset = scatter(brain.rng)
	end
end

function BotBrain.new(tank: TankBuilder.Tank, combatant: Combatant.Combatant): Brain?
	local refs = TankDrive.resolve(tank.model)
	if not refs then
		return nil
	end
	local rng = Random.new()
	return {
		tank = tank,
		refs = refs,
		combatant = combatant,
		rng = rng,
		target = nil,
		targetHull = nil,
		targetVisible = false,
		inSightSince = math.huge,
		nextRetarget = 0,
		orbitSign = if rng:NextNumber() < 0.5 then -1 else 1,
		backingOff = false,
		nextOrbitFlip = 0,
		waypoint = nil,
		stuckFor = 0,
		unstickUntil = 0,
		unstickTurn = 1,
		unstickThrottle = -1,
		avoidSide = 1,
		avoidSideUntil = 0,
		aimOffset = scatter(rng),
	}
end

function BotBrain.step(brain: Brain, dt: number)
	local now = os.clock()
	local cfg = Config.Bots
	local hull = brain.tank.hull
	local params = queryParams(brain)

	if now >= brain.nextRetarget then
		brain.nextRetarget = now + cfg.RetargetInterval
		retarget(brain, now, params)
	end

	-- Aim: at the target (with scatter), else straight ahead.
	local targetHull = brain.targetHull
	local aimPoint = if targetHull and targetHull.Parent
		then targetHull.Position + brain.aimOffset
		else hull.Position + hull.CFrame.LookVector * 50 + Vector3.yAxis * 3
	TankDrive.aim(brain.refs, aimPoint)
	fireIfReady(brain, now, aimPoint, params)

	-- Drive.
	local throttle, turn
	if now < brain.unstickUntil then
		setState(brain, "unstick")
		throttle, turn = brain.unstickThrottle, brain.unstickTurn
	else
		local heading, wanted = chooseMove(brain, now)
		heading = avoidWalls(brain, heading, wanted, now, params)
		local yawError = TankDrive.hullYaw(hull.CFrame, heading)
		-- Positive yaw error = heading is to the left; turn input is positive to the right.
		turn = -math.clamp(yawError / cfg.SteerSoftAngle, -1, 1)
		-- Ease off the throttle while turning sharply.
		throttle = wanted * math.max(0, math.cos(yawError))
		if wanted < 0 then
			throttle = wanted
		end

		-- Stuck = trying to move or turn but doing neither (wedged on a wall, corner or debris).
		local speed = flat(hull.AssemblyLinearVelocity).Magnitude
		local spin = math.abs(hull.AssemblyAngularVelocity:Dot(hull.CFrame.UpVector))
		local trying = math.abs(throttle) > 0.3 or math.abs(turn) > 0.5
		if trying and speed < cfg.StuckSpeed and spin < cfg.StuckSpin then
			brain.stuckFor += dt
		else
			brain.stuckFor = 0
		end
		if brain.stuckFor > cfg.StuckTime then
			brain.stuckFor = 0
			brain.unstickUntil = now + cfg.UnstickTime
			brain.unstickTurn = if brain.rng:NextNumber() < 0.5 then -1 else 1
			-- Back out of whatever we drove into (or pull forward if we reversed into it).
			brain.unstickThrottle = if throttle > 0 then -1 else 1
		end
	end
	TankDrive.drive(brain.refs, throttle, turn, dt)
end

return BotBrain
