--!strict
-- Client bootstrap.

local GarageMenu = require(script.GarageMenu)
local ProfileClient = require(script.ProfileClient)
local ProgressHud = require(script.ProgressHud)
local RoundHud = require(script.RoundHud)
local Spectator = require(script.Spectator)
local TankController = require(script.TankController)
local TankOverlays = require(script.TankOverlays)
local WeaponClient = require(script.WeaponClient)

ProfileClient.start()
TankController.start()
WeaponClient.start()
RoundHud.start()
Spectator.start()
task.spawn(ProgressHud.start)
task.spawn(GarageMenu.start)
task.spawn(TankOverlays.start)
