-- Workspace 사전 배치 빌더
--
-- 사용자 지시: "그냥 워크스페이스에 에셋 배치하는 방식 ㄱㄱ"
--   -> 런타임에 WorldSetup.build() 로 만들던 맵/장식을 빌드 타임에 Workspace 에 굽는다.
--      Studio 에서 열자마자 보이고, Play 하지 않아도 구조를 확인할 수 있다.
--
-- 이 스크립트는 assets_clean/*.rbxm 을 읽어 Config/MapThemes 의 좌표 규칙대로
-- Workspace.TowerArena 아래에 배치한 뒤 하나의 .rbxm 으로 저장한다.
-- Rojo 는 이 파일을 Workspace 에 그대로 넣는다.
--
-- 사용: lune run tools/bake-workspace.luau assets_clean workspace_baked
local roblox = require("@lune/roblox")
local fs = require("@lune/fs")
local process = require("@lune/process")

-- Lune 은 Roblox 데이터 타입을 roblox 모듈로 노출한다 (전역 아님)
local Vector3 = roblox.Vector3
local CFrame = roblox.CFrame
local Color3 = roblox.Color3
local UDim2 = roblox.UDim2
local Enum = roblox.Enum

local assetDir = process.args[1] or "assets_clean"
local outDir = process.args[2] or "workspace_baked"

-- ============ Config 값 (src/shared/Config.luau 와 동기) ============
local GRID_COLS = 7
local GRID_ROWS = 5
local CELL_SIZE = 6

-- Config.PATH 과 동일 (col, row)
local PATH = {
	{ 1, 3 }, { 2, 3 }, { 2, 1 }, { 4, 1 }, { 4, 4 }, { 6, 4 }, { 6, 2 }, { 7, 2 },
}

-- MapThemes.Midgard_Forest
local THEME = {
	groundColor = { 46, 82, 40 },
	groundMaterial = "Grass",
	pathColor = { 120, 105, 80 },
	pathMaterial = "Ground",
	baseColor = { 80, 180, 255 },
	spawnColor = { 200, 60, 60 },
}

local function color3(rgb: { number }): Color3
	return Color3.fromRGB(rgb[1], rgb[2], rgb[3])
end

local function cellToWorld(col: number, row: number): Vector3
	local x = (col - (GRID_COLS - 1) / 2) * CELL_SIZE
	local z = (row - (GRID_ROWS - 1) / 2) * CELL_SIZE
	return Vector3.new(x, 0, z)
end

-- ============ 준비 ============
if fs.isDir(outDir) then
	fs.removeDir(outDir)
end
fs.writeDir(outDir)

-- 에셋 원본 로드 (최상위 1개로 정규화된 assets_clean 사용)
local sources: { [string]: Instance } = {}
local available = {}
for _, f in fs.readDir(assetDir) do
	if not string.match(f, "%.rbxm$") then
		continue
	end
	local key = (string.match(f, "^(.+)%.rbxm$")) :: string
	local ok, list = pcall(function()
		return roblox.deserializeModel(fs.readFile(assetDir .. "/" .. f))
	end)
	if ok and list then
		local first = nil
		for _, inst in list do
			if not first then
				first = inst
			end
		end
		if first then
			sources[key] = first
			table.insert(available, key)
		end
	end
end
table.sort(available)
print(string.format("에셋 로드: %d개", #available))

-- ============ TowerArena 구축 ============
local arena = roblox.Instance.new("Model")
arena.Name = "TowerArena"

local function addPart(name: string, size: Vector3, pos: Vector3, color: { number }, material: string, collide: boolean): any
	local p = roblox.Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = collide
	p.Size = size
	p.CFrame = CFrame.new(pos)
	p.Material = (Enum.Material :: any)[material] or Enum.Material.SmoothPlastic
	p.Color = color3(color)
	p.TopSurface = Enum.SurfaceType.Smooth
	p.Parent = arena
	return p
end

-- 바닥
local boundsX = GRID_COLS * CELL_SIZE + 24
local boundsZ = GRID_ROWS * CELL_SIZE + 24
addPart("Ground", Vector3.new(boundsX, 2, boundsZ), Vector3.new(0, -1, 0), THEME.groundColor, THEME.groundMaterial, true)

-- 경로
local pts = {}
for _, p in PATH do
	table.insert(pts, cellToWorld(p[1], p[2]))
end
for i = 2, #pts do
	local a, b = pts[i - 1], pts[i]
	local mid = (a + b) / 2
	local len = (b - a).Magnitude
	local cf = CFrame.lookAt(mid, b) * CFrame.Angles(0, math.rad(90), 0)
	local seg = roblox.Instance.new("Part")
	seg.Name = "Path"
	seg.Anchored = true
	seg.CanCollide = false
	seg.Size = Vector3.new(CELL_SIZE * 0.9, 0.4, len)
	seg.CFrame = cf
	seg.Material = (Enum.Material :: any)[THEME.pathMaterial] or Enum.Material.Ground
	seg.Color = color3(THEME.pathColor)
	seg.Parent = arena
end

-- 스폰 표식 / 실제 스폰
addPart("SpawnMark", Vector3.new(4, 0.5, 4), pts[1] + Vector3.new(0, 0.3, 0), THEME.spawnColor, "Neon", false)

local spawn = roblox.Instance.new("SpawnLocation")
spawn.Name = "PlayerSpawn"
spawn.Anchored = true
spawn.CanCollide = true
spawn.Size = Vector3.new(8, 1, 8)
spawn.CFrame = CFrame.new(pts[1] + Vector3.new(0, 0.5, 10))
spawn.Material = Enum.Material.SmoothPlastic
spawn.Color = color3(THEME.spawnColor)
spawn.TopSurface = Enum.SurfaceType.Smooth
spawn.Neutral = true
spawn.Duration = 0
spawn.Parent = arena

-- 기지 표식 + 코어
local last = pts[#pts]
addPart("BaseMark", Vector3.new(6, 1, 6), last + Vector3.new(0, 0.5, 0), THEME.baseColor, "Neon", false)

local core = roblox.Instance.new("Part")
core.Name = "BaseCore"
core.Shape = Enum.PartType.Ball
core.Anchored = true
core.CanCollide = false
core.Size = Vector3.new(5, 5, 5)
core.CFrame = CFrame.new(last + Vector3.new(0, 4, 0))
core.Material = Enum.Material.Neon
core.Color = color3(THEME.baseColor)
core.Parent = arena

-- ============ 장식 배치 ============
local decor = roblox.Instance.new("Folder")
decor.Name = "Decor"
decor.Parent = arena

-- 결정적 배치를 위한 간단한 LCG
local seed = 20261019
local function rnd(): number
	seed = (seed * 1103515245 + 12345) % 2147483648
	return seed / 2147483648
end

local function pathDistance(px: number, pz: number): number
	-- 경로 폴리라인까지 최단 거리 (평면)
	local best = math.huge
	for i = 2, #pts do
		local a, b = pts[i - 1], pts[i]
		local ax, az = a.X, a.Z
		local bx, bz = b.X, b.Z
		local dx, dz = bx - ax, bz - az
		local len2 = dx * dx + dz * dz
		local t = 0
		if len2 > 0 then
			t = math.clamp(((px - ax) * dx + (pz - az) * dz) / len2, 0, 1)
		end
		local cx, cz = ax + dx * t, az + dz * t
		local d = math.sqrt((px - cx) ^ 2 + (pz - cz) ^ 2)
		if d < best then
			best = d
		end
	end
	return best
end

-- 에셋을 목표 크기로 스케일해 배치
local function placeAsset(key: string, pos: Vector3, targetSize: number, name: string): boolean
	local src = sources[key]
	if not src then
		return false
	end
	local clone = src:Clone()
	if not clone then
		return false
	end
	clone.Name = name

	-- Model 이면 ScaleTo, Part 면 Size 조정
	if clone:IsA("Model") then
		local okBox, _, size = pcall(function()
			return (clone :: any):GetBoundingBox()
		end)
		if okBox and size and size.Y > 0 then
			local s = targetSize / math.max(size.X, size.Y, size.Z)
			pcall(function()
				(clone :: any):ScaleTo(s)
			end)
		end
		pcall(function()
			(clone :: any):PivotTo(CFrame.new(pos))
		end)
	elseif clone:IsA("BasePart") then
		local part = clone :: any
		local m = math.max(part.Size.X, part.Size.Y, part.Size.Z)
		if m > 0 then
			part.Size = part.Size * (targetSize / m)
		end
		part.CFrame = CFrame.new(pos)
	end

	for _, d in clone:GetDescendants() do
		if d:IsA("BasePart") then
			(d :: any).Anchored = true
			(d :: any).CanCollide = false
			(d :: any).CanTouch = false
		end
	end
	if clone:IsA("BasePart") then
		(clone :: any).Anchored = true
		(clone :: any).CanCollide = false
	end

	clone.Parent = decor
	return true
end

-- 바위 12개 (경로에서 떨어뜨려)
local rockCount = 0
for _ = 1, 12 do
	local x = (rnd() - 0.5) * boundsX * 0.85
	local z = (rnd() - 0.5) * boundsZ * 0.85
	if pathDistance(x, z) > 7 then
		local size = 1.5 + rnd() * 2.5
		if placeAsset("env_rock", Vector3.new(x, size * 0.35, z), size, "Rock") then
			rockCount += 1
		end
	end
end

-- 나무/수정 14개
local treeCount, crystalCount = 0, 0
for _ = 1, 14 do
	local x = (rnd() - 0.5) * boundsX * 0.88
	local z = (rnd() - 0.5) * boundsZ * 0.88
	if pathDistance(x, z) > 6 then
		local size = 2.0 + rnd() * 2.5
		if rnd() > 0.45 then
			if placeAsset("env_tree", Vector3.new(x, 0, z), size * 1.6, "Tree") then
				treeCount += 1
			end
		else
			if placeAsset("env_crystal", Vector3.new(x, size * 0.4, z), size, "Crystal") then
				crystalCount += 1
			end
		end
	end
end

-- 기둥 2개 (좌우 대칭)
local pillarCount = 0
for _, sx in { -1, 1 } do
	local x = sx * boundsX * 0.36
	local z = 0
	-- 기둥 기둥대
	addPart("PillarBase", Vector3.new(4, 12, 4), Vector3.new(x, 6, z), THEME.groundColor, "Slate", true)
	-- 꼭대기 발광 구
	local orb = roblox.Instance.new("Part")
	orb.Name = "PillarOrb"
	orb.Shape = Enum.PartType.Ball
	orb.Anchored = true
	orb.CanCollide = false
	orb.Size = Vector3.new(3, 3, 3)
	orb.CFrame = CFrame.new(Vector3.new(x, 13.5, z))
	orb.Material = Enum.Material.Neon
	orb.Color = Color3.fromRGB(80, 220, 255)
	orb.Parent = decor
	pillarCount += 1
end

-- 중앙 상징물
placeAsset("env_tower", Vector3.new(0, 0, 0), 10, "CentralSpire")

print(string.format("배치: 바위 %d, 나무 %d, 수정 %d, 기둥 %d", rockCount, treeCount, crystalCount, pillarCount))

-- ============ 저장 ============
local outPath = outDir .. "/TowerArena.rbxm"
fs.writeFile(outPath, roblox.serializeModel({ arena }))
print(string.format("저장: %s (%d bytes)", outPath, #fs.readFile(outPath)))

-- 검증용 요약
local summary = {}
for _, c in arena:GetChildren() do
	local n = c.Name
	summary[n] = (summary[n] or 0) + 1
end
local keys = {}
for k in summary do
	table.insert(keys, k)
end
table.sort(keys)
print("\nTowerArena 직계 자식:")
for _, k in keys do
	print(string.format("  %-14s %d", k, summary[k]))
end
