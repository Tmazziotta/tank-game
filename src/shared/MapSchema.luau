--!strict
-- Names of the arena instances, shared so clients can find (e.g. ignore) them.

return {
	MapFolder = "Map", -- workspace.Map: the live arena
	BuildingsFolder = "Buildings", -- destructible chunk buildings and walls
	CoverFolder = "Cover", -- indestructible hard cover and the boundary
	PropsFolder = "Props", -- crushable props: tanks drive through them
	GroundFolder = "Ground", -- surface patches and water (thin, non-colliding, queryable)
	MinefieldsFolder = "Minefields", -- minefield zones, warning signs and mines
	MineAttribute = "Mine", -- on each mine part
	CrushableAttribute = "Crushable", -- on each prop Model
	IndestructibleAttribute = "Indestructible",
}
