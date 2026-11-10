--!strict
-- Cosmetic shot visuals, rendered locally on each client: muzzle flash and a glowing shell
-- flying the same arc as the server's (ShellFired), then the impact burst when the server
-- reports where it landed (ShotFired). No gameplay effect.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Ballistics = require(ReplicatedStorage.Shared.Ballistics)
local CombatTypes = require(ReplicatedStorage.Shared.CombatTypes)
local Config = require(ReplicatedStorage.Shared.Config)

local ShotEffects = {}

local TRACER_COLOR = Color3.fromRGB(255, 230, 120)
local FLASH_COLOR = Color3.fromRGB(255, 200, 90)
local BLAST_COLOR = Color3.fromRGB(255, 130, 50)
local SPARK_COLOR = Color3.fromRGB(255, 250, 220)
local SHIELD_COLOR = Color3.fromRGB(120, 200, 255)

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

local function impact(position: Vector3, radius: number, sparkCount: number)
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
	sparks:Emit(sparkCount)
	smoke:Emit(math.round(sparkCount * 0.4))
	task.delay(2, function()
		holder:Destroy()
	end)
end

-- Shells in flight, by id.
type Flight = { part: BasePart, origin: Vector3, velocity: Vector3, launched: number }
local flights: { [number]: Flight } = {}

local function makeShell(origin: Vector3): BasePart
	local shell = effectPart(Enum.PartType.Ball, Vector3.one * 0.8, CFrame.new(origin), TRACER_COLOR)
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, 0.3, 0)
	a0.Parent = shell
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, -0.3, 0)
	a1.Parent = shell
	local trail = Instance.new("Trail")
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Lifetime = 0.15
	trail.Color = ColorSequence.new(TRACER_COLOR)
	trail.LightEmission = 1
	trail.Transparency = NumberSequence.new(0.2, 1)
	trail.FaceCamera = true
	trail.Parent = shell
	return shell
end

local function stepFlights()
	local now = os.clock()
	local maxTime = Ballistics.maxFlightTime()
	for id, flight in flights do
		local t = now - flight.launched
		if t > maxTime + 0.5 then
			flight.part:Destroy()
			flights[id] = nil
		else
			flight.part.CFrame = CFrame.new(Ballistics.positionAt(flight.origin, flight.velocity, t))
		end
	end
end

function ShotEffects.mount()
	folder.Parent = workspace
	RunService.RenderStepped:Connect(stepFlights)
end

-- A shell left a barrel.
function ShotEffects.launch(launch: CombatTypes.ShellLaunch)
	muzzleFlash(launch.origin)
	flights[launch.id] = {
		part = makeShell(launch.origin),
		origin = launch.origin,
		velocity = launch.velocity,
		launched = os.clock(),
	}
end

-- A small bright flash where a shell glanced off or splashed on a shield.
local function glance(position: Vector3, color: Color3)
	local flash = effectPart(Enum.PartType.Ball, Vector3.one * 1, CFrame.new(position), color)
	fadeOut(flash, 0.25, { Size = Vector3.one * 5 })
end

-- A shell landed (or ran out of range).
function ShotEffects.land(report: CombatTypes.ShotReport)
	local flight = flights[report.id]
	local incoming = (report.hit - report.origin).Unit
	if flight then
		flights[report.id] = nil
		local t = os.clock() - flight.launched
		incoming = Ballistics.velocityAt(flight.velocity, t).Unit
		flight.part:Destroy()
	end
	local kind = report.kind
	if kind == "World" or kind == "Hit" then
		impact(report.hit, report.radius, 30)
	elseif kind == "Ricochet" then
		glance(report.hit, SPARK_COLOR)
		local normal = report.normal or -incoming
		local bounced = incoming - 2 * incoming:Dot(normal) * normal
		tracer(report.hit, report.hit + bounced * 30)
	elseif kind == "Shielded" then
		glance(report.hit, SHIELD_COLOR)
	end
end

-- A tank blowing up.
function ShotEffects.tankExplosion(position: Vector3)
	impact(position, Config.Combat.WreckBlastRadius * 1.5, 70)
end

return ShotEffects
