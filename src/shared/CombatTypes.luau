--!strict
-- Payloads the server broadcasts about combat. Clients only draw these.

-- Miss: hit nothing. World: hit map/debris. Hit: damaged a tank. Ricochet: bounced off a
-- tank's armor. Shielded: struck a spawn-protected tank.
export type ShotKind = "Miss" | "World" | "Hit" | "Ricochet" | "Shielded"

export type ShotReport = {
	origin: Vector3,
	hit: Vector3,
	kind: ShotKind,
	radius: number, -- blast radius of the shooter's gun
	normal: Vector3?, -- surface normal at the hit (tank hits only)
	damage: number?, -- damage dealt (Hit only)
	zone: string?, -- "Front" | "Side" | "Rear" (tank hits only)
	victim: Player?, -- player driving the tank that was struck (nil for bots)
}

export type DestroyedReport = {
	victimName: string,
	victim: Player?, -- nil for bots
	killerName: string?, -- nil if nobody gets credit
	killer: Player?, -- nil for bots
	position: Vector3?,
}

return {}
