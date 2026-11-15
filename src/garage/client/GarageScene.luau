--!strict
-- The Garage backdrop: a kid's desk at toy scale (tanks are ~10 studs long) with pencils,
-- crayons, an eraser, wooden letter blocks and a crayon drawing taped to the wall, plus
-- the cardboard turntable the tank sits on. Built locally on each client, so every player
-- sees only their own desk, far from the arena (Config.Garage.ScenePosition).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local GarageScene = {}

export type Scene = {
	folder: Folder,
	center: CFrame, -- turntable center on the desk top; the camera looks at it from +Z
	turntable: Model, -- the spinning disc (pivot = center at the disc top)
}

local WOOD = Color3.fromRGB(196, 146, 98)
local CARDBOARD = Color3.fromRGB(192, 152, 104)

local function part(
	parent: Instance,
	shape: Enum.PartType,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material?
): Part
	local p = Instance.new("Part")
	p.Shape = shape
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function block(parent: Instance, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material?): Part
	return part(parent, Enum.PartType.Block, size, cframe, color, material)
end

-- Cylinder lying along `axis` (a CFrame whose X axis is the length).
local function rod(parent: Instance, length: number, diameter: number, cframe: CFrame, color: Color3, material: Enum.Material?): Part
	return part(parent, Enum.PartType.Cylinder, Vector3.new(length, diameter, diameter), cframe, color, material)
end

-- A pencil lying on the desk at (x, z), pointing along `yaw` degrees.
local function pencil(parent: Instance, base: CFrame, x: number, z: number, yaw: number, color: Color3)
	local d = 3
	local axis = base * CFrame.new(x, d / 2, z) * CFrame.Angles(0, math.rad(yaw), 0)
	rod(parent, 44, d, axis, color)
	rod(parent, 4, d * 0.98, axis * CFrame.new(-24, 0, 0), Color3.fromRGB(200, 200, 205), Enum.Material.Metal) -- ferrule
	rod(parent, 4, d * 0.95, axis * CFrame.new(-28, 0, 0), Color3.fromRGB(240, 140, 160)) -- eraser
	rod(parent, 5, d * 0.7, axis * CFrame.new(24.5, 0, 0), Color3.fromRGB(230, 200, 160), Enum.Material.Wood) -- sharpened wood
	rod(parent, 2, d * 0.35, axis * CFrame.new(27.5, 0, 0), Color3.fromRGB(60, 60, 66)) -- lead
end

local function crayon(parent: Instance, base: CFrame, x: number, z: number, yaw: number, color: Color3)
	local d = 2.6
	local axis = base * CFrame.new(x, d / 2, z) * CFrame.Angles(0, math.rad(yaw), 0)
	rod(parent, 16, d, axis, color)
	rod(parent, 10, d * 1.04, axis * CFrame.new(-1, 0, 0), Color3.fromRGB(245, 240, 225)) -- paper wrapper
	rod(parent, 2.4, d * 0.6, axis * CFrame.new(9, 0, 0), color) -- tip
end

-- A wooden letter block with its letter on the camera-facing (+Z, "Back") face.
local function letterBlock(parent: Instance, cframe: CFrame, color: Color3, letter: string)
	local size = 8
	local p = block(parent, Vector3.new(size, size, size), cframe, color, Enum.Material.Wood)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Back
	gui.CanvasSize = Vector2.new(100, 100)
	gui.Parent = p
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = letter
	label.TextScaled = true
	label.Font = Enum.Font.FredokaOne
	label.TextColor3 = Color3.fromRGB(255, 250, 235)
	label.Parent = gui
end

local function frame(parent: Instance, position: UDim2, size: UDim2, color: Color3, round: number?): Frame
	local f = Instance.new("Frame")
	f.Position = position
	f.Size = size
	f.BackgroundColor3 = color
	f.BorderSizePixel = 0
	f.Parent = parent
	if round then
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(round, 0)
		corner.Parent = f
	end
	return f
end

-- A kid's crayon drawing of a tank under a sun, taped to the wall.
local function drawing(parent: Instance, cframe: CFrame)
	local paper = block(parent, Vector3.new(34, 24, 0.2), cframe, Color3.fromRGB(252, 250, 240), Enum.Material.Fabric)
	for _, corner in { { -16, 11 }, { 16, 11 } } do
		block(parent, Vector3.new(4, 1.6, 0.25), cframe * CFrame.new(corner[1], corner[2], 0.1) * CFrame.Angles(0, 0, math.rad(corner[1] > 0 and -30 or 30)), Color3.fromRGB(235, 225, 190)).Transparency = 0.3
	end
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Back -- +Z, toward the camera
	gui.CanvasSize = Vector2.new(340, 240)
	gui.Parent = paper
	frame(gui, UDim2.fromOffset(0, 190), UDim2.fromOffset(340, 50), Color3.fromRGB(120, 200, 90)) -- grass
	frame(gui, UDim2.fromOffset(255, 20), UDim2.fromOffset(60, 60), Color3.fromRGB(255, 210, 60), 0.5) -- sun
	frame(gui, UDim2.fromOffset(90, 140), UDim2.fromOffset(150, 50), Color3.fromRGB(230, 80, 70), 0.2) -- hull
	frame(gui, UDim2.fromOffset(130, 108), UDim2.fromOffset(70, 40), Color3.fromRGB(230, 80, 70), 0.5) -- turret
	frame(gui, UDim2.fromOffset(195, 120), UDim2.fromOffset(70, 10), Color3.fromRGB(60, 60, 70)) -- barrel
	for i = 0, 3 do
		frame(gui, UDim2.fromOffset(98 + i * 36, 176), UDim2.fromOffset(26, 26), Color3.fromRGB(60, 60, 70), 0.5) -- wheels
	end
