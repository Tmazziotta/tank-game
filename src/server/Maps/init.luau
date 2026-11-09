--!strict
-- Map registry: every arena by id. Rotation order is Config.Maps.Rotation.

local MapKit = require(script.Parent.MapKit)

local maps: { [string]: MapKit.MapDef } = {}
for _, def in { require(script.Town), require(script.Dockyard), require(script.Orchard) } do
	maps[def.id] = def
end

return maps
