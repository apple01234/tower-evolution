--!strict
-- 맵 장식 생성: 바위, 기둥, 소품. 테마별 밀도와 색을 따른다.
-- 순수 배치 계산(random 포함)이지만 Instance 생성은 Roblox 전용.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MapThemes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("MapThemes"))

local AssetLoader = require(script.Parent:WaitForChild("AssetLoader"))

local MapDecor = {}

-- 시드 고정 난수 (같은 맵이 항상 같은 모양이 되도록)
local function seededRandom(seed: number): () -> number
	local state = seed % 2147483647
	if state <= 0 then
		state += 2147483646
	end
	return function()
		state = (state * 16807) % 2147483647
		return (state - 1) / 2147483646
	end
end

-- 경로와 겹치지 않는 위치인지 검사
local function isClearOfPath(x: number, z: number, pathPoints: { Vector3 }, margin: number): boolean
	for i = 2, #pathPoints do
		local a = pathPoints[i - 1]
		local b = pathPoints[i]
		-- 선분 ab 에서 점 (x,z) 까지 거리
		local abx, abz = b.X - a.X, b.Z - a.Z
		local apx, apz = x - a.X, z - a.Z
		local len2 = abx * abx + abz * abz
		local t = 0
		if len2 > 0 then
			t = math.clamp((apx * abx + apz * abz) / len2, 0, 1)
		end
		local dx = apx - abx * t
		local dz = apz - abz * t
		if (dx * dx + dz * dz) < margin * margin then
			return false
		end
	end
	return true
end

-- 바위 생성
function MapDecor.rocks(parent: Instance, theme: any, bounds: { x: number, z: number }, pathPoints: { Vector3 }, seed: number)
	local rnd = seededRandom(seed)
	for _ = 1, theme.decor.rocks do
		local x = (rnd() - 0.5) * bounds.x
		local z = (rnd() - 0.5) * bounds.z
		if not isClearOfPath(x, z, pathPoints, 7) then
			continue
		end

		local size = 1.5 + rnd() * 2.5

		-- 마켓플레이스 바위 에셋 우선, 실패 시 파트
		local asset = AssetLoader.template("env_rock")
		if asset and asset:IsA("Model") then
			AssetLoader.fit(asset, Vector3.new(size, size, size))
			for _, d in asset:GetDescendants() do
				if d:IsA("BasePart") then
					d.Anchored = true
					d.CanCollide = false
					d.CanTouch = false
				end
			end
			asset:PivotTo(CFrame.new(x, size * 0.35, z) * CFrame.Angles(0, rnd() * math.pi * 2, 0))
			asset.Parent = parent
			continue
		end

		local rock = Instance.new("Part")
		rock.Name = "Rock"
		rock.Anchored = true
		rock.CanCollide = false
		rock.Size = Vector3.new(size, size * (0.6 + rnd() * 0.6), size)
		rock.CFrame = CFrame.new(x, size * 0.35, z)
			* CFrame.Angles(rnd() * 0.6, rnd() * math.pi * 2, rnd() * 0.6)
		rock.Material = Enum.Material.Rock
		rock.Color = MapThemes.toColor3(theme.propColor)
		rock.Parent = parent
	end
end

-- 기둥 생성 (지역 상징물)
function MapDecor.pillars(parent: Instance, theme: any, bounds: { x: number, z: number }, pathPoints: { Vector3 }, seed: number)
	local rnd = seededRandom(seed + 7919)
	for i = 1, theme.decor.pillars do
		local angle = (i / theme.decor.pillars) * math.pi * 2
		local radius = math.min(bounds.x, bounds.z) * 0.42
		local x = math.cos(angle) * radius
		local z = math.sin(angle) * radius
		if not isClearOfPath(x, z, pathPoints, 6) then
			continue
		end

		local height = 8 + rnd() * 10
		local pillar = Instance.new("Part")
		pillar.Name = "Pillar"
		pillar.Anchored = true
		pillar.CanCollide = false
		pillar.Size = Vector3.new(2, height, 2)
		pillar.CFrame = CFrame.new(x, height / 2, z)
		pillar.Material = MapThemes.toMaterial(theme.groundMaterial)
		pillar.Color = MapThemes.toColor3(theme.propColor)
		pillar.Parent = parent

		-- 기둥 상단 발광
		local cap = Instance.new("Part")
		cap.Name = "PillarCap"
		cap.Shape = Enum.PartType.Ball
		cap.Anchored = true
		cap.CanCollide = false
		cap.Size = Vector3.new(2.6, 2.6, 2.6)
		cap.CFrame = CFrame.new(x, height + 1, z)
		cap.Material = Enum.Material.Neon
		cap.Color = MapThemes.toColor3(theme.baseColor)
		cap.Parent = parent
	end
end

-- 작은 소품 (덤불/수정)
function MapDecor.props(parent: Instance, theme: any, bounds: { x: number, z: number }, pathPoints: { Vector3 }, seed: number)
	local rnd = seededRandom(seed + 104729)
	for _ = 1, theme.decor.props do
		local x = (rnd() - 0.5) * bounds.x
		local z = (rnd() - 0.5) * bounds.z
		if not isClearOfPath(x, z, pathPoints, 6) then
			continue
		end

		local size = 2.0 + rnd() * 2.5

		-- 지역에 따라 나무/수정 에셋 선택
		local assetKey = (rnd() > 0.45) and "env_tree" or "env_crystal"
		local asset = AssetLoader.template(assetKey)
		if asset and asset:IsA("Model") then
			AssetLoader.fit(asset, Vector3.new(size, size * 1.6, size))
			for _, d in asset:GetDescendants() do
				if d:IsA("BasePart") then
					d.Anchored = true
					d.CanCollide = false
					d.CanTouch = false
				end
			end
			asset:PivotTo(CFrame.new(x, 0, z) * CFrame.Angles(0, rnd() * math.pi * 2, 0))
			asset.Parent = parent
			continue
		end

		local prop = Instance.new("Part")
		prop.Name = "Prop"
		prop.Anchored = true
		prop.CanCollide = false
		prop.Size = Vector3.new(size, size, size)
		prop.CFrame = CFrame.new(x, size / 2, z)
			* CFrame.Angles(0, rnd() * math.pi * 2, 0)
		prop.Material = Enum.Material.Slate
		prop.Color = MapThemes.toColor3(theme.propColor)
		prop.Parent = parent
	end
end

-- 전체 장식 배치
function MapDecor.build(parent: Instance, theme: any, bounds: { x: number, z: number }, pathPoints: { Vector3 }, seed: number)
	local decor = Instance.new("Folder")
	decor.Name = "Decor"
	decor.Parent = parent

	MapDecor.rocks(decor, theme, bounds, pathPoints, seed)
	MapDecor.pillars(decor, theme, bounds, pathPoints, seed)
	MapDecor.props(decor, theme, bounds, pathPoints, seed)
	return decor
end

return MapDecor
