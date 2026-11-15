--!strict
-- Top-left player card: level badge, display name, XP bar and "x / y XP".

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerDataTypes = require(ReplicatedStorage.Shared.PlayerDataTypes)
local ProfileClient = require(ReplicatedStorage.Shared.ProfileClient)
local Progression = require(ReplicatedStorage.Shared.Progression)
local Toy = require(script.Parent.Toy)

local PlayerCard = {}

PlayerCard.Size = Vector2.new(330, 96)

function PlayerCard.mount(parent: Instance)
	local panel = Toy.panel(parent, UDim2.fromOffset(16, 12), UDim2.fromOffset(PlayerCard.Size.X, PlayerCard.Size.Y))
	panel.holder.Name = "PlayerCard"
	local face = panel.face

	local badge = Toy.frame(face, UDim2.fromOffset(12, 12), UDim2.fromOffset(64, 64), Toy.Yellow)
	Toy.corner(badge, 32)
	Toy.outline(badge, 4)
	local level = Toy.text(badge, "1", 30, UDim2.new(), UDim2.fromScale(1, 1))
	local tag = Toy.text(badge, "LVL", 12, UDim2.new(0.5, 0, 1, -8), UDim2.fromOffset(40, 16), Toy.Brown)
	tag.AnchorPoint = Vector2.new(0.5, 0)
	tag.BackgroundColor3 = Toy.Cream
	tag.BackgroundTransparency = 0
	Toy.corner(tag, 8)
	Toy.outline(tag, 2)

	local name = Toy.text(face, Players.LocalPlayer.DisplayName, 24, UDim2.fromOffset(88, 10), UDim2.new(1, -100, 0, 30))
	name.TextXAlignment = Enum.TextXAlignment.Left
	name.TextTruncate = Enum.TextTruncate.AtEnd

	local track = Toy.frame(face, UDim2.fromOffset(88, 46), UDim2.new(1, -102, 0, 28), Toy.CreamDark)
	Toy.corner(track, 14)
	Toy.outline(track, 3)
	local fill = Toy.frame(track, UDim2.new(), UDim2.fromScale(0, 1), Toy.Yellow)
	Toy.corner(fill, 14)
	local xp = Toy.text(track, "", 16, UDim2.new(), UDim2.fromScale(1, 1))
	xp.ZIndex = 2

	local function render(data: PlayerDataTypes.Data)
		local lvl = Progression.levelForXP(data.XP)
		level.Text = tostring(lvl)
		local floor = Progression.xpForLevel(lvl)
		local span = math.max(Progression.xpForLevel(lvl + 1) - floor, 1)
		local into = data.XP - floor
		fill.Size = UDim2.fromScale(math.clamp(into / span, 0.04, 1), 1)
		xp.Text = `{into} / {span} XP`
	end
	ProfileClient.changed:Connect(render)
	local data = ProfileClient.get()
	if data then
		render(data)
	end
end

return PlayerCard
