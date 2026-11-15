--!strict
-- Shows the garage client only while this player is in the Garage (see LocationGate).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocationGate = require(ReplicatedStorage.Shared.LocationGate)

return LocationGate.new("Garage")
