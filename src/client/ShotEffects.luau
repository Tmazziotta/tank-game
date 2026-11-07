--!strict
-- Cosmetic shot visuals (tracer, muzzle flash, impact burst), rendered locally on each
-- client from the server's ShotFired broadcast. No gameplay effect.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)

local ShotEffects = {}

local TRACER_COLOR = Color3.fromRGB(255, 230, 120)
local FLASH_COLOR = Color3.fromRGB(255, 200, 90)
local BLAST_COLOR = Color3.fromRGB(255, 130, 50)

local folder = Instance.new("Folder")
folder.Name = "ClientEffects"

local function effectPart(shape: Enum.PartType, size: Vector3, cframe: CFrame, color: Color3): Part
	local part = Instance.new("Part")
	part.Shape = shape
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = Enum.Material.Neon
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Parent = folder
	return part
end

local function fadeOut(part: BasePart, duration: number, goal: { [string]: any })
	goal.Transparency = 1
	local tween = TweenService:Create(part, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), goal)
	tween.Completed:Once(function()
		part:Destroy()
	end)
	tween:Play()
end

local function tracer(origin: Vector3, hit: Vector3)
	local length = (hit - origin).Magnitude
	if length < 0.1 then
		return
	end
	local beam = effectPart(
		Enum.PartType.Block,
		Vector3.new(0.4, 0.4, length),
		CFrame.lookAt((origin + hit) / 2, hit),
		TRACER_COLOR
	)
	fadeOut(beam, Config.Weapon.TracerLifetime, { Size = Vector3.new(0.05, 0.05, length) })
end

local function muzzleFlash(origin: Vector3)
	local flash = effectPart(Enum.PartType.Ball, Vector3.one * 1.5, CFrame.new(origin), FLASH_COLOR)
	fadeOut(flash, 0.15, { Size = Vector3.one * 4 })
end

local function impact(position: Vector3)
	local radius = Config.Weapon.BlastRadius
	local ball = effectPart(Enum.PartType.Ball, Vector3.one * 2, CFrame.new(position), BLAST_COLOR)
	ball.Transparency = 0.2
	fadeOut(ball, 0.35, { Size = Vector3.one * radius * 2 })

	local light = Instance.new("PointLight")
	light.Color = BLAST_COLOR
	light.Range = radius * 3
	light.Brightness = 6
	light.Parent = ball

	-- Particles live on a separate holder so they outlast the shrinking fireball.
	local holder = effectPart(Enum.PartType.Block, Vector3.one, CFrame.new(position), BLAST_COLOR)
	holder.Transparency = 1
	local sparks = Instance.new("ParticleEmitter")
	sparks.Color = ColorSequence.new(FLASH_COLOR, BLAST_COLOR)
	sparks.LightEmission = 1
	sparks.Size = NumberSequence.new(0.6, 0)
	sparks.Lifetime = NumberRange.new(0.3, 0.7)
	sparks.Speed = NumberRange.new(25, 45)
	sparks.SpreadAngle = Vector2.new(180, 180)
	sparks.Drag = 3
	sparks.Enabled = false
	sparks.Parent = holder
	local smoke = Instance.new("ParticleEmitter")
	smoke.Color = ColorSequence.new(Color3.fromRGB(90, 90, 100))
	smoke.Size = NumberSequence.new(2, 5)
	smoke.Transparency = NumberSequence.new(0.3, 1)
	smoke.Lifetime = NumberRange.new(0.8, 1.4)
	smoke.Speed = NumberRange.new(4, 10)
	smoke.SpreadAngle = Vector2.new(180, 180)
	smoke.Acceleration = Vector3.new(0, 6, 0)
	smoke.Enabled = false
	smoke.Parent = holder
	sparks:Emit(30)
	smoke:Emit(12)
	task.delay(2, function()
		holder:Destroy()
	end)
end

function ShotEffects.mount()
	folder.Parent = workspace
end

function ShotEffects.play(origin: Vector3, hitPosition: Vector3, didHit: boolean)
	muzzleFlash(origin)
	tracer(origin, hitPosition)
	if didHit then
		impact(hitPosition)
	end
end

return ShotEffects
