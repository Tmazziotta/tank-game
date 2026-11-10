--!strict
-- Shared state between the on-screen touch controls (TouchControls, which writes it) and
-- the tank controller and camera (which read it). No dependencies, so anything can use it.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local TouchInput = {}

local throttle, turn = 0, 0
local look = Vector2.zero

-- Studio only: set this attribute on the local player to preview the touch UI on a PC.
local FORCE_ATTRIBUTE = "ForceTouchControls"

-- Phone/tablet without a keyboard: show touch controls and touch wording in the UI.
function TouchInput.isTouchDevice(): boolean
	if RunService:IsStudio() and Players.LocalPlayer and Players.LocalPlayer:GetAttribute(FORCE_ATTRIBUTE) == true then
		return true
	end
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

-- Virtual joystick: throttle -1 (reverse) .. 1, turn -1 (left) .. 1 (right).
function TouchInput.setDrive(newThrottle: number, newTurn: number)
	throttle, turn = newThrottle, newTurn
end

function TouchInput.getDrive(): (number, number)
	return throttle, turn
end

-- Look drag, in pixels; accumulated between camera frames.
function TouchInput.addLook(delta: Vector2)
	look += delta
end

-- Returns and clears the accumulated look drag.
function TouchInput.takeLook(): Vector2
	local value = look
	look = Vector2.zero
	return value
end

return TouchInput
