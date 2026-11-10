--!strict
-- Smooth terrain for a map: gentle drivable hills inside the arena, and a mountain range
-- around the outside of the boundary as a backdrop. Built from a height field and written
-- as voxels in slabs. Terrain never breaks (hard cover), so it's only rebuilt when the
-- map changes, not every round.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local MapKit = require(script.Parent.MapKit)

local TerrainBuilder = {}

local VOXEL = 4
local SLAB_COLUMNS = 16 -- voxel columns along X written per WriteVoxels call

local builtFor: string? = nil

type Column = { height: number, material: Enum.Material }

local function heightAt(def: MapKit.MapDef, terrain: MapKit.TerrainDef, x: number, z: number): (number, Enum.Material)
	local h, material = 0, terrain.hillMaterial
	for _, hill in terrain.hills do
		local p = hill.origin.Position
		local r = math.sqrt((x - p.X) ^ 2 + (z - p.Z) ^ 2)
		if r < hill.radius then
			-- Cosine bump: flat top, flat foot, steepest halfway out.
			h = math.max(h, hill.height * (1 + math.cos(math.pi * r / hill.radius)) / 2)
		end
	end
	local mountains = terrain.mountains
	if mountains then
		local outside = math.max(math.abs(x - def.center.X) - def.halfSize.X, math.abs(z - def.center.Z) - def.halfSize.Y)
		local start = Config.Maps.BoundaryThickness + Config.Terrain.MountainStart
		if outside > start then
			local t = math.clamp((outside - start) / Config.Terrain.MountainRise, 0, 1)
			local rough = 0.7 + 0.45 * math.noise(x / 90, z / 90, mountains.seed) + 0.2 * math.noise(x / 25, z / 25, mountains.seed + 7)
			local m = mountains.height * t ^ 0.7 * math.max(rough, 0.25)
			if m > h then
				h = m
				material = if mountains.peak and m > mountains.height * 0.75 then mountains.peak else mountains.material
			end
		end
	end
	return h, material
end

local function clear()
	workspace.Terrain:Clear()
	builtFor = nil
end

-- Build (or clear) terrain for `def`. Yields between slabs.
function TerrainBuilder.build(def: MapKit.MapDef)
	if builtFor == def.id then
		return
	end
	clear()
	local terrain = def.terrain
	if not terrain then
		builtFor = def.id
		return
	end
	if terrain.colors then
		for material, color in terrain.colors do
			workspace.Terrain:SetMaterialColor(material, color)
		end
	end

	local margin = if terrain.mountains then Config.Maps.GroundMargin else 0
	local function snap(v: number, up: boolean): number
		return if up then math.ceil(v / VOXEL) * VOXEL else math.floor(v / VOXEL) * VOXEL
	end
	local minX = snap(def.center.X - def.halfSize.X - margin, false)
	local maxX = snap(def.center.X + def.halfSize.X + margin, true)
	local minZ = snap(def.center.Z - def.halfSize.Y - margin, false)
	local maxZ = snap(def.center.Z + def.halfSize.Y + margin, true)
	local peak = 0
	for _, hill in terrain.hills do
		peak = math.max(peak, hill.height)
	end
	if terrain.mountains then
		peak = math.max(peak, terrain.mountains.height * 1.4)
	end
	local minY = -VOXEL -- one solid layer under the ground anchors the surface
	local maxY = snap(peak + VOXEL, true)
	local ny = (maxY - minY) // VOXEL
	local nz = (maxZ - minZ) // VOXEL

	local x0 = minX
	while x0 < maxX do
		local x1 = math.min(x0 + SLAB_COLUMNS * VOXEL, maxX)
		local nx = (x1 - x0) // VOXEL
		local materials: { { { Enum.Material } } } = table.create(nx)
		local occupancies: { { { number } } } = table.create(nx)
		local any = false
		for ix = 1, nx do
			local mx: { { Enum.Material } } = table.create(ny)
			local ox: { { number } } = table.create(ny)
			for iy = 1, ny do
				mx[iy] = table.create(nz, Enum.Material.Air)
				ox[iy] = table.create(nz, 0)
			end
			local cx = x0 + (ix - 0.5) * VOXEL
			for iz = 1, nz do
				local cz = minZ + (iz - 0.5) * VOXEL
				local h, material = heightAt(def, terrain, cx, cz)
				if h > 0.2 then
					any = true
					-- Measured: smooth terrain puts the surface half a voxel above a linear fill
					-- (writing height h shows up at h + 2), so fill to h - VOXEL / 2.
					local fill = h - VOXEL / 2
					for iy = 1, ny do
						local y0 = minY + (iy - 1) * VOXEL
						local occupancy = math.clamp((fill - y0) / VOXEL, 0, 1)
						if occupancy > 0 then
							mx[iy][iz] = material
							ox[iy][iz] = occupancy
						end
					end
				end
			end
			materials[ix] = mx
			occupancies[ix] = ox
		end
		if any then
			local region = Region3.new(Vector3.new(x0, minY, minZ), Vector3.new(x1, maxY, maxZ))
			workspace.Terrain:WriteVoxels(region, VOXEL, materials, occupancies)
		end
		x0 = x1
		task.wait()
	end
	builtFor = def.id
end

-- Ground height at (x, z): top of the terrain there, or 0 on flat ground.
function TerrainBuilder.groundY(x: number, z: number): number
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { workspace.Terrain }
	local result = workspace:Raycast(Vector3.new(x, 400, z), Vector3.new(0, -420, 0), params)
	return if result then math.max(result.Position.Y, 0) else 0
end

return TerrainBuilder
