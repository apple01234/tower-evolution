--!strict
-- 맵/경로 생성. 그리드 좌표를 월드 좌표로 환산하고, 지역 테마에 맞춰 맵을 만든다.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local MapThemes = require(Shared:WaitForChild("MapThemes"))

local MapDecor = require(script.Parent:WaitForChild("MapDecor"))

local WorldSetup = {}

WorldSetup.ORIGIN = Vector3.new(0, 0, 0)

-- 경로 길이는 불변 → 최초 1회 캐시
local _pathLenCache: number? = nil

-- 그리드(col,row) -> 월드 Vector3
function WorldSetup.cellToWorld(col: number, row: number): Vector3
	local x = (col - (Config.GRID_COLS - 1) / 2) * Config.CELL_SIZE
	local z = (row - (Config.GRID_ROWS - 1) / 2) * Config.CELL_SIZE
	return WorldSetup.ORIGIN + Vector3.new(x, 0, z)
end

function WorldSetup.pathPoints(): { Vector3 }
	local pts = {}
	for _, p in Config.PATH do
		table.insert(pts, WorldSetup.cellToWorld(p[1], p[2]))
	end
	return pts
end

function WorldSetup.pathLength(): number
	if _pathLenCache then
		return _pathLenCache
	end
	local pts = WorldSetup.pathPoints()
	local total = 0
	for i = 2, #pts do
		total += (pts[i] - pts[i - 1]).Magnitude
	end
	_pathLenCache = total
	return total
end

-- 경로 위 위치 보간: t는 0..1
function WorldSetup.pointAt(t: number): Vector3
	local pts = WorldSetup.pathPoints()
	if #pts < 2 then
		return WorldSetup.ORIGIN
	end
	local clamped = math.clamp(t, 0, 1)
	local segLens = {}
	local total = 0
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

-- 조명/안개를 테마에 맞춤
local function applyAmbience(theme: any)
	local amb = MapThemes.toColor3(theme.ambient)
	local fog = MapThemes.toColor3(theme.fogColor)
	Lighting.Ambient = amb
	Lighting.OutdoorAmbient = amb
	Lighting.FogColor = fog
	Lighting.FogEnd = theme.fogEnd
	Lighting.ColorShift_Top = fog
end

local function part(parent: Instance, name: string, size: Vector3, cf: CFrame, mat: Enum.Material, color: Color3, collide: boolean?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	-- 기본은 충돌 없음(장식). 바닥/경로처럼 밟아야 하는 것은 collide=true 로 넘긴다.
	p.CanCollide = collide == true
	p.Size = size
	p.CFrame = cf
	p.Material = mat
	p.Color = color
	p.Parent = parent
	return p
end

-- 맵 생성. zoneId 로 테마를 고른다.
function WorldSetup.build(zoneId: string?)
	local theme = MapThemes.get(zoneId or "Midgard_Forest")

	local existing = workspace:FindFirstChild("TowerArena")
	if existing then
		existing:Destroy()
	end

	local arena = Instance.new("Folder")
	arena.Name = "TowerArena"
	arena.Parent = workspace

	local bounds = {
		x = Config.GRID_COLS * Config.CELL_SIZE + 24,
		z = Config.GRID_ROWS * Config.CELL_SIZE + 24,
	}

	-- 바닥 (밟을 수 있어야 한다: collide = true)
	local ground = part(
		arena,
		"Ground",
		Vector3.new(bounds.x, 2, bounds.z),
		CFrame.new(WorldSetup.ORIGIN - Vector3.new(0, 1, 0)),
		MapThemes.toMaterial(theme.groundMaterial),
		MapThemes.toColor3(theme.groundColor),
		true
	)
	ground.TopSurface = Enum.SurfaceType.Smooth

	-- 경로
	local pts = WorldSetup.pathPoints()
	for i = 2, #pts do
		local a, b = pts[i - 1], pts[i]
		part(
			arena,
			"Path",
			Vector3.new(Config.CELL_SIZE * 0.9, 0.4, (b - a).Magnitude),
			CFrame.lookAt((a + b) / 2, b) * CFrame.Angles(0, math.rad(90), 0),
			MapThemes.toMaterial(theme.pathMaterial),
			MapThemes.toColor3(theme.pathColor),
			false
		)
	end

	-- 스폰 / 기지 표식
	part(arena, "SpawnMark", Vector3.new(4, 0.5, 4),
		CFrame.new(pts[1] + Vector3.new(0, 0.3, 0)), Enum.Material.Neon, MapThemes.toColor3(theme.spawnColor))

	-- 실제 스폰 지점. 없으면 플레이어가 허공에 떨어져 바닥을 뚫고 낙하한다.
	-- 바닥 윗면(y=0)보다 살짝 위에 두고, 경로 시작점에서 옆으로 띄운다.
	local spawnPos = pts[1] + Vector3.new(0, 0.5, 10)
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "PlayerSpawn"
	spawn.Anchored = true
	spawn.CanCollide = true
	spawn.Size = Vector3.new(8, 1, 8)
	spawn.CFrame = CFrame.new(spawnPos)
	spawn.Material = Enum.Material.SmoothPlastic
	spawn.Color = MapThemes.toColor3(theme.spawnColor)
	spawn.TopSurface = Enum.SurfaceType.Smooth
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = arena

	part(arena, "BaseMark", Vector3.new(6, 1, 6),
		CFrame.new(pts[#pts] + Vector3.new(0, 0.5, 0)), Enum.Material.Neon, MapThemes.toColor3(theme.baseColor))

	-- 기지 코어 (상징물)
	local core = Instance.new("Part")
	core.Name = "BaseCore"
	core.Shape = Enum.PartType.Ball
	core.Anchored = true
	core.CanCollide = false
	core.Size = Vector3.new(5, 5, 5)
	core.CFrame = CFrame.new(pts[#pts] + Vector3.new(0, 4, 0))
	core.Material = Enum.Material.Neon
	core.Color = MapThemes.toColor3(theme.baseColor)
	core.Parent = arena

	-- 장식 (테마별 밀도, 시드로 항상 같은 배치)
	local seed = 0
	local zid = theme.zoneId
	for i = 1, #zid do
		seed += string.byte(zid, i) * i
	end
	MapDecor.build(arena, theme, bounds, pts, seed)

	applyAmbience(theme)

	return arena
end

return WorldSetup
