--!strict
-- Shell flight: constant gravity, no drag. Shared so the server's simulation, the client's
-- shell visuals, aim compensation and the bots' leading all agree.

local Config = require(script.Parent.Config)

local Ballistics = {}

local GRAVITY = Vector3.new(0, -Config.Weapon.ShellGravity, 0)

function Ballistics.gravity(): Vector3
	return GRAVITY
end

function Ballistics.launchVelocity(direction: Vector3): Vector3
	return direction.Unit * Config.Weapon.ShellSpeed
end

-- Where a shell is `t` seconds after leaving `origin` with `velocity`.
function Ballistics.positionAt(origin: Vector3, velocity: Vector3, t: number): Vector3
	return origin + velocity * t + GRAVITY * (0.5 * t * t)
end

function Ballistics.velocityAt(velocity: Vector3, t: number): Vector3
	return velocity + GRAVITY * t
end

function Ballistics.maxFlightTime(): number
	return Config.Weapon.Range / Config.Weapon.ShellSpeed
end

-- Aim point that makes a shell from `origin` land on `target` (raised by the drop over
-- the flight time). Good to well under a degree at our speeds and ranges.
function Ballistics.compensate(origin: Vector3, target: Vector3): Vector3
	local t = (target - origin).Magnitude / Config.Weapon.ShellSpeed
	return target - GRAVITY * (0.5 * t * t)
end

-- Where a target moving at `targetVelocity` will be when a shell from `origin` reaches it.
function Ballistics.lead(origin: Vector3, target: Vector3, targetVelocity: Vector3): Vector3
	local predicted = target
	for _ = 1, 3 do
		local t = (predicted - origin).Magnitude / Config.Weapon.ShellSpeed
		predicted = target + targetVelocity * t
	end
	return predicted
end

-- Trace a shell's path and return the first hit (or nil within Range).
function Ballistics.trace(origin: Vector3, velocity: Vector3, params: RaycastParams): RaycastResult?
	local step = Config.Weapon.ShellStep
	local maxTime = Ballistics.maxFlightTime()
	local t = 0
	local from = origin
	while t < maxTime do
		local nextT = math.min(t + step, maxTime)
		local to = Ballistics.positionAt(origin, velocity, nextT)
		local result = workspace:Raycast(from, to - from, params)
		if result then
			return result
		end
		from, t = to, nextT
	end
	return nil
end

return Ballistics
