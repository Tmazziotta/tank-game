--!strict
-- Bottom-left loadout cards: a render of each loadout tank with its line-color stripe, tier,
-- name and class. Tapping a card drives that tank (the server validates). The selected card
-- is bigger with a yellow border and a SELECTED tag; the game-pass slot shows locked.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local PlayerDataTypes = require(ReplicatedStorage.Shared.PlayerDataTypes)
local ProfileClient = require(ReplicatedStorage.Shared.ProfileClient)
local Progression = require(ReplicatedStorage.Shared.Progression)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local TankCatalog = require(ReplicatedStorage.Shared.TankCatalog)
local TankPreview = require(script.Parent.TankPreview)
local Toy = require(script.Parent.Toy)

local LoadoutCards = {}

local SMALL = Vector2.new(140, 124)
local BIG = Vector2.new(170, 150)
local GAP = 12

type Card = {
	button: Toy.Button,
	preview: TankPreview.Preview,
	stripe: Frame,
	tier: TextLabel,
	name: TextLabel,
	class: TextLabel,
	tag: Frame,
}

local cards: { Card } = {}
local holder: Frame? = nil
local busy = false
local toast: (string) -> () = function(_message: string) end

local function select(slot: number)
	local data = ProfileClient.get()
	local id = data and data.Loadout[slot]
	if busy or not data or not id or data.SelectedTank == id then
		return
	end
	busy = true
	local ok, message = Remotes.GarageRequest:InvokeServer("Select", id)
	busy = false
	if not ok then
		toast(`Can't do that: {message or "unknown error"}`)
	end
end

-- A dashed outline made of short frames (UIStroke has no dash style).
local function dashes(parent: Frame, size: Vector2)
	local DASH, SPACE, T = 12, 8, 3
	local function run(horizontal: boolean, fixed: number, length: number)
		local at = 10
		while at + DASH <= length - 10 do
			local d = if horizontal
				then Toy.frame(parent, UDim2.fromOffset(at, fixed), UDim2.fromOffset(DASH, T), Toy.BrownSoft)
				else Toy.frame(parent, UDim2.fromOffset(fixed, at), UDim2.fromOffset(T, DASH), Toy.BrownSoft)
			Toy.corner(d, 2)
			at += DASH + SPACE
		end
	end
	run(true, 0, size.X)
	run(true, size.Y - T, size.X)
	run(false, 0, size.Y)
	run(false, size.X - T, size.Y)
end

local function newCard(parent: Instance, slot: number): Card
	local b = Toy.button(parent, "", 18, UDim2.new(), UDim2.fromOffset(SMALL.X, SMALL.Y + Toy.Shadow))
	b.holder.Name = `Slot{slot}`
	b.holder.LayoutOrder = slot
	local face = b.face
	face.ClipsDescendants = false

	local stripe = Toy.frame(face, UDim2.fromOffset(8, 8), UDim2.new(0, 8, 1, -16), Toy.Grey)
	Toy.corner(stripe, 4)
	stripe.ZIndex = 3
	local preview = TankPreview.new(face, UDim2.fromOffset(16, 4), UDim2.new(1, -20, 1, -50))
	preview.frame.ZIndex = 3
	local tier = Toy.text(face, "", 18, UDim2.new(1, -36, 0, 6), UDim2.fromOffset(30, 26))
	tier.BackgroundColor3 = Toy.Yellow
	tier.BackgroundTransparency = 0
	tier.ZIndex = 3
	Toy.corner(tier, 8)
	Toy.outline(tier, 2)
	local name = Toy.text(face, "", 19, UDim2.new(0, 20, 1, -46), UDim2.new(1, -26, 0, 22))
	name.TextXAlignment = Enum.TextXAlignment.Left
	name.TextTruncate = Enum.TextTruncate.AtEnd
	name.ZIndex = 3
	local class = Toy.text(face, "", 15, UDim2.new(0, 20, 1, -24), UDim2.new(1, -26, 0, 18), Toy.BrownSoft)
	class.TextXAlignment = Enum.TextXAlignment.Left
	class.ZIndex = 3

	local tag = Toy.frame(b.holder, UDim2.new(0.5, 0, 0, -14), UDim2.fromOffset(112, 26), Toy.Yellow)
	tag.AnchorPoint = Vector2.new(0.5, 0)
	tag.ZIndex = 5
	Toy.corner(tag, 13)
	Toy.outline(tag, 3)
	local tagText = Toy.text(tag, "✔ SELECTED", 16, UDim2.new(), UDim2.fromScale(1, 1))
	tagText.ZIndex = 5

	b.button.Activated:Connect(function()
		select(slot)
	end)
	return { button = b, preview = preview, stripe = stripe, tier = tier, name = name, class = class, tag = tag }
