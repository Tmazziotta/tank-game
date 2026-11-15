--!strict
-- Brick Co. signature: every damaging hit knocks a few bricks off the hull. They fly away
-- from the shot and become ordinary debris. Shells pass through them (CanQuery off).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local DebrisService = require(script.Parent.DebrisService)

local BrickChips = {}

local random = Random.new()

-- `hull` was hit at `position` by a shell travelling along `direction`.
function BrickChips.burst(hull: BasePart, position: Vector3, direction: Vector3)
	local cfg = Config.Signatures.Brick
	-- Start just outside the hull surface so the chips don't spawn inside it.
	local out = (position - hull.Position)
	local start = hull.Position + (if out.Magnitude > 0.01 then out.Unit else Vector3.yAxis) * (out.Magnitude + 1)
	for _ = 1, cfg.ChipsPerHit do
		local chip = Instance.new("Part")
		chip.Name = "BrickChip"
		chip.Size = cfg.ChipSize
		chip.Color = hull.Color:Lerp(Color3.new(0, 0, 0), random:NextNumber(0, 0.2))
		chip.Material = Enum.Material.SmoothPlastic
		chip.CanQuery = false
		chip.CanTouch = false
		chip.CFrame = CFrame.new(start + random:NextUnitVector() * 0.5)
			* CFrame.Angles(random:NextNumber(0, 6.28), random:NextNumber(0, 6.28), 0)
		-- Mostly back toward the shooter and up, with spread.
		local fling = (-direction * 0.6 + Vector3.yAxis * 0.8 + random:NextUnitVector() * 0.5).Unit
		chip.AssemblyLinearVelocity = fling * cfg.ChipSpeed
		chip.AssemblyAngularVelocity = random:NextUnitVector() * 12
		DebrisService.add(chip)
	end
end

return BrickChips
