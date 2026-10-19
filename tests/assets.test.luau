-- 에셋 카탈로그 무결성 검증
local AssetCatalog = require("../src/shared/AssetCatalog")
local TowerData = require("../src/shared/TowerData")
local Lore = require("../src/shared/Lore")

local pass, fail = 0, 0
local failures = {}
local function check(name: string, cond: boolean, detail: string?)
	if cond then
		pass += 1
	else
		fail += 1
		table.insert(failures, name)
		print(string.format("  FAIL  %s  %s", name, detail or ""))
	end
end
local function section(s: string) print("\n[" .. s .. "]") end

section("카탈로그 기본 무결성")
do
	local keys = AssetCatalog.allKeys()
	check("카탈로그 비어있지 않음", #keys > 0, tostring(#keys))

	local ids = {}
	local dupes = 0
	for _, k in keys do
		local e = AssetCatalog.get(k)
		check(k .. " id 존재", type(e.id) == "number" and e.id > 0)
		check(k .. " label 존재", type(e.label) == "string" and #e.label > 0)
		if ids[e.id] then
			dupes += 1
			print("  중복 ID: " .. k .. " == " .. ids[e.id])
		end
		ids[e.id] = k
	end
	check("중복 ID 없음", dupes == 0, tostring(dupes) .. "개 중복")
end

section("모든 타워에 에셋 매핑")
do
	local towers = TowerData.all()
	local missing = {}
	for _, d in towers do
		if not AssetCatalog.has(d.key) then
			table.insert(missing, d.key)
		end
	end
	check("타워 15종 전부 에셋 보유", #missing == 0,
		#missing > 0 and ("누락: " .. table.concat(missing, ", ")) or "")

	-- 역방향: 카탈로그의 타워 키가 실제 존재하는 타워인지
	local TOWER_KEYS = AssetCatalog.TOWER_KEYS
	for _, k in AssetCatalog.allKeys() do
		if TOWER_KEYS[k] then
			check(k .. " 은 실제 타워", TowerData.exists(k))
		end
	end
end

section("계열별 에셋 커버리지")
do
	for _, fam in TowerData.FAMILY_KEYS do
		local nodes = TowerData.familyChain(fam)
		local covered = 0
		for _, d in nodes do
			if AssetCatalog.has(d.key) then
				covered += 1
			end
		end
		check(fam .. " 전 노드 에셋 보유", covered == #nodes,
			string.format("%d/%d", covered, #nodes))
	end
end

section("적 / 보스 / 환경 에셋")
do
	check("일반 적 에셋", AssetCatalog.has("enemy"))
	check("보스급 적 에셋", AssetCatalog.has("enemy_alt"))
	check("환경 나무", AssetCatalog.has("env_tree"))
	check("환경 바위", AssetCatalog.has("env_rock"))
	check("보스 드래곤", AssetCatalog.has("boss_dragon"))
end

section("로어 지역 테마 커버리지")
do
	-- 9지역 중 최소한 나무/바위/수정은 공용으로 쓸 수 있어야 함
	local zones = #Lore.ZONES
	check("지역 9개", zones == 9, tostring(zones))
	check("공용 환경 에셋 존재", AssetCatalog.has("env_tree") and AssetCatalog.has("env_rock"))
end

section("에셋 키 명명 규칙")
do
	for _, k in AssetCatalog.allKeys() do
		-- PascalCase(타워) / snake_case(적·환경) / 단일 소문자 단어
		local isPascal = string.match(k, "^%u%w+$") ~= nil
		local isSnake = string.match(k, "^%l[%w_]*$") ~= nil and string.find(k, "_") ~= nil
		local isSingle = string.match(k, "^%l[%w]*$") ~= nil
		check(k .. " 명명 규칙", isPascal or isSnake or isSingle, k)
	end
end

section("검증 메타데이터")
do
	-- AssetCatalog 는 "검증된 것만" 등록한다는 규칙이 있으므로
	-- 각 항목에 검증 표시가 있는지 확인할 수는 없지만, 최소한 개수는 기록
	local keys = AssetCatalog.allKeys()
	print(string.format("  카탈로그 항목: %d개", #keys))
	check("카탈로그 20개 이상", #keys >= 20, tostring(#keys))
end

print(string.format("\n===== RESULT: %d passed, %d failed =====", pass, fail))
if fail > 0 then
	print("FAILED: " .. table.concat(failures, ", "))
	error("asset catalog tests failed")
end