end

local function newLockedCard(parent: Instance, order: number)
	local card = Toy.frame(parent, UDim2.new(), UDim2.fromOffset(SMALL.X, SMALL.Y), Toy.CreamDark, 0.1)
	card.Name = "LockedSlot"
	card.LayoutOrder = order
	Toy.corner(card, Toy.Radius)
	dashes(card, SMALL)
	Toy.text(card, "🔒", 34, UDim2.fromOffset(0, 22), UDim2.new(1, 0, 0, 40))
	Toy.text(card, "Game pass", 18, UDim2.fromOffset(0, 68), UDim2.new(1, 0, 0, 22), Toy.BrownSoft)
	local tap = Instance.new("TextButton")
	tap.Text = ""
	tap.BackgroundTransparency = 1
	tap.Size = UDim2.fromScale(1, 1)
	tap.Parent = card
	tap.Activated:Connect(function()
		toast("An extra loadout slot is coming with a game pass")
	end)
end

local function render(data: PlayerDataTypes.Data)
	for slot, card in cards do
		local id = data.Loadout[slot]
		card.button.holder.Visible = id ~= nil
		if id then
			local def = TankCatalog.get(id)
			local selected = data.SelectedTank == id
			local size = if selected then BIG else SMALL
			card.button.holder.Size = UDim2.fromOffset(size.X, size.Y + Toy.Shadow)
			card.button.stroke.Color = if selected then Toy.Yellow else Toy.Brown
			card.button.stroke.Thickness = if selected then 6 else Toy.Outline
			card.tag.Visible = selected
			local line = TankCatalog.line(def.Line)
			card.preview.show(id, Progression.equipped(data, id))
			card.stripe.BackgroundColor3 = line.Color
			card.tier.Text = Toy.tier(def.Tier)
			card.name.Text = def.DisplayName
			card.class.Text = `{def.Class} · {line.DisplayName}`
		end
	end
end

-- Cards sit bottom-left, starting `left` reference pixels from the edge.
function LoadoutCards.mount(parent: Instance, left: number, showToast: (string) -> ())
	toast = showToast
	local frame = Toy.frame(parent, UDim2.new(0, left, 1, -16), UDim2.fromOffset(0, BIG.Y + Toy.Shadow))
	frame.Name = "Loadout"
	frame.AnchorPoint = Vector2.new(0, 1)
	frame.AutomaticSize = Enum.AutomaticSize.X
	holder = frame
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, GAP)
	layout.Parent = frame
	for slot = 1, Config.Garage.LoadoutSlots do
		cards[slot] = newCard(frame, slot)
	end
	for i = 1, Config.Garage.LockedSlots do
		newLockedCard(frame, Config.Garage.LoadoutSlots + i)
	end
	ProfileClient.changed:Connect(render)
	local data = ProfileClient.get()
	if data then
		render(data)
	end
end

function LoadoutCards.setLeft(left: number)
	local frame = holder
	if frame then
		frame.Position = UDim2.new(0, left, 1, -16)
	end
end

return LoadoutCards
