--!strict
-- 에셋 로더 (3단계 우선순위)
--   1) ReplicatedStorage.AssetBundles 에 Rojo 로 구워진 모델 (즉시, 인증 불필요)
--   2) InsertService:LoadAsset (런타임, 서버 전용, 실패 가능)
--   3) 호출측의 절차적 파트 폴백
--
-- 공식 문서 근거 (API-Dump version-d0e8cfcd943d4ae2):
--   InsertService:LoadAsset(assetId: int64) -> Instance   [capability LoadOwnedAsset, yields]
--   Model:GetBoundingBox() -> Tuple (CFrame, Vector3)
--   Model:ScaleTo(float) -> null ; Model:PivotTo() 는 PVInstance 상속

local InsertService = game:GetService("InsertService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AssetLoader = {}

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AssetCatalog = require(Shared:WaitForChild("AssetCatalog"))

AssetLoader.CATALOG = AssetCatalog.CATALOG

local runtimeCache: { [number]: Instance } = {}
local runtimeFailed: { [number]: boolean } = {}

-- 구워진 번들 폴더 (없으면 nil)
local function bundles(): Folder?
	local f = ReplicatedStorage:FindFirstChild("AssetBundles")
	return if f and f:IsA("Folder") then f else nil
end

-- 1단계: 구워진 에셋 조회
local function baked(key: string): Instance?
	local folder = bundles()
	if not folder then
		return nil
	end

	-- 자식 이름이 key 와 정확히 일치
	local direct = folder:FindFirstChild(key)
	if direct then
		return direct
	end

	-- Rojo 가 확장자를 이름에 남긴 경우 (key.rbxm 등) 대비
	for _, child in folder:GetChildren() do
		local base = string.match(child.Name, "^(.+)%.rbxm[x]?$")
		if base == key then
			return child
		end
	end
	return nil
end

-- 2단계: 런타임 로드 (캐시)
function AssetLoader.load(assetId: number): Instance?
	if runtimeCache[assetId] then
		return runtimeCache[assetId]
	end
	if runtimeFailed[assetId] then
		return nil
	end

	local ok, result = pcall(InsertService.LoadAsset, InsertService, assetId)
	if not ok or not result then
		warn(string.format("[AssetLoader] 런타임 로드 실패 id=%d: %s", assetId, tostring(result)))
		runtimeFailed[assetId] = true
		return nil
	end

	runtimeCache[assetId] = result
	return result
end

-- key 로 원본 인스턴스 획득 (구워진 것 우선)
function AssetLoader.loadKey(key: string): Instance?
	local b = baked(key)
	if b then
		return b
	end
	local entry = AssetCatalog.get(key)
	if entry then
		return AssetLoader.load(entry.id)
	end
	return nil
end

-- 복제본 반환. 원본은 절대 파괴하지 않는다.
function AssetLoader.template(key: string): Instance?
	local base = AssetLoader.loadKey(key)
	if not base then
		return nil
	end
	return base:Clone()
end

-- 모델을 목표 크기에 맞춰 스케일. GetBoundingBox 는 Tuple 반환.
function AssetLoader.fit(model: Instance, targetSize: Vector3): boolean
	if not model:IsA("Model") then
		return false
	end
	local okBox, _, size = pcall(model.GetBoundingBox, model)
	if not okBox or typeof(size) ~= "Vector3" then
		return false
	end
	if size.X <= 0 or size.Y <= 0 or size.Z <= 0 then
		return false
	end
	local scale = math.min(targetSize.X / size.X, targetSize.Y / size.Y, targetSize.Z / size.Z)
	if scale <= 0 or scale == math.huge or scale ~= scale then
		return false
	end
	return pcall(model.ScaleTo, model, scale)
end

-- 바닥 기준으로 배치
function AssetLoader.place(model: Instance, at: Vector3): boolean
	if not model:IsA("Model") then
		return false
	end
	local okBox, bbox, size = pcall(model.GetBoundingBox, model)
	if not okBox or typeof(bbox) ~= "CFrame" or typeof(size) ~= "Vector3" then
		return false
	end
	local offset = Vector3.new(0, size.Y / 2, 0)
	return pcall(function()
		model:PivotTo(CFrame.new(at + offset))
	end)
end

-- 구워진 에셋 개수 (Studio 즉시 확인용)
function AssetLoader.bakedCount(): number
	local folder = bundles()
	if not folder then
		return 0
	end
	local n = 0
	for _ in folder:GetChildren() do
		n += 1
	end
	return n
end

function AssetLoader.stats(): (number, number)
	local okn, failn = 0, 0
	for _ in runtimeCache do
		okn += 1
	end
	for _ in runtimeFailed do
		failn += 1
	end
	return okn, failn
end

-- 진단: 구워진 것과 런타임 로드를 모두 확인
function AssetLoader.diagnose()
	print(string.format("[AssetLoader] 구워진 에셋: %d개", AssetLoader.bakedCount()))

	local bakedOk, bakedFail, runtimeOk, runtimeFail = 0, 0, 0, 0
	for key, _ in AssetCatalog.CATALOG do
		local b = baked(key)
		if b then
			local okBox, _, size = pcall((b :: any).GetBoundingBox, b)
			local desc = okBox and string.format("%.1f x %.1f x %.1f", size.X, size.Y, size.Z) or "bbox?"
			print(string.format("  BAKED %-20s %s", key, desc))
			bakedOk += 1
		else
			bakedFail += 1
			local entry = AssetCatalog.get(key)
			local ok, result = pcall(InsertService.LoadAsset, InsertService, entry.id)
			if ok and result then
				runtimeOk += 1
				print(string.format("  RUNTIME %-18s id=%d (구워지지 않음)", key, entry.id))
				result:Destroy()
			else
				runtimeFail += 1
				print(string.format("  FAIL  %-20s id=%d %s", key, entry.id, tostring(result)))
			end
			task.wait(0.2)
		end
	end
	print(string.format("[AssetLoader] 구워짐 %d / 런타임 %d / 실패 %d", bakedOk, runtimeOk, runtimeFail))
	_ = bakedFail
end

return AssetLoader
