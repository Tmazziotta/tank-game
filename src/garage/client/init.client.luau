--!strict
-- Garage client bootstrap: the desk scene and lobby HUD. Runs on the Garage place, and
-- alongside the Match client in dev mode (see Places).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Places = require(ReplicatedStorage.Shared.Places)
if not Places.runsGarage() then
	return
end
