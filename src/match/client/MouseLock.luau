--!strict
-- Who owns the mouse. While driving, the camera locks it to the screen center; menus
-- (e.g. the class picker) release it so the cursor can click buttons.

local UserInputService = game:GetService("UserInputService")

local MouseLock = {}

local released = false

function MouseLock.setReleased(on: boolean)
	released = on
end

-- True while a menu has the cursor (no mouse-look, no firing).
function MouseLock.isReleased(): boolean
	return released
end

-- Apply the lock state; `wantLock` is whether the camera would like the mouse locked.
function MouseLock.apply(wantLock: boolean)
	local lock = wantLock and not released
	UserInputService.MouseBehavior = if lock then Enum.MouseBehavior.LockCenter else Enum.MouseBehavior.Default
	UserInputService.MouseIconEnabled = not lock
end

return MouseLock
