--!strict
-- Static level data: where things go. Building code lives elsewhere.

local MapLayout = {}

local CENTER = Vector3.new(0, 0, 20)

local function facingCenter(x: number, z: number): CFrame
	local pos = Vector3.new(x, 0.1, z)
	return CFrame.lookAt(pos, Vector3.new(CENTER.X, pos.Y, CENTER.Z))
end

MapLayout.SpawnPoints = {
	facingCenter(0, -60),
	facingCenter(-70, -45),
	facingCenter(70, -45),
	facingCenter(0, 130),
}

return MapLayout
