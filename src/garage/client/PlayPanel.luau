--!strict
-- Bottom-right: game mode dropdown (only 4v4 Battle for now; FFA and Practice greyed out),
-- party button (stub) and the big PLAY button with "Tier N queue · TankName".

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerDataTypes = require(ReplicatedStorage.Shared.PlayerDataTypes)
local ProfileClient = require(ReplicatedStorage.Shared.ProfileClient)
local TankCatalog = require(ReplicatedStorage.Shared.TankCatalog)
local Toy = require(script.Parent.Toy)

local PlayPanel = {}

PlayPanel.Width = 300
local PLAY_H = 102
local ROW_H = 56
local GAP = 10

type Mode = { id: string, label: string, enabled: boolean }
local MODES: { Mode } = {
	{ id = "Battle", label = "4v4 Battle", enabled = true },
	{ id = "FFA", label = "Free-for-all", enabled = false },
	{ id = "Practice", label = "Practice", enabled = false },
}

export type Handle = {
	play: Toy.Button,
	setBusy: (on: boolean, text: string?) -> (),
}

function PlayPanel.mount(parent: Instance, toast: (string) -> (), onPlay: () -> ()): Handle
	local holder = Toy.frame(parent, UDim2.new(1, -16, 1, -16), UDim2.fromOffset(PlayPanel.Width, PLAY_H + GAP + ROW_H))
	holder.Name = "PlayPanel"
	holder.AnchorPoint = Vector2.new(1, 1)
	holder.ZIndex = 2 -- the mode menu opens up over the tank card

	-- Mode dropdown.
	local modeW = PlayPanel.Width - ROW_H - GAP
	local mode = Toy.button(holder, "", 20, UDim2.new(), UDim2.fromOffset(modeW, ROW_H))
	mode.holder.Name = "Mode"
	local modeText = Toy.text(mode.face, MODES[1].label, 20, UDim2.fromOffset(14, 0), UDim2.new(1, -48, 1, 0))
	modeText.TextXAlignment = Enum.TextXAlignment.Left
	modeText.ZIndex = 3
	local chevron = Toy.text(mode.face, "▼", 16, UDim2.new(1, -36, 0, 0), UDim2.new(0, 26, 1, 0))
	chevron.ZIndex = 3

	local menu = Toy.panel(holder, UDim2.fromOffset(0, -GAP), UDim2.fromOffset(modeW, #MODES * 46 + 12 + Toy.Shadow))
	menu.holder.Name = "ModeMenu"
	menu.holder.AnchorPoint = Vector2.new(0, 1)
	menu.holder.Visible = false
	menu.holder.ZIndex = 20
	Toy.raise(menu.holder, 20)
	for index, m in MODES do
		local option = Instance.new("TextButton")
		option.Name = m.id
		option.BackgroundColor3 = Toy.Yellow
		option.BackgroundTransparency = if index == 1 then 0 else 1
		option.Position = UDim2.fromOffset(6, 6 + (index - 1) * 46)
		option.Size = UDim2.new(1, -12, 0, 42)
		option.Font = Toy.Font
		option.TextSize = 19
		option.Text = if m.enabled then `  {m.label}` else `  {m.label}  · Soon`
		option.TextXAlignment = Enum.TextXAlignment.Left
		option.TextColor3 = if m.enabled then Toy.Brown else Toy.Grey
		option.AutoButtonColor = m.enabled
		option.ZIndex = 25
		Toy.corner(option, 10)
		option.Parent = menu.face
		option.Activated:Connect(function()
			menu.holder.Visible = false
			if not m.enabled then
				toast(`{m.label} is coming soon`)
			end
		end)
	end
	mode.button.Activated:Connect(function()
		menu.holder.Visible = not menu.holder.Visible
	end)

	-- Party (stub).
	local party = Toy.button(holder, "👥", 26, UDim2.fromOffset(modeW + GAP, 0), UDim2.fromOffset(ROW_H, ROW_H))
	party.holder.Name = "Party"
	party.button.Activated:Connect(function()
		toast("Parties are coming soon")
	end)

	-- PLAY.
	local play = Toy.button(holder, "", 20, UDim2.fromOffset(0, ROW_H + GAP), UDim2.fromOffset(PlayPanel.Width, PLAY_H), Toy.Yellow, 20)
	play.holder.Name = "Play"
	play.stroke.Thickness = 5
	local title = Toy.text(play.face, "PLAY", 46, UDim2.fromOffset(0, 8), UDim2.new(1, 0, 0, 52))
	title.ZIndex = 3
	local sub = Toy.text(play.face, "", 17, UDim2.new(0, 10, 1, -34), UDim2.new(1, -20, 0, 22))
	sub.ZIndex = 3
	sub.TextTruncate = Enum.TextTruncate.AtEnd
	play.button.Activated:Connect(function()
		menu.holder.Visible = false
		onPlay()
	end)

	local function render(data: PlayerDataTypes.Data)
		local def = TankCatalog.get(data.SelectedTank)
		sub.Text = `Tier {Toy.tier(def.Tier)} queue · {def.DisplayName}`
	end
	ProfileClient.changed:Connect(render)
	local data = ProfileClient.get()
	if data then
		render(data)
	end

	local function setBusy(on: boolean, text: string?)
		title.Text = text or "PLAY"
		title.TextSize = if text then 30 else 46
		play.face.BackgroundColor3 = if on then Toy.Grey else Toy.Yellow
	end
	return { play = play, setBusy = setBusy }
end

return PlayPanel
