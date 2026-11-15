--!strict
-- The toy-box unlock animation: a box in the line's color shakes, the lid pops off and the
-- new tank springs out. Tap (or wait) to close.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local TankCatalog = require(ReplicatedStorage.Shared.TankCatalog)
local TankPreview = require(script.Parent.TankPreview)
local Toy = require(script.Parent.Toy)

local UnboxFx = {}

local SHOW_TIME = 3.5

local function tween(instance: Instance, seconds: number, goal: { [string]: any }, style: Enum.EasingStyle?, direction: Enum.EasingDirection?): Tween
	local t = TweenService:Create(instance, TweenInfo.new(seconds, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out), goal)
	t:Play()
	return t
end

function UnboxFx.play(parent: Instance, tankId: string)
	local def = TankCatalog.get(tankId)
	local line = TankCatalog.line(def.Line)

	local overlay = Instance.new("TextButton") -- swallows input; tap to close
	overlay.Name = "Unbox"
	overlay.Text = ""
	overlay.AutoButtonColor = false
	overlay.BackgroundColor3 = Toy.Brown
	overlay.BackgroundTransparency = 0.2
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.ZIndex = 45
	overlay.Parent = parent

	local stage = Toy.frame(overlay, UDim2.fromScale(0.5, 0.5), UDim2.fromOffset(420, 360))
	stage.AnchorPoint = Vector2.new(0.5, 0.5)

	-- The box: body + lid, both in the line color.
	local box = Toy.panel(stage, UDim2.new(0.5, -110, 0, 150), UDim2.fromOffset(220, 170), line.Color, 12)
	Toy.text(box.face, "★", 60, UDim2.new(), UDim2.fromScale(1, 1), Color3.new(1, 1, 1))
	local lid = Toy.panel(stage, UDim2.new(0.5, -124, 0, 112), UDim2.fromOffset(248, 50), line.Color:Lerp(Color3.new(1, 1, 1), 0.25), 12)

	-- The prize (hidden until the lid is off).
	local prize = Toy.frame(stage, UDim2.new(), UDim2.fromScale(1, 1))
	prize.Visible = false
	local pop = Instance.new("UIScale")
	pop.Scale = 0.2
	pop.Parent = prize
	local title = Toy.text(prize, "NEW TANK!", 44, UDim2.new(), UDim2.new(1, 0, 0, 52), Toy.Yellow)
	title.TextStrokeTransparency = 0
	title.TextStrokeColor3 = Toy.Brown
	local preview = TankPreview.new(prize, UDim2.fromOffset(40, 56), UDim2.new(1, -80, 0, 220))
	preview.show(tankId)
	local name = Toy.text(prize, def.DisplayName, 34, UDim2.new(0, 0, 1, -76), UDim2.new(1, 0, 0, 40), Toy.Cream)
	name.TextStrokeTransparency = 0
	name.TextStrokeColor3 = Toy.Brown
	local info = Toy.text(prize, `{line.DisplayName} · {def.Class} · Tier {Toy.tier(def.Tier)}`, 20, UDim2.new(0, 0, 1, -34), UDim2.new(1, 0, 0, 26), Toy.Cream)
	info.TextStrokeTransparency = 0
	info.TextStrokeColor3 = Toy.Brown

	local closed = false
	local function close()
		if closed then
			return
		end
		closed = true
		overlay:Destroy()
	end
	overlay.Activated:Connect(close)

	task.spawn(function()
		-- Shake.
		for i = 1, 6 do
			local angle = if i % 2 == 0 then -7 else 7
			tween(box.holder, 0.07, { Rotation = angle })
			tween(lid.holder, 0.07, { Rotation = angle })
			task.wait(0.08)
		end
		tween(box.holder, 0.07, { Rotation = 0 })
		tween(lid.holder, 0.07, { Rotation = 0 })
		task.wait(0.15)
		if closed then
			return
		end
		-- Lid off, box drops away, tank springs out.
		tween(lid.holder, 0.35, { Position = lid.holder.Position + UDim2.fromOffset(120, -260), Rotation = 50 })
		tween(box.holder, 0.35, { Position = box.holder.Position + UDim2.fromOffset(0, 220) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		task.wait(0.2)
		prize.Visible = true
		tween(pop, 0.45, { Scale = 1 }, Enum.EasingStyle.Back)
		task.wait(0.4)
		lid.holder.Visible = false
		box.holder.Visible = false
		task.wait(SHOW_TIME)
		close()
	end)
end

return UnboxFx
