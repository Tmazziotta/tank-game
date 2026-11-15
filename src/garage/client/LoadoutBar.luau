--!strict
-- The loadout bar: one card per loadout slot showing its tank. Tap a card to drive that
-- tank (it goes on the turntable); tap its EDIT button to swap a different owned tank into the
-- slot from a picker. The server (Hangar) validates every change.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerDataTypes = require(ReplicatedStorage.Shared.PlayerDataTypes)
local ProfileClient = require(ReplicatedStorage.Shared.ProfileClient)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local TankCatalog = require(ReplicatedStorage.Shared.TankCatalog)
local TankClass = require(ReplicatedStorage.Shared.TankClass)
local UiKit = require(script.Parent.UiKit)

type Data = PlayerDataTypes.Data

local LoadoutBar = {}

local CARD_W, CARD_H, GAP = 176, 96, 12
local PICK_W, PICK_H = 168, 58

type Card = { button: TextButton, stroke: UIStroke, name: TextLabel, info: TextLabel, edit: TextButton }

local cards: { Card } = {}
local bar: Frame? = nil
local picker: Frame? = nil
local pickerGrid: Frame? = nil
local pickerTitle: TextLabel? = nil
local pickingSlot = 0
local toast: (string) -> () = function(_message: string) end
local busy = false

local function request(action: string, tankId: string, extra: number?)
	if busy then
		return
	end
	busy = true
	local ok, message = Remotes.GarageRequest:InvokeServer(action, tankId, extra)
	busy = false
	if not ok then
		toast(`Can't do that: {message or "unknown error"}`)
	end
end

local function describe(id: string): string
	local def = TankCatalog.get(id)
	return `{TankClass.get(def.Class).DisplayName} · Tier {UiKit.tier(def.Tier)}`
end

local function closePicker()
	local p = picker
	if p then
		p.Visible = false
	end
	pickingSlot = 0
end

local function openPicker(slot: number)
	local data = ProfileClient.get()
	local p, grid, title = picker, pickerGrid, pickerTitle
	if not data or not p or not grid or not title then
		return
	end
	pickingSlot = slot
	title.Text = `SLOT {slot}: PICK A TANK`
	for _, child in grid:GetChildren() do
		if child:IsA("GuiButton") then
			child:Destroy()
		end
	end
	local index = 0
	for _, id in TankCatalog.order do
		if data.OwnedTanks[id] then
			local col, row = index % 3, index // 3
			index += 1
			local current = data.Loadout[slot] == id
			local b = UiKit.button(
				grid,
				"",
				18,
				UDim2.fromOffset(col * (PICK_W + 10), row * (PICK_H + 10)),
				UDim2.fromOffset(PICK_W, PICK_H),
				if current then UiKit.Gold else UiKit.PanelLight
			)
			UiKit.label(b, TankCatalog.get(id).DisplayName, 20, UDim2.fromOffset(0, 6), UDim2.new(1, 0, 0, 24))
			local info = UiKit.label(b, describe(id), 13, UDim2.fromOffset(0, 32), UDim2.new(1, 0, 0, 18))
			info.TextColor3 = if current then Color3.new(1, 1, 1) else UiKit.Muted
			b.Name = id
			b.Activated:Connect(function()
				closePicker()
				if not current then
					request("SetSlot", id, slot)
				end
			end)
		end
	end
	p.Visible = true
end

local function render(data: Data)
	for slot, card in cards do
		local id = data.Loadout[slot]
		if id then
			local selected = data.SelectedTank == id
			card.button.Visible = true
			card.name.Text = TankCatalog.get(id).DisplayName
			card.info.Text = if selected then "DRIVING" else describe(id)
			card.info.TextColor3 = if selected then UiKit.Gold else UiKit.Muted
			card.stroke.Color = if selected then UiKit.Gold else UiKit.Disabled
			card.stroke.Thickness = if selected then 4 else 2
		else
			card.button.Visible = false
		end
	end
end

-- Build the bar (bottom-center of `parent`) and the slot picker (centered in `overlay`).
function LoadoutBar.mount(parent: Instance, overlay: Instance, slots: number, showToast: (string) -> ())
	toast = showToast
	local width = slots * CARD_W + (slots - 1) * GAP
	local frame = UiKit.frame(parent, UDim2.new(0.5, -width / 2 - 120, 1, -CARD_H - 16), UDim2.fromOffset(width, CARD_H), Color3.new(), 1)
	frame.Name = "LoadoutBar"
	bar = frame
	for slot = 1, slots do
		local b = UiKit.button(frame, "", 18, UDim2.fromOffset((slot - 1) * (CARD_W + GAP), 0), UDim2.fromOffset(CARD_W, CARD_H), UiKit.Panel)
		b.BackgroundTransparency = 0.1
		b.Name = `Slot{slot}`
		local stroke = UiKit.stroke(b, UiKit.Disabled, 2)
		local name = UiKit.label(b, "", 24, UDim2.fromOffset(0, 34), UDim2.new(1, 0, 0, 28))
		local info = UiKit.label(b, "", 17, UDim2.fromOffset(0, 66), UDim2.new(1, 0, 0, 20))
		local edit = UiKit.button(b, "EDIT", 14, UDim2.new(1, -56, 0, 6), UDim2.fromOffset(50, 30), UiKit.PanelLight)
		edit.ZIndex = 2
		edit.Name = "Edit"
		cards[slot] = { button = b, stroke = stroke, name = name, info = info, edit = edit }
		b.Activated:Connect(function()
			local data = ProfileClient.get()
			local id = data and data.Loadout[slot]
			if id and data and data.SelectedTank ~= id then
				request("Select", id)
			end
		end)
		edit.Activated:Connect(function()
			if pickingSlot == slot then
				closePicker()
			else
				openPicker(slot)
			end
		end)
	end

	-- Slot picker popup.
	local pickW = 3 * PICK_W + 2 * 10 + 40
	local p = UiKit.frame(overlay, UDim2.new(0.5, -pickW / 2, 0.5, -170), UDim2.fromOffset(pickW, 330), UiKit.Panel, 0.05)
	p.Name = "SlotPicker"
	p.Active = true -- swallow clicks so they don't turn the turntable
	p.Visible = false
	p.ZIndex = 5
	UiKit.corner(p, 16)
	pickerTitle = UiKit.label(p, "", 24, UDim2.fromOffset(0, 12), UDim2.new(1, 0, 0, 30))
	local grid = UiKit.frame(p, UDim2.fromOffset(20, 56), UDim2.new(1, -40, 0, 3 * (PICK_H + 10)), Color3.new(), 1)
	grid.Name = "Grid"
	pickerGrid = grid
	local cancel = UiKit.button(p, "Cancel", 18, UDim2.new(0.5, -70, 1, -50), UDim2.fromOffset(140, 38), UiKit.Disabled)
	cancel.Activated:Connect(closePicker)
	picker = p

	ProfileClient.changed:Connect(render)
	local data = ProfileClient.get()
	if data then
		render(data)
	end
end

function LoadoutBar.setVisible(on: boolean)
	local frame = bar
	if frame then
		frame.Visible = on
	end
	if not on then
		closePicker()
	end
end

return LoadoutBar
