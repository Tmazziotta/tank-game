--!strict
-- Shape of a player's saved data (ProfileStore profile) and the snapshot sent to their client.

-- One tank's mod tree. Equipped has one entry per row: a mod id, or "" for none.
export type TankMods = {
	Unlocked: { [string]: boolean }, -- mod id -> unlocked
	Equipped: { string },
}

export type Data = {
	Coins: number,
	XP: number,
	Line: string, -- the toy line picked on first join; "" until then (no tanks yet)
	OwnedTanks: { [string]: boolean }, -- tank id -> owned
	TankXP: { [string]: number }, -- tank id -> unspent tank XP (earned driving it)
	Mods: { [string]: TankMods }, -- tank id -> mod tree (missing = nothing unlocked)
	SelectedTank: string, -- always one of Loadout ("" before a line is picked)
	Loadout: { string }, -- up to Config.Garage.LoadoutSlots owned tank ids, no repeats
	Stats: {
		Kills: number,
		Deaths: number,
		Wins: number,
		Rounds: number,
	},
}

return {}
