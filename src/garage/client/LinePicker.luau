--!strict
-- First join: "Choose your toy line". One card per line with its starter tank; picking one
-- (Hangar "PickLine") gives you that starter. Shown whenever your data has no line yet.
-- (The M12 tutorial adds a test drive of each starter before this choice.)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerDataTypes = require(ReplicatedStorage.Shared.PlayerDataTypes)
local ProfileClient = require(ReplicatedStorage.Shared.ProfileClient)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local TankCatalog = require(ReplicatedStorage.Shared.TankCatalog)
local TankPreview = require(script.Parent.TankPreview)
local Toy = require(script.Parent.Toy)

local LinePicker = {}

local CARD_W, CARD_H, GAP = 290, 330, 20

function LinePicker.mount(parent: Instance, toast: (string) -> ())
	-- Dimmed backdrop that swallows input (so the turntable doesn't spin underneath).
	local backdrop = Toy.frame(parent, UDim2.new(), UDim2.fromScale(1, 1), Toy.Brown, 0.45)
	backdrop.Name = "LinePicker"
	backdrop.Active = true
	backdrop.ZIndex = 40
	backdrop.Visible = false

	local count = #TankCatalog.lineOrder
	local width = count * CARD_W + (count - 1) * GAP
	local box = Toy.frame(backdrop, UDim2.fromScale(0.5, 0.5), UDim2.fromOffset(width, CARD_H + 70))
	box.Name = "Cards"
	box.AnchorPoint = Vector2.new(0.5, 0.5)
	local title = Toy.text(box, "Choose your toy line!", 40, UDim2.new(), UDim2.new(1, 0, 0, 50), Toy.Cream)
	title.TextStrokeTransparency = 0
	title.TextStrokeColor3 = Toy.Brown

	local busy = false
	for index, line in TankCatalog.lineOrder do
		local def = TankCatalog.line(line)
		local starter = TankCatalog.starterOf(line)
		local card = Toy.panel(box, UDim2.fromOffset((index - 1) * (CARD_W + GAP), 66), UDim2.fromOffset(CARD_W, CARD_H))
		card.holder.Name = `Line{line}`
		local stripe = Toy.frame(card.face, UDim2.new(), UDim2.new(1, 0, 0, 14), def.Color)
		Toy.corner(stripe, Toy.Radius)
		Toy.text(card.face, def.DisplayName, 28, UDim2.fromOffset(0, 20), UDim2.new(1, 0, 0, 34))
		local preview = TankPreview.new(card.face, UDim2.fromOffset(20, 58), UDim2.new(1, -40, 0, 120))
		preview.show(starter)
		local blurb = Toy.text(card.face, def.Blurb, 17, UDim2.fromOffset(16, 182), UDim2.new(1, -32, 0, 60), Toy.BrownSoft)
		blurb.TextWrapped = true
		local pick = Toy.button(card.face, `Pick {TankCatalog.get(starter).DisplayName}`, 22, UDim2.new(0, 16, 1, -70), UDim2.new(1, -32, 0, 56), def.Color, 14)
		pick.holder.Name = "Pick"
		pick.label.TextColor3 = Color3.new(1, 1, 1)
		pick.button.Activated:Connect(function()
			if busy then
				return
			end
			busy = true
			local ok, message = Remotes.GarageRequest:InvokeServer("PickLine", line)
			busy = false
			if not ok then
				toast(`Can't do that: {message or "unknown error"}`)
			end
		end)
	end

	local function render(data: PlayerDataTypes.Data)
		backdrop.Visible = data.Line == ""
	end
	ProfileClient.changed:Connect(render)
	local data = ProfileClient.get()
	if data then
		render(data)
	end
end

return LinePicker
