--!strict
-- 마켓플레이스 에셋 로더 — 절차적 생성 대신 Roblox 무료 모델을 사용한다.
--
-- 공식 문서 근거 (API-Dump version-d0e8cfcd943d4ae2 로 시그니처 확인):
--   InsertService:LoadAsset(assetId: int64) -> Instance
--   Model:GetBoundingBox() -> Tuple            (CFrame, Vector3)
--   Model:ScaleTo(newScaleFactor: float) -> null
--   Model:GetScale() -> float
--   Model:PivotTo()  — Model에는 없음. WorldPivot/PrimaryPart 사용 또는 :PivotTo()는 PVInstance
--
-- LoadAsset은 서버 Script 전용이며 실패할 수 있으므로 반드시 pcall로 감싼다.
-- 에셋이 로드되지 않으면 절차적 폴백을 쓴다 (게임이 멈추지 않게).

local InsertService = game:GetService("InsertService")

local AssetLoader = {}

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local AssetCatalog = require(Shared:WaitForChild("AssetCatalog"))

-- 카탈로그: AssetCatalog.luau (검증된 무료 모델만)
AssetLoader.CATALOG = AssetCatalog.CATALOG

local cache: { [number]: Instance } = {}
local failed: { [number]: boolean } = {}

-- 에셋 1회 로드 후 캐시. 실패 시 nil.
function AssetLoader.load(assetId: number): Instance?
	if cache[assetId] then
		return cache[assetId]
	end
	if failed[assetId] then
		return nil
	end

	local ok, result = pcall(InsertService.LoadAsset, InsertService, assetId)
	if not ok or not result then
		warn(string.format("[AssetLoader] 로드 실패 id=%d: %s", assetId, tostring(result)))
		failed[assetId] = true
		return nil
	end

	cache[assetId] = result
	return result
end

function AssetLoader.loadKey(key: string): Instance?
	local entry = AssetLoader.CATALOG[key]
	if not entry then
		return nil
	end
	return AssetLoader.load(entry.id)
end

-- 복제본을 반환. 원본은 캐시에 보존하고 파괴하지 않는다.
function AssetLoader.template(key: string): Instance?
	local base = AssetLoader.loadKey(key)
	if not base then
		return nil
	end
	return base:Clone()
end

-- 모델을 목표 크기에 맞춰 스케일 조정. 성공 시 true.
-- GetBoundingBox는 Tuple(CFrame, Vector3) 반환.
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

	local okScale = pcall(model.ScaleTo, model, scale)
	return okScale
end

-- 모델을 특정 셀 위치에 정렬 (바닥 기준)
function AssetLoader.place(model: Instance, at: Vector3): boolean
	if not model:IsA("Model") then
		return false
	end
	local okBox, bbox, size = pcall(model.GetBoundingBox, model)
	if not okBox or typeof(bbox) ~= "CFrame" then
		return false
	end
	-- 바운딩박스 중심의 Y를 바닥(size.Y/2)에 맞춘다
	local offset = Vector3.new(0, size.Y / 2, 0)
	local okPivot = pcall(function()
		model:PivotTo(CFrame.new(at + offset))
	end)
	return okPivot
end

function AssetLoader.stats(): (number, number)
	local okn, failn = 0, 0
	for _ in cache do
		okn += 1
	end
	for _ in failed do
		failn += 1
	end
	return okn, failn
end

-- Studio 진단용: 카탈로그 전체를 실제로 로드해 성공/실패를 출력한다.
-- 이 환경에서는 Studio가 없어 실행 불가 — Studio에서 호출해 확인할 것.
function AssetLoader.diagnose()
	print("[AssetLoader] 진단 시작")
	local okn, failn = 0, 0
	for key, entry in AssetLoader.CATALOG do
		local ok, result = pcall(InsertService.LoadAsset, InsertService, entry.id)
		if ok and result then
			local okBox, _, size = pcall(result.GetBoundingBox, result)
			local desc = okBox and string.format("%.1f x %.1f x %.1f", size.X, size.Y, size.Z) or "bbox?"
			print(string.format("  OK    %-18s id=%-14d %s", key, entry.id, desc))
			result:Destroy()
			okn += 1
		else
			print(string.format("  FAIL  %-18s id=%-14d %s", key, entry.id, tostring(result)))
			failn += 1
		end
		task.wait(0.25)
	end
	print(string.format("[AssetLoader] 진단 완료 — %d OK, %d FAIL", okn, failn))
end

return AssetLoader
