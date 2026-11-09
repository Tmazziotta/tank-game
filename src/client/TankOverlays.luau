--!strict
-- World-space overlays on live tanks: a name + health billboard over other players'
-- tanks, and a bubble around any tank that still has spawn protection. Reads the
-- attributes the server writes on each tank model.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local TankClass = require(ReplicatedStorage.Shared.TankClass)
local TankSchema = require(ReplicatedStorage.Shared.TankSchema)

local TankOverlays = {}

local SHIELD_COLOR = Color3.fromRGB(120, 200, 255)
local HEALTH_HIGH = Color3.fromRGB(120, 230, 140)
local HEALTH_LOW = Color3.fromRGB(255, 80, 80)
local BUBBLE_SIZE = 17

type Overlay = {
	hull: BasePart,
	billboard: BillboardGui?,
	fill: Frame?,
	bubble: Part,
}

local localPlayer = Players.LocalPlayer
local overlays: { [Model]: Overlay } = {}

local effects = Instance.new("Folder")
effects.Name = "TankOverlays"

local function displayName(model: Model): string
	local ownerId = model:GetAttribute(TankSchema.OwnerAttribute)
	local owner = if type(ownerId) == "number" then Players:GetPlayerByUserId(ownerId) else nil
	return if owner then owner.DisplayName else model.Name
end

local function makeBillboard(model: Model, hull: BasePart): (BillboardGui, Frame)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "TankLabel"
	billboard.Adornee = hull
	billboard.Size = UDim2.fromOffset(130, 36)
	billboard.StudsOffset = Vector3.new(0, 8, 0)
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 300
	billboard.ResetOnSpawn = false

	local name = Instance.new("TextLabel")
	name.Size = UDim2.new(1, 0, 0, 18)
	name.BackgroundTransparency = 1
	name.Font = Enum.Font.FredokaOne
	name.TextSize = 16
	name.TextColor3 = Color3.new(1, 1, 1)
	name.TextStrokeTransparency = 0.4
	name.Text = `{displayName(model)} - {TankClass.ofModel(model).DisplayName}`
	name.Parent = billboard

	local back = Instance.new("Frame")
	back.Position = UDim2.fromOffset(15, 22)
	back.Size = UDim2.new(1, -30, 0, 9)
	back.BackgroundColor3 = Color3.fromRGB(30, 32, 44)
	back.BackgroundTransparency = 0.2
	back.BorderSizePixel = 0
	back.Parent = billboard
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = back

	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = HEALTH_HIGH
	fill.BorderSizePixel = 0
	fill.Parent = back
	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0.5, 0)
	fillCorner.Parent = fill

	billboard.Parent = localPlayer:WaitForChild("PlayerGui")
	return billboard, fill
end

local function makeBubble(): Part
	local bubble = Instance.new("Part")
	bubble.Name = "SpawnShield"
	bubble.Shape = Enum.PartType.Ball
	bubble.Size = Vector3.one * BUBBLE_SIZE
	bubble.Material = Enum.Material.ForceField
	bubble.Color = SHIELD_COLOR
	bubble.Anchored = true
	bubble.CanCollide = false
	bubble.CanQuery = false
	bubble.CanTouch = false
	bubble.CastShadow = false
	bubble.Transparency = 1
	bubble.Parent = effects
	return bubble
end

local function detach(model: Instance)
	if not model:IsA("Model") then
		return
	end
	local overlay = overlays[model]
	if overlay then
		overlays[model] = nil
		if overlay.billboard then
			overlay.billboard:Destroy()
		end
		overlay.bubble:Destroy()
	end
end

local function attach(model: Instance)
	if not model:IsA("Model") or overlays[model] then
		return
	end
	local hull = model:WaitForChild(TankSchema.Hull, 10)
	if not (hull and hull:IsA("BasePart")) or not model:IsDescendantOf(workspace) then
		return
	end
	local mine = model:GetAttribute(TankSchema.OwnerAttribute) == localPlayer.UserId
	local billboard, fill = nil, nil
	if not mine then
		billboard, fill = makeBillboard(model, hull)
	end
	overlays[model] = { hull = hull, billboard = billboard, fill = fill, bubble = makeBubble() }
end

local function update()
	local now = workspace:GetServerTimeNow()
	for model, overlay in overlays do
		local fill = overlay.fill
		if fill then
			local health = model:GetAttribute(TankSchema.HealthAttribute)
			local maxHealth = model:GetAttribute(TankSchema.MaxHealthAttribute)
			if type(health) == "number" and type(maxHealth) == "number" and maxHealth > 0 then
				local fraction = math.clamp(health / maxHealth, 0, 1)
				fill.Size = UDim2.fromScale(fraction, 1)
				fill.BackgroundColor3 = HEALTH_LOW:Lerp(HEALTH_HIGH, fraction)
			end
		end
		local protectedUntil = model:GetAttribute(TankSchema.ProtectedUntilAttribute)
		local protected = type(protectedUntil) == "number" and now < protectedUntil
		overlay.bubble.Transparency = if protected then 0.2 else 1
		if protected then
			overlay.bubble.CFrame = overlay.hull.CFrame
		end
	end
end

function TankOverlays.start()
	effects.Parent = workspace
	local tanks = workspace:WaitForChild(TankSchema.TanksFolder)
	tanks.ChildAdded:Connect(function(child)
		attach(child)
	end)
	tanks.ChildRemoved:Connect(detach)
	for _, child in tanks:GetChildren() do
		task.spawn(attach, child)
	end
	RunService.RenderStepped:Connect(update)
end

return TankOverlays
