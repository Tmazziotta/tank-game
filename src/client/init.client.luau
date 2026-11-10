--!strict
-- Client bootstrap.

local GarageMenu = require(script.GarageMenu)
local HazardEffects = require(script.HazardEffects)
local ProfileClient = require(script.ProfileClient)
local ProgressHud = require(script.ProgressHud)
local RoundHud = require(script.RoundHud)
local Scope = require(script.Scope)
local Spectator = require(script.Spectator)
local TankController = require(script.TankController)
local TankOverlays = require(script.TankOverlays)
local WeaponClient = require(script.WeaponClient)

ProfileClient.start()
TankController.start()
WeaponClient.start()
RoundHud.start()
HazardEffects.start()
Spectator.start()
Scope.start()
task.spawn(ProgressHud.start)
task.spawn(GarageMenu.start)
task.spawn(TankOverlays.start)
