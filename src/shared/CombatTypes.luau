--!strict
-- Payloads the server broadcasts about combat. Clients only draw these.

-- Miss: hit nothing. World: hit map/debris. Hit: damaged a tank. Ricochet: bounced off a
-- tank's armor. Shielded: struck a spawn-protected tank or a teammate (no friendly fire).
export type ShotKind = "Miss" | "World" | "Hit" | "Ricochet" | "Shielded"

export type ShotReport = {
	id: number, -- the shell (matches ShellLaunch.id)
	origin: Vector3,
	hit: Vector3,
	kind: ShotKind,
	radius: number, -- blast radius of the shooter's gun
	normal: Vector3?, -- surface normal at the hit (tank hits only)
	damage: number?, -- damage dealt (Hit only)
	zone: string?, -- "Front" | "Side" | "Rear" (tank hits only)
	victim: Player?, -- player driving the tank that was struck (nil for bots)
}

-- A shell leaving the barrel; clients fly a visual along the same path.
export type ShellLaunch = {
	id: number,
	origin: Vector3,
	velocity: Vector3,
}

export type DestroyedReport = {
	victimName: string,
	victim: Player?, -- nil for bots
	killerName: string?, -- nil if nobody gets credit
	killer: Player?, -- nil for bots
	victimTeam: string?,
	killerTeam: string?,
	position: Vector3?,
}

return {}
