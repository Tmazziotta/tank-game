--!strict
-- Builds crushable props (crates, fence pieces, trees) from primitives. Intact props are
-- anchored and don't collide, so a tank never snags on one: PropCrusher breaks whatever a
-- tank overlaps, or a blast reaches, and only the flying pieces have physics.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local MapSchema = require(ReplicatedStorage.Shared.MapSchema)

export type Kind = "Crate" | "Fence" | "Tree"

local PropBuilder = {}

local WOOD = Color3.fromRGB(196, 140, 82)
local WOOD_DARK = Color3.fromRGB(150, 100, 60)
local FENCE = Color3.fromRGB(245, 240, 230)
local TRUNK = Color3.fromRGB(120, 85, 60)
local LEAVES = {
	Color3.fromRGB(110, 200, 90),
	Color3.fromRGB(80, 175, 95),
	Color3.fromRGB(150, 210, 80),
}

local function part(model: Model, name: string, shape: Enum.PartType, size: Vector3, cframe: CFrame, color: Color3): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Shape = shape
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Anchored = true
	p.CanCollide = false -- tanks pass through; the crusher breaks it on contact
	p.CanQuery = true -- shells and blasts still find it
	p.Parent = model
	return p
end

local function crate(model: Model, origin: CFrame)
	local s = Config.Props.CrateSize
	local box = part(model, "Crate", Enum.PartType.Block, Vector3.new(s, s, s), origin * CFrame.new(0, s / 2, 0), WOOD)
	-- Dark slats on two faces read as "crate" from any angle.
	for _, z in { -1, 1 } do
		local slat = part(model, "Slat", Enum.PartType.Block, Vector3.new(s * 1.02, s * 0.2, s * 0.2), box.CFrame * CFrame.new(0, 0, z * s * 0.45), WOOD_DARK)
		slat.CanQuery = false
	end
end

local function fence(model: Model, origin: CFrame, length: number)
	-- One post at the start; the next piece's post closes the gap.
	part(model, "Post", Enum.PartType.Block, Vector3.new(0.8, 4, 0.8), origin * CFrame.new(0, 2, 0), FENCE)
	for _, y in { 1.4, 3 } do
		part(model, "Rail", Enum.PartType.Block, Vector3.new(0.4, 0.6, length), origin * CFrame.new(0, y, -length / 2), FENCE)
	end
end

local function tree(model: Model, origin: CFrame, rng: Random)
	local height = rng:NextNumber(7, 10)
	part(model, "Trunk", Enum.PartType.Cylinder, Vector3.new(height, 1.6, 1.6), origin * CFrame.new(0, height / 2, 0) * CFrame.Angles(0, 0, math.rad(90)), TRUNK)
	local canopy = rng:NextNumber(7, 9.5)
	part(model, "Canopy", Enum.PartType.Ball, Vector3.new(canopy, canopy, canopy), origin * CFrame.new(0, height + canopy * 0.25, 0), LEAVES[rng:NextInteger(1, #LEAVES)])
end

-- Returns an unparented prop Model. `origin` is ground level; fences run `length` studs
-- along its -Z.
function PropBuilder.build(kind: Kind, origin: CFrame, rng: Random, length: number?): Model
	local model = Instance.new("Model")
	model.Name = kind
	model:SetAttribute(MapSchema.CrushableAttribute, true)
	if kind == "Crate" then
		crate(model, origin)
	elseif kind == "Fence" then
		fence(model, origin, length or Config.Props.FenceSegment)
	else
		tree(model, origin, rng)
	end
	return model
end

return PropBuilder
