-- 맵 테마 데이터 검증 (Roblox API 무의존 부분만)
local MapThemes = require("../src/shared/MapThemes")

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

section("테마 9종 정의")
do
	local all = MapThemes.all()
	check("테마 9개", #all == 9, tostring(#all))

	local ids = {}
	for _, t in all do
		ids[t.zoneId] = true
	end
	local n = 0
	for _ in ids do n += 1 end
	check("zoneId 중복 없음", n == 9, tostring(n))
end

section("필수 필드 무결성")
do
	for _, t in MapThemes.all() do
		local function validRGB(c: any): boolean
			return type(c) == "table" and #c == 3
				and c[1] >= 0 and c[1] <= 255
				and c[2] >= 0 and c[2] <= 255
				and c[3] >= 0 and c[3] <= 255
		end
		check(t.zoneId .. " groundColor RGB", validRGB(t.groundColor))
		check(t.zoneId .. " pathColor RGB", validRGB(t.pathColor))
		check(t.zoneId .. " baseColor RGB", validRGB(t.baseColor))
		check(t.zoneId .. " propColor RGB", validRGB(t.propColor))
		check(t.zoneId .. " ambient RGB", validRGB(t.ambient))
		check(t.zoneId .. " fogColor RGB", validRGB(t.fogColor))
		check(t.zoneId .. " groundMaterial 문자열", type(t.groundMaterial) == "string")
		check(t.zoneId .. " fogEnd > 0", t.fogEnd > 0, tostring(t.fogEnd))
		check(t.zoneId .. " decor 정의", type(t.decor) == "table")
		check(t.zoneId .. " rocks >= 0", t.decor.rocks >= 0)
		check(t.zoneId .. " pillars >= 0", t.decor.pillars >= 0)
		check(t.zoneId .. " props >= 0", t.decor.props >= 0)
	end
end

section("지역별 차별화")
do
	-- 바닥색이 지역마다 달라야 함
	local colors = {}
	for _, t in MapThemes.all() do
		local key = tostring(t.groundColor)
		colors[key] = (colors[key] or 0) + 1
	end
	local distinct = 0
	for _ in colors do distinct += 1 end
	check("바닥색 9종 모두 다름", distinct == 9, tostring(distinct))

	-- 안개 거리도 다양해야 함
	local fogs = {}
	for _, t in MapThemes.all() do
		fogs[t.fogEnd] = true
	end
	local fogN = 0
	for _ in fogs do fogN += 1 end
	check("fogEnd 다양함 (>=5종)", fogN >= 5, tostring(fogN))
end

section("테마 조회 및 폴백")
do
	local forest = MapThemes.get("Midgard_Forest")
	check("존재하는 zoneId 조회", forest ~= nil and forest.zoneId == "Midgard_Forest")

	-- 존재하지 않는 id → 기본 테마 폴백 (크래시 방지)
	local fallback = MapThemes.get("NoSuchZone")
	check("미존재 zoneId 폴백", fallback ~= nil and fallback.zoneId == "Midgard_Forest")
	local nilFallback = MapThemes.get(nil :: any)
	check("nil zoneId 폴백", nilFallback ~= nil)
end

section("Lore 지역과 1:1 대응")
do
	local Lore = require("../src/shared/Lore")
	local themeIds = {}
	for _, t in MapThemes.all() do
		themeIds[t.zoneId] = true
	end

	local missing = 0
	for _, z in Lore.ZONES do
		if not themeIds[z.id] then
			missing += 1
			print("  누락된 테마: " .. z.id)
		end
	end
	check("모든 Lore 지역에 테마 존재", missing == 0, tostring(missing) .. "개 누락")
end

section("장식 밀도 범위")
do
	for _, t in MapThemes.all() do
		local total = t.decor.rocks + t.decor.pillars + t.decor.props
		check(t.zoneId .. " 장식 총량 적정(10~50)", total >= 10 and total <= 50, tostring(total))
	end
end

section("최종 지역이 가장 어두움")
do
	local abyss = MapThemes.get("Abyss")
	local forest = MapThemes.get("Midgard_Forest")
	check("Abyss 안개 거리 < Forest", abyss.fogEnd < forest.fogEnd,
		string.format("%.0f vs %.0f", abyss.fogEnd, forest.fogEnd))
end

print(string.format("\n===== RESULT: %d passed, %d failed =====", pass, fail))
if fail > 0 then
	print("FAILED: " .. table.concat(failures, ", "))
	error("map tests failed")
end
