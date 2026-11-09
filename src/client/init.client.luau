--!strict
-- Client bootstrap.

local ClassPicker = require(script.ClassPicker)
local RoundHud = require(script.RoundHud)
local TankController = require(script.TankController)
local TankOverlays = require(script.TankOverlays)
local WeaponClient = require(script.WeaponClient)

TankController.start()
WeaponClient.start()
RoundHud.start()
task.spawn(ClassPicker.start)
task.spawn(TankOverlays.start)
