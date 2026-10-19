-- 에셋이 런타임에 실제로 처리 가능한지 검증
-- 문제: 다운로드한 에셋 중 Model 이 아닌 것(Part/Accessory/Folder/UnionOperation)이 있고,
--       코드가 Model 전제로 걸러내면 에셋이 조용히 버려지고 파트 폴백만 보인다.
--
-- .rbxlx 를 직접 파싱하는 대신, 원본 assets_clean/*.rbxm 을 Lune 으로 역직렬화해
-- 최상위 클래스를 확인한다. 빌드 결과와 무관하게 에셋 자체를 검사하므로 더 정확하다.
local roblox = require("@lune/roblox")
local fs = require("@lune/fs")
local process = require("@lune/process")

local dir = process.args[1] or "assets_clean"

-- AssetLoader.fit / place / anchor 가 처리 가능한 클래스
local PV_CLASSES = {
	Model = true,
	Part = true,
	MeshPart = true,
	UnionOperation = true,
	NegateOperation = true,
	CornerWedgePart = true,
	WedgePart = true,
	TrussPart = true,
	Seat = true,
	VehicleSeat = true,
	SpawnLocation = true,
}

-- PVInstance 는 아니지만 anchor() 로 하위 파트를 고정할 수 있는 컨테이너
local CONTAINER_CLASSES = {
	Folder = true,
	Accessory = true,
	Tool = true,
	Hat = true,
}

local files = fs.readDir(dir)
table.sort(files)

local pass, fail = 0, 0
local failures = {}

print(string.format("%-24s %-18s %-12s", "asset", "top class", "처리"))
print(string.rep("-", 58))

for _, f in files do
	if not string.match(f, "%.rbxm$") then
		continue
	end
	local key = (string.match(f, "^(.+)%.rbxm$")) :: string
	local ok, data = pcall(fs.readFile, dir .. "/" .. f)
	if not ok then
		print(string.format("%-24s %-18s %-12s", key, "?", "읽기실패"))
		fail += 1
		table.insert(failures, key .. " (읽기 실패)")
		continue
	end

	local okDe, list = pcall(function()
		return roblox.deserializeModel(data)
	end)
	if not okDe or not list then
		print(string.format("%-24s %-18s %-12s", key, "?", "파싱실패"))
		fail += 1
		table.insert(failures, key .. " (파싱 실패)")
		continue
	end

	-- 최상위 개수와 첫 인스턴스 클래스
	local count, top = 0, nil
	for _, inst in list do
		count += 1
		if not top then
			top = inst
		end
	end

	local cls = top and top.ClassName or "?"
	local kind
	if count > 1 then
		kind = "다중 최상위"
		fail += 1
		table.insert(failures, string.format("%s (%d개 최상위 — Rojo 가 단일만 허용)", key, count))
	elseif PV_CLASSES[cls] then
		kind = "PV OK"
		pass += 1
	elseif CONTAINER_CLASSES[cls] then
		kind = "컨테이너 OK"
		pass += 1
	else
		kind = "미지원"
		fail += 1
		table.insert(failures, string.format("%s [%s]", key, cls))
	end

	print(string.format("%-24s %-18s %-12s", key, cls, kind))
end

print(string.format("\n===== 에셋 클래스 검증: %d OK, %d 문제 =====", pass, fail))
if fail > 0 then
	print("\n문제 목록:")
	for _, x in failures do
		print("  " .. x)
	end
	error("asset class check failed")
end
