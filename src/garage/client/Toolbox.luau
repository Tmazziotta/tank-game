--!strict
-- Toolbox (mods): one owned tank's mod tree. Each row is pick 1 of 2; tap a mod to unlock it
-- with that tank's XP (rows open top to bottom) or to equip one you've unlocked. The header
-- flips between your tanks and shows tank XP and progress to elite. The server (Hangar)
-- validates every change.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local PlayerDataTypes = require(ReplicatedStorage.Shared.PlayerDataTypes)
local ProfileClient = require(ReplicatedStorage.Shared.ProfileClient)
local Progression = require(ReplicatedStorage.Shared.Progression)
local Requests = require(script.Parent.Requests)
local TankCatalog = require(ReplicatedStorage.Shared.TankCatalog)
local Toy = require(script.Parent.Toy)

type Data = PlayerDataTypes.Data

local Toolbox = {}

local NATURAL = Vector2.new(960, 430)
local ROW_TOP, ROW_H, ROW_GAP = 76, 80, 10
local CARDS_X = 66
local CARD_GAP = 12

type Card = { button: Toy.Button, name: TextLabel, blurb: TextLabel, pill: Frame, pillText: TextLabel, pop: UIScale, modId: string }
type Row = { badge: Frame, badgeText: TextLabel, cards: { Card } }

local rows: { Row } = {}
local focused = ""
local root: Frame? = nil
local nameLabel: TextLabel? = nil
local infoLabel: TextLabel? = nil
local xpLabel: TextLabel? = nil
local eliteLabel: TextLabel? = nil
local eliteFill: Frame? = nil
local toast: (string) -> () = function(_message: string) end

local function owned(data: Data): { string }
	local list = {}
	for _, id in TankCatalog.order do
		if data.OwnedTanks[id] then
			table.insert(list, id)
		end
	end
	return list
end

local function setPill(card: Card, text: string, color: Color3, textColor: Color3)
	card.pillText.Text = text
	card.pillText.TextColor3 = textColor
	card.pill.BackgroundColor3 = color
end

local function render()
	local data = ProfileClient.get()
	if not data or not root then
		return
	end
	if not data.OwnedTanks[focused] then
		focused = if data.OwnedTanks[data.SelectedTank] then data.SelectedTank else owned(data)[1] or ""
	end
	if focused == "" then
		return
	end
	local id = focused
	local def = TankCatalog.get(id)
	local line = TankCatalog.line(def.Line)
	local equipped = Progression.equipped(data, id)
	local done = Progression.rowsDone(data, id)
	if nameLabel and infoLabel and xpLabel and eliteLabel and eliteFill then
		nameLabel.Text = def.DisplayName
		infoLabel.Text = `{line.DisplayName} · {def.Class} · Tier {Toy.tier(def.Tier)}`
		xpLabel.Text = `{Progression.tankXP(data, id)} tank XP`
		if done >= Config.Mods.Rows then
			local next = {}
			for _, child in TankCatalog.children(id) do
				table.insert(next, TankCatalog.get(child).DisplayName)
			end
			eliteLabel.Text = if #next > 0 then `★ ELITE: unlocks {table.concat(next, ", ")}` else "★ ELITE"
		else
			eliteLabel.Text = `Mod rows to Elite: {done} / {Config.Mods.Rows}`
		end
		eliteFill.Size = UDim2.fromScale(done / Config.Mods.Rows, 1)
		eliteFill.Visible = done > 0
	end

	for r, entry in TankCatalog.modRows(id) do
		local row = rows[r]
		if not row then
			continue
		end
		local rowDone = Progression.rowDone(data, id, r)
		local rowOpen = r == 1 or Progression.rowDone(data, id, r - 1)
		row.badge.BackgroundColor3 = if rowDone then Toy.Yellow elseif rowOpen then Toy.Cream else Toy.Grey
		for slot, modId in entry do
			local card = row.cards[slot]
			local mod = TankCatalog.mod(modId)
			card.modId = modId
			card.name.Text = mod.DisplayName
			card.blurb.Text = mod.Blurb
			local isOn = table.find(equipped, modId) ~= nil
			local unlocked = Progression.isUnlocked(data, id, modId)
			local canUnlock, _, cost = Progression.canUnlockMod(data, id, modId)
			card.button.face.BackgroundColor3 = if isOn then Toy.YellowLight elseif rowOpen then Toy.Cream else Toy.CreamDark
			card.button.stroke.Color = if isOn then Toy.Yellow else Toy.Brown
			card.button.stroke.Thickness = if isOn then 6 else Toy.Outline
			card.name.TextColor3 = if rowOpen then Toy.Brown else Toy.BrownSoft
			if isOn then
				setPill(card, "✔ ON", Toy.Yellow, Toy.Brown)
			elseif unlocked then
				setPill(card, "Equip", Toy.Cream, Toy.Brown)
			elseif not rowOpen then
				setPill(card, "🔒 Locked", Toy.Grey, Toy.Brown)
			elseif canUnlock then
				setPill(card, `Unlock · {cost} XP`, Toy.Green, Color3.new(1, 1, 1))
			else
				setPill(card, `{cost} XP`, Toy.Grey, Toy.Brown)
			end
		end
	end
