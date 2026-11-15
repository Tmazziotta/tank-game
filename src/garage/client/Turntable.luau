--!strict
-- The selected tank on the cardboard turntable: a local, anchored display copy that spins
-- slowly. Dragging (mouse or touch) anywhere outside the UI turns it by hand; the idle spin
-- resumes a moment after letting go. The tank follows the player's saved selection.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local GarageScene = require(script.Parent.GarageScene)
local TankBuilder = require(ReplicatedStorage.Shared.TankBuilder)
local TankCatalog = require(ReplicatedStorage.Shared.TankCatalog)

local Turntable = {}

local scene: GarageScene.Scene? = nil
local base: CFrame = CFrame.identity -- turntable top, unrotated
local yaw = math.rad(-30) -- start three-quarter on
local display: Model? = nil
local displayOffset: CFrame = CFrame.identity -- display pivot relative to the build origin
local shownKey: string? = nil
local dragging: InputObject? = nil
local lastDrag = -math.huge
local enabled = false

local function anchorAll(model: Model)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
		elseif d:IsA("Constraint") then
			d.Enabled = false
		end
	end
end

-- Identifies what's on display, so re-syncs of unchanged data don't rebuild the tank.
local function displayKey(tankId: string, mods: { string }?): string
	return `{tankId}:{TankCatalog.encodeMods(mods or {})}`
end

-- Show `tankId` (with its mods) on the turntable; no-op if it's already there.
function Turntable.show(tankId: string, mods: { string }?)
	local current = scene
	if not current then
		return
	end
	local key = displayKey(tankId, mods)
	if key == shownKey and display and display.Parent then
		return
	end
	shownKey = key
	if display then
		display:Destroy()
	end
	local tank = TankBuilder.build(base, Config.Garage.TankColor, TankCatalog.normalize(tankId), mods)
	anchorAll(tank.model)
	displayOffset = base:ToObjectSpace(tank.model:GetPivot())
	tank.model.Name = "DisplayTank"
	tank.model.Parent = current.folder
	display = tank.model
end

local function isDragInput(input: InputObject): boolean
	return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
end

local function step(dt: number)
	local current = scene
	if not current or not enabled then
		return
	end
	if not dragging and os.clock() - lastDrag > Config.Garage.SpinResumeDelay then
		yaw += Config.Garage.SpinSpeed * dt
	end
	local turned = base * CFrame.Angles(0, yaw, 0)
	current.turntable:PivotTo(turned)
	if display then
		display:PivotTo(turned * displayOffset)
	end
end

-- Pause or resume (the garage is hidden while the player is in a match).
function Turntable.setEnabled(on: boolean)
	enabled = on
	dragging = nil
end

function Turntable.start(builtScene: GarageScene.Scene)
	scene = builtScene
	base = builtScene.turntable:GetPivot()
	RunService.RenderStepped:Connect(step)

	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if enabled and not processed and not dragging and isDragInput(input) then
			dragging = input
		end
	end)
	UserInputService.InputChanged:Connect(function(input: InputObject)
		local drag = dragging
		if not drag then
			return
		end
		local moved = (drag.UserInputType == Enum.UserInputType.MouseButton1 and input.UserInputType == Enum.UserInputType.MouseMovement)
			or (drag.UserInputType == Enum.UserInputType.Touch and input == drag)
		if moved then
			yaw += input.Delta.X * Config.Garage.DragSpeed
			lastDrag = os.clock()
		end
	end)
	UserInputService.InputEnded:Connect(function(input: InputObject)
		local drag = dragging
		if drag and (input == drag or input.UserInputType == drag.UserInputType and drag.UserInputType == Enum.UserInputType.MouseButton1) then
			dragging = nil
			lastDrag = os.clock()
		end
	end)
end

return Turntable
