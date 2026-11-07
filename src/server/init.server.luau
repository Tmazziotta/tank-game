--!strict
-- Server bootstrap.

local TankService = require(script.TankService)
local WeaponService = require(script.WeaponService)

TankService.start()
WeaponService.start(function(_position: Vector3, _shooter: Player)
	-- Impacts get wired to destruction once buildings exist.
end)
