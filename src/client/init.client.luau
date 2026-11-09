--!strict
-- Client bootstrap.

local RoundHud = require(script.RoundHud)
local TankController = require(script.TankController)
local TankOverlays = require(script.TankOverlays)
local WeaponClient = require(script.WeaponClient)

TankController.start()
WeaponClient.start()
RoundHud.start()
task.spawn(TankOverlays.start)
