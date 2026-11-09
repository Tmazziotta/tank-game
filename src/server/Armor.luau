--!strict
-- Armor math (pure, no state): which plate a shell struck and how much damage gets
-- through. Front plates are toughest, rear plates weakest; the further a shell strikes
-- from square-on, the less gets through, and past the ricochet angle it bounces off.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

export type Zone = "Front" | "Side" | "Rear"

export type Result = {
	zone: Zone,
	impactAngle: number, -- radians from the surface normal
	ricochet: boolean,
	damage: number,
}

local Armor = {}

-- `facing` is the forward direction of the struck assembly (hull or turret), `up` the
-- hull's up. Roof and belly hits count as side armor.
function Armor.zone(normal: Vector3, facing: Vector3, up: Vector3): Zone
	local flatNormal = normal - up * normal:Dot(up)
	local flatFacing = facing - up * facing:Dot(up)
	if flatNormal.Magnitude < 0.2 or flatFacing.Magnitude < 1e-3 then
		return "Side" :: Zone
	end
	local alignment = flatNormal.Unit:Dot(flatFacing.Unit)
	local arc = math.cos(Config.Combat.FrontArc)
	if alignment >= arc then
		return "Front" :: Zone
	elseif alignment <= -arc then
		return "Rear" :: Zone
	end
	return "Side" :: Zone
end

-- 1 for square-on hits, falling to GrazeMultiplier near the ricochet angle, 0 past it.
function Armor.angleMultiplier(impactAngle: number): number
	local c = Config.Combat
	if impactAngle >= c.RicochetAngle then
		return 0
	elseif impactAngle <= c.FullDamageAngle then
		return 1
	end
	local t = (impactAngle - c.FullDamageAngle) / (c.RicochetAngle - c.FullDamageAngle)
	return 1 + (c.GrazeMultiplier - 1) * t
end

function Armor.zoneMultiplier(zone: Zone): number
	local c = Config.Combat
	if zone == "Front" then
		return c.FrontArmorMultiplier
	elseif zone == "Rear" then
		return c.RearArmorMultiplier
	end
	return c.SideArmorMultiplier
end

function Armor.evaluate(shellDirection: Vector3, normal: Vector3, facing: Vector3, up: Vector3): Result
	local zone: Zone = Armor.zone(normal, facing, up)
	local impactAngle = math.acos(math.clamp(-shellDirection.Unit:Dot(normal.Unit), -1, 1))
	local angleMultiplier = Armor.angleMultiplier(impactAngle)
	local damage = Config.Combat.ShellDamage * Armor.zoneMultiplier(zone) * angleMultiplier
	return {
		zone = zone,
		impactAngle = impactAngle,
		ricochet = angleMultiplier == 0,
		damage = if angleMultiplier > 0 then math.max(1, math.round(damage)) else 0,
	}
end

return Armor