end

-- The cardboard turntable: a disc with a printed arrow ring, so you can see it turn.
local function buildTurntable(parent: Instance, center: CFrame): Model
	local model = Instance.new("Model")
	model.Name = "Turntable"
	local height = 2.4
	local flat = CFrame.Angles(0, 0, math.rad(90)) -- cylinders run along X; stand them up
	-- Static base, slightly wider and darker.
	rod(parent, 1, 32, center * CFrame.new(0, 0.5, 0) * flat, Color3.fromRGB(150, 115, 78), Enum.Material.Cardboard)
	rod(model, height - 1, 30, center * CFrame.new(0, 1 + (height - 1) / 2, 0) * flat, CARDBOARD, Enum.Material.Cardboard)
	-- Marker-drawn dashes around the rim.
	for i = 0, 11 do
		local angle = math.rad(i * 30)
		block(
			model,
			Vector3.new(3, 0.1, 0.8),
			center * CFrame.Angles(0, angle, 0) * CFrame.new(0, height + 0.02, -13),
			Color3.fromRGB(110, 80, 55)
		)
	end
	-- No PrimaryPart: the pivot must be the flat disc top, not the (sideways) cylinder's frame.
	model.WorldPivot = center * CFrame.new(0, height, 0)
	model.Parent = parent
	return model
end

function GarageScene.build(): Scene
	local folder = Instance.new("Folder")
	folder.Name = "GarageScene"
	local center = CFrame.new(Config.Garage.ScenePosition) -- desk top, camera on the +Z side

	-- Desk top and front edge.
	block(folder, Vector3.new(220, 6, 110), center * CFrame.new(0, -3, -10), WOOD, Enum.Material.Wood)
	block(folder, Vector3.new(220, 3, 3), center * CFrame.new(0, -1.5, 45), Color3.fromRGB(170, 120, 78), Enum.Material.Wood)
	-- Bedroom wall behind the desk, and a skirting strip where they meet.
	block(folder, Vector3.new(400, 220, 2), center * CFrame.new(0, 100, -66), Color3.fromRGB(170, 205, 235))
	block(folder, Vector3.new(400, 4, 1), center * CFrame.new(0, 2, -64.6), Color3.fromRGB(245, 245, 250))
	drawing(folder, center * CFrame.new(-34, 30, -64.8) * CFrame.Angles(0, 0, math.rad(-4)))

	-- Clutter, kept out of the turntable's way.
	pencil(folder, center, -50, 8, 12, Color3.fromRGB(250, 200, 50))
	pencil(folder, center, -58, 18, -20, Color3.fromRGB(80, 150, 230))
	crayon(folder, center, 42, 24, 160, Color3.fromRGB(230, 70, 70))
	crayon(folder, center, 50, 30, 200, Color3.fromRGB(80, 190, 110))
	crayon(folder, center, 38, 32, 120, Color3.fromRGB(150, 90, 210))
	block(folder, Vector3.new(9, 3.5, 5), center * CFrame.new(-28, 1.75, 30) * CFrame.Angles(0, math.rad(-18), 0), Color3.fromRGB(240, 150, 170)) -- eraser
	letterBlock(folder, center * CFrame.new(48, 4, -12) * CFrame.Angles(0, math.rad(-20), 0), Color3.fromRGB(220, 80, 70), "A")
	letterBlock(folder, center * CFrame.new(57, 4, -4) * CFrame.Angles(0, math.rad(-35), 0), Color3.fromRGB(70, 130, 220), "B")
	letterBlock(folder, center * CFrame.new(51, 12, -9) * CFrame.Angles(0, math.rad(-8), 0), Color3.fromRGB(245, 190, 60), "C")
	letterBlock(folder, center * CFrame.new(-44, 4, -26) * CFrame.Angles(0, math.rad(25), 0), Color3.fromRGB(90, 180, 110), "T")

	-- A warm desk-lamp glow over the turntable.
	local glow = block(folder, Vector3.new(1, 1, 1), center * CFrame.new(0, 40, 10), Color3.new(1, 1, 1))
	glow.Transparency = 1
	local light = Instance.new("PointLight")
	light.Range = 60
	light.Brightness = 1.2
	light.Color = Color3.fromRGB(255, 225, 180)
	light.Parent = glow

	local turntable = buildTurntable(folder, center)
	folder.Parent = workspace
	return {
		folder = folder,
		center = center,
		turntable = turntable,
	}
end

return GarageScene
