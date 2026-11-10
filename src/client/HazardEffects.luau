--!strict
-- Effects for map hazards the server reports: mines going off and tanks sinking.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local ShotEffects = require(script.Parent.ShotEffects)

local HazardEffects = {}

local WATER = Color3.fromRGB(200, 230, 255)
local DIRT = Color3.fromRGB(110, 85, 60)

local function burst(position: Vector3, color: Color3, count: number, speed: number, size: number)
	local holder = Instance.new("Part")
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.CanTouch = false
	holder.Transparency = 1
	holder.Size = Vector3.one
	holder.CFrame = CFrame.new(position)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(color)
	emitter.Size = NumberSequence.new(size, size * 2)
	emitter.Transparency = NumberSequence.new(0.1, 1)
	emitter.Lifetime = NumberRange.new(0.8, 1.4)
	emitter.Speed = NumberRange.new(speed * 0.6, speed)
	emitter.SpreadAngle = Vector2.new(35, 35)
	emitter.EmissionDirection = Enum.NormalId.Top
	emitter.Acceleration = Vector3.new(0, -workspace.Gravity * 0.5, 0)
	emitter.Enabled = false
	emitter.Parent = holder
	holder.Parent = workspace
	emitter:Emit(count)
	task.delay(2, function()
		holder:Destroy()
	end)
end

local function splash(position: Vector3)
	local ground = Vector3.new(position.X, 0.3, position.Z)
	burst(ground, WATER, 80, 45, 1.5)
	local ring = Instance.new("Part")
	ring.Shape = Enum.PartType.Cylinder
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.Color = WATER
	ring.Material = Enum.Material.SmoothPlastic
	ring.Transparency = 0.3
	ring.Size = Vector3.new(0.3, 4, 4)
	ring.CFrame = CFrame.new(ground) * CFrame.Angles(0, 0, math.pi / 2)
	ring.Parent = workspace
	local tween = TweenService:Create(ring, TweenInfo.new(1.2), { Size = Vector3.new(0.3, 30, 30), Transparency = 1 })
	tween.Completed:Connect(function()
		ring:Destroy()
	end)
	tween:Play()
end

function HazardEffects.start()
	Remotes.HazardEvent.OnClientEvent:Connect(function(kind: unknown, position: unknown)
		if typeof(position) ~= "Vector3" then
			return
		end
		if kind == "Mine" then
			ShotEffects.explosion(position + Vector3.new(0, 1, 0), Config.Hazards.MineBlastRadius)
			burst(position, DIRT, 40, 50, 1.2)
		elseif kind == "Sink" then
			splash(position)
		end
	end)
end

return HazardEffects
