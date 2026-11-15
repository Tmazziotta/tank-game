--!strict
-- Plush Patrol signature, on the local tank (the client owns its physics, so impulses
-- applied here move it): HOP (Space or the touch HOP button) when on the ground, and a
-- springy bounce off walls instead of stopping dead. After a bounce the drive lets go for a
-- moment (TankController asks `isLoose`) so the bounce carries.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local TankCatalog = require(ReplicatedStorage.Shared.TankCatalog)
local TankDrive = require(ReplicatedStorage.Shared.TankDrive)

type Refs = TankDrive.Refs

local PlushMoves = {}

local localPlayer = Players.LocalPlayer
local lastHop = -math.huge
local lastBounce = -math.huge
local current: () -> Refs? = function()
	return nil
end

local function plushTank(): Refs?
	local tank = current()
	if tank and TankCatalog.lineOfModel(tank.model) == "Plush" then
		return tank
	end
	return nil
end

local function params(tank: Refs): RaycastParams
	local ignore: { Instance } = { tank.model }
	if localPlayer.Character then
		table.insert(ignore, localPlayer.Character :: Model)
	end
	local p = RaycastParams.new()
	p.FilterType = Enum.RaycastFilterType.Exclude
	p.FilterDescendantsInstances = ignore
	return p
end

local function grounded(tank: Refs): boolean
	local reach = tank.hull.Size.Y / 2 + Config.Signatures.Plush.GroundProbe
	return workspace:Raycast(tank.hull.Position, Vector3.new(0, -reach, 0), params(tank)) ~= nil
end

-- Whether the local tank is a Plush tank (shows the HOP button).
function PlushMoves.canHop(): boolean
	return plushTank() ~= nil
end

-- 0..1 hop cooldown (1 = ready).
function PlushMoves.hopProgress(): number
	return math.clamp((os.clock() - lastHop) / Config.Signatures.Plush.HopCooldown, 0, 1)
end

function PlushMoves.hop()
	local tank = plushTank()
	if not tank or PlushMoves.hopProgress() < 1 or not grounded(tank) then
		return
	end
	lastHop = os.clock()
	local hull = tank.hull
	hull:ApplyImpulse(Vector3.yAxis * Config.Signatures.Plush.HopSpeed * hull.AssemblyMass)
end

-- True for a moment after a wall bounce: the drive shouldn't fight it.
function PlushMoves.isLoose(): boolean
	return os.clock() - lastBounce < Config.Signatures.Plush.BounceLoose
end

local function checkBounce(dt: number)
	local tank = plushTank()
	if not tank or PlushMoves.isLoose() then
		return
	end
	local cfg = Config.Signatures.Plush
	local hull = tank.hull
	local v = hull.AssemblyLinearVelocity
	local flat = Vector3.new(v.X, 0, v.Z)
	local speed = flat.Magnitude
	if speed < cfg.BounceMinSpeed then
		return
	end
	local reach = math.max(hull.Size.X, hull.Size.Z) / 2 + speed * dt * 2 + 0.5
	local result = workspace:Raycast(hull.Position, flat.Unit * reach, params(tank))
	if not result or math.abs(result.Normal.Y) > 0.5 then
		return -- nothing ahead, or a slope rather than a wall
	end
	local normal = Vector3.new(result.Normal.X, 0, result.Normal.Z).Unit
	local into = flat:Dot(normal) -- negative when heading into the wall
	if into > -cfg.BounceMinSpeed then
		return
	end
	lastBounce = os.clock()
	local kick = normal * (-into * (1 + cfg.BounceRestitution)) + Vector3.yAxis * cfg.BouncePop
	hull:ApplyImpulse(kick * hull.AssemblyMass)
end

-- `getTank` returns the local player's tank (TankController.getTank).
function PlushMoves.start(getTank: () -> Refs?)
	current = getTank
	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if not processed and input.KeyCode == Enum.KeyCode.Space then
			PlushMoves.hop()
		end
	end)
	RunService.Heartbeat:Connect(checkBounce)
end

return PlushMoves
