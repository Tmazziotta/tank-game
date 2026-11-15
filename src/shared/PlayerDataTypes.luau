--!strict
-- Shape of a player's saved data (ProfileStore profile) and the snapshot sent to their client.

export type UpgradeLevels = {
	Gun: number,
	Armor: number,
	Engine: number,
}

export type Data = {
	Coins: number,
	XP: number,
	OwnedTanks: { [string]: boolean }, -- tank id -> owned
	Upgrades: { [string]: UpgradeLevels }, -- tank id -> levels (missing = all 0)
	SelectedTank: string, -- always one of Loadout
	Loadout: { string }, -- Config.Garage.LoadoutSlots owned tank ids, no repeats
	Stats: {
		Kills: number,
		Deaths: number,
		Wins: number,
		Rounds: number,
	},
}

return {}