end

local function onCard(card: Card)
	local data = ProfileClient.get()
	local id = focused
	if not data or card.modId == "" or id == "" then
		return
	end
	if Progression.isUnlocked(data, id, card.modId) then
		if not table.find(Progression.equipped(data, id), card.modId) then
			Requests.send("EquipMod", id, card.modId)
		end
		return
	end
	local ok, reason = Progression.canUnlockMod(data, id, card.modId)
	if not ok then
		toast(reason or "Can't unlock that yet")
		return
	end
	if Requests.send("UnlockMod", id, card.modId) then
		card.pop.Scale = 1.12
		TweenService:Create(card.pop, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	end
end

local function cycle(step: number)
	local data = ProfileClient.get()
	if not data then
		return
	end
	local list = owned(data)
	if #list == 0 then
		return
	end
	local index = table.find(list, focused) or 1
	focused = list[(index - 1 + step) % #list + 1]
	render()
end

-- Build ------------------------------------------------------------------------------

local function buildHeader(parent: Instance)
	local prev = Toy.button(parent, "◀", 24, UDim2.new(), UDim2.fromOffset(54, 56 + Toy.Shadow), Toy.Cream, 14)
	prev.holder.Name = "Prev"
	prev.button.Activated:Connect(function()
		cycle(-1)
	end)
	local tank = Toy.panel(parent, UDim2.fromOffset(62, 0), UDim2.fromOffset(330, 56 + Toy.Shadow))
	local name = Toy.text(tank.face, "", 24, UDim2.fromOffset(14, 2), UDim2.new(1, -28, 0, 28))
	name.TextXAlignment = Enum.TextXAlignment.Left
	local info = Toy.text(tank.face, "", 15, UDim2.fromOffset(14, 30), UDim2.new(1, -28, 0, 20), Toy.BrownSoft)
	info.TextXAlignment = Enum.TextXAlignment.Left
	local nextButton = Toy.button(parent, "▶", 24, UDim2.fromOffset(400, 0), UDim2.fromOffset(54, 56 + Toy.Shadow), Toy.Cream, 14)
	nextButton.holder.Name = "Next"
	nextButton.button.Activated:Connect(function()
		cycle(1)
	end)

	local xp = Toy.panel(parent, UDim2.fromOffset(470, 0), UDim2.fromOffset(190, 56 + Toy.Shadow), Toy.YellowLight)
	local xpText = Toy.text(xp.face, "", 20, UDim2.new(), UDim2.fromScale(1, 1))

	local elite = Toy.panel(parent, UDim2.fromOffset(670, 0), UDim2.fromOffset(290, 56 + Toy.Shadow))
	local eliteText = Toy.text(elite.face, "", 15, UDim2.fromOffset(12, 4), UDim2.new(1, -24, 0, 20))
	eliteText.TextXAlignment = Enum.TextXAlignment.Left
	eliteText.TextTruncate = Enum.TextTruncate.AtEnd
	local track = Toy.frame(elite.face, UDim2.fromOffset(12, 28), UDim2.new(1, -24, 0, 16), Toy.CreamDark)
	Toy.corner(track, 8)
	Toy.outline(track, 2)
	local fill = Toy.frame(track, UDim2.new(), UDim2.fromScale(0, 1), Toy.Green)
	Toy.corner(fill, 8)

	nameLabel, infoLabel, xpLabel, eliteLabel, eliteFill = name, info, xpText, eliteText, fill
end

local function buildRows(parent: Instance)
	local cardW = (NATURAL.X - CARDS_X - CARD_GAP) / 2
	for r = 1, Config.Mods.Rows do
		local y = ROW_TOP + (r - 1) * (ROW_H + ROW_GAP)
		if r > 1 then
			local link = Toy.frame(parent, UDim2.fromOffset(24, y - ROW_GAP - 20), UDim2.fromOffset(5, ROW_GAP + 24), Toy.BrownSoft)
			Toy.corner(link, 2)
		end
		local badge = Toy.frame(parent, UDim2.fromOffset(4, y + (ROW_H - 50) / 2), UDim2.fromOffset(50, 50), Toy.Cream)
		Toy.corner(badge, 25)
		Toy.outline(badge, 4)
		local badgeText = Toy.text(badge, tostring(r), 24, UDim2.new(), UDim2.fromScale(1, 1))
		local cards = {}
		for slot = 1, 2 do
			local b = Toy.button(parent, "", 18, UDim2.fromOffset(CARDS_X + (slot - 1) * (cardW + CARD_GAP), y), UDim2.fromOffset(cardW, ROW_H), Toy.Cream, 14)
			b.holder.Name = `Row{r}Mod{slot}`
			local pop = Instance.new("UIScale")
			pop.Parent = b.holder
			local name = Toy.text(b.face, "", 21, UDim2.fromOffset(14, 6), UDim2.new(1, -160, 0, 26))
			name.TextXAlignment = Enum.TextXAlignment.Left
			name.ZIndex = 3
			local blurb = Toy.text(b.face, "", 14, UDim2.fromOffset(14, 32), UDim2.new(1, -160, 0, 36), Toy.BrownSoft)
			blurb.TextXAlignment = Enum.TextXAlignment.Left
			blurb.TextYAlignment = Enum.TextYAlignment.Top
			blurb.TextWrapped = true
			blurb.ZIndex = 3
			local pill = Toy.frame(b.face, UDim2.new(1, -140, 0.5, -18), UDim2.fromOffset(128, 36), Toy.Grey)
			pill.ZIndex = 3
			Toy.corner(pill, 18)
			Toy.outline(pill, 3)
			local pillText = Toy.text(pill, "", 16, UDim2.new(), UDim2.fromScale(1, 1))
			pillText.ZIndex = 3
			local card: Card = { button = b, name = name, blurb = blurb, pill = pill, pillText = pillText, pop = pop, modId = "" }
			b.button.Activated:Connect(function()
				onCard(card)
			end)
			cards[slot] = card
		end
		rows[r] = { badge = badge, badgeText = badgeText, cards = cards }
	end
end

-- Build the Toolbox inside `parent` (its tab).
function Toolbox.mount(parent: GuiObject, showToast: (string) -> ())
	toast = showToast
	local frame = Toy.frame(parent, UDim2.fromScale(0.5, 0), UDim2.fromOffset(NATURAL.X, NATURAL.Y))
	frame.Name = "Toolbox"
	frame.AnchorPoint = Vector2.new(0.5, 0)
	root = frame
	buildHeader(frame)
	buildRows(frame)
	Toy.fit(frame)
	ProfileClient.changed:Connect(function(_data: Data)
		render()
	end)
	render()
end

-- Opening the tab, on `tankId` (default: the tank you're driving).
function Toolbox.show(tankId: string?)
	local data = ProfileClient.get()
	if tankId then
		focused = tankId
	elseif data then
		focused = data.SelectedTank
	end
	render()
end

return Toolbox
