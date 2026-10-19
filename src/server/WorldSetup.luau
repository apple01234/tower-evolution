--!strict
-- 맵/경로 생성. 그리드 좌표를 월드 좌표로 환산한다.
local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config"))

local WorldSetup = {}

WorldSetup.ORIGIN = Vector3.new(0, 0, 0)

-- 그리드(col,row) -> 월드 Vector3 (셀 중심)
function WorldSetup.cellToWorld(col: number, row: number): Vector3
	local x = (col - (Config.GRID_COLS - 1) / 2) * Config.CELL_SIZE
	local z = (row - (Config.GRID_ROWS - 1) / 2) * Config.CELL_SIZE
	return WorldSetup.ORIGIN + Vector3.new(x, 0, z)
end

-- 경로를 월드 좌표 배열로
function WorldSetup.pathPoints(): { Vector3 }
	local pts = {}
	for _, p in Config.PATH do
		table.insert(pts, WorldSetup.cellToWorld(p[1], p[2]))
	end
	return pts
end

-- 경로 총 길이 (스폰 위치 계산용)
function WorldSetup.pathLength(): number
	local pts = WorldSetup.pathPoints()
	local total = 0
	for i = 2, #pts do
		total += (pts[i] - pts[i - 1]).Magnitude
	end
	return total
end

-- 경로 위 위치 보간: t는 0..1
function WorldSetup.pointAt(t: number): Vector3
	local pts = WorldSetup.pathPoints()
	if #pts < 2 then
		return WorldSetup.ORIGIN
	end
	local clamped = math.clamp(t, 0, 1)
	local total = 0
	local segLens = {}
	for i = 2, #pts do
		local d = (pts[i] - pts[i - 1]).Magnitude
		table.insert(segLens, d)
		total += d
	end
	if total <= 0 then
		return pts[1]
	end
	local target = clamped * total
	local acc = 0
	for i = 1, #segLens do
		if acc + segLens[i] >= target then
			local a = (target - acc) / segLens[i]
			return pts[i]:Lerp(pts[i + 1], a)
		end
		acc += segLens[i]
	end
	return pts[#pts]
end

function WorldSetup.build()
	local existing = workspace:FindFirstChild("TowerArena")
	if existing then
		existing:Destroy()
	end

	local arena = Instance.new("Folder")
	arena.Name = "TowerArena"
	arena.Parent = workspace

	-- 바닥
	local ground = Instance.new("Part")
	ground.Name = "Ground"
	ground.Anchored = true
	ground.Size = Vector3.new(
		Config.GRID_COLS * Config.CELL_SIZE + 20,
		2,
		Config.GRID_ROWS * Config.CELL_SIZE + 20
	)
	ground.Position = WorldSetup.ORIGIN - Vector3.new(0, 1, 0)
	ground.Material = Enum.Material.Grass
	ground.Color = Color3.fromRGB(46, 82, 40)
	ground.TopSurface = Enum.SurfaceType.Smooth
	ground.Parent = arena

	-- 경로 표시
	local pts = WorldSetup.pathPoints()
	for i = 2, #pts do
		local a, b = pts[i - 1], pts[i]
		local seg = Instance.new("Part")
		seg.Name = "Path"
		seg.Anchored = true
		seg.CanCollide = false
		seg.Size = Vector3.new(Config.CELL_SIZE * 0.9, 0.4, (b - a).Magnitude)
		seg.CFrame = CFrame.lookAt((a + b) / 2, b) * CFrame.Angles(0, math.rad(90), 0)
		seg.Material = Enum.Material.Slate
		seg.Color = Color3.fromRGB(120, 105, 80)
		seg.Parent = arena
	end

	-- 스폰/종착 지점 표식
	local spawnMark = Instance.new("Part")
	spawnMark.Name = "SpawnMark"
	spawnMark.Anchored = true
	spawnMark.CanCollide = false
	spawnMark.Size = Vector3.new(4, 0.5, 4)
	spawnMark.Position = pts[1]
	spawnMark.Material = Enum.Material.Neon
	spawnMark.Color = Color3.fromRGB(200, 60, 60)
	spawnMark.Parent = arena

	local baseMark = Instance.new("Part")
	baseMark.Name = "BaseMark"
	baseMark.Anchored = true
	baseMark.CanCollide = false
	baseMark.Size = Vector3.new(6, 1, 6)
	baseMark.Position = pts[#pts]
	baseMark.Material = Enum.Material.Neon
	baseMark.Color = Color3.fromRGB(80, 180, 255)
	baseMark.Parent = arena

	return arena
end

return WorldSetup
