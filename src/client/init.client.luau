--!strict
-- Client bootstrap.

local TankController = require(script.TankController)
local WeaponClient = require(script.WeaponClient)

TankController.start()
WeaponClient.start()
