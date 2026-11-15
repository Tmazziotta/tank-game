--!strict
-- Foam Force's clip: a few darts fired quickly, then a long reload. The server (WeaponService)
-- owns the state and mirrors it onto the tank model's attributes; clients read those for the
-- HUD and to avoid sending requests the server would refuse. Times are server time
-- (workspace:GetServerTimeNow()) so both sides agree.

local Config = require(script.Parent.Config)
local TankClass = require(script.Parent.TankClass)

local DartClip = {}

DartClip.AmmoAttribute = "Ammo"
DartClip.ReloadAttribute = "ReloadUntil"

function DartClip.size(): number
	return Config.Signatures.Foam.ClipSize
end

function DartClip.interval(): number
	return Config.Signatures.Foam.DartInterval
end

function DartClip.reloadTime(spec: TankClass.Spec): number
	return spec.Cooldown * DartClip.size()
end

-- Darts ready now and reload progress (0..1, 1 = full clip) as seen from `model`'s attributes.
function DartClip.read(model: Instance, spec: TankClass.Spec, now: number): (number, number)
	local ammo = model:GetAttribute(DartClip.AmmoAttribute)
	local reloadUntil = model:GetAttribute(DartClip.ReloadAttribute)
	if type(ammo) ~= "number" or type(reloadUntil) ~= "number" or now >= reloadUntil then
		return DartClip.size(), 1
	end
	local reload = DartClip.reloadTime(spec)
	return ammo, math.clamp(1 - (reloadUntil - now) / reload, 0, 1)
end

return DartClip
