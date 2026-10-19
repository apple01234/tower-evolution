-- 성장 시스템 (환생/연구/도감/지역) 검증
local Progress = require("../src/shared/Progress")
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

-- ============ 초기 상태 ============
section("초기 상태")
do
	local st = Progress.new(300)
	check("골드 초기화", st.gold == 300)
	check("환생 0회", st.rebirths == 0)
	check("연구 포인트 0", Progress.researchPoints(st) == 0)
	check("도감 0개", Progress.collectedCount(st) == 0)
	check("배율 기본 1.0", Progress.goldMultiplier(st) == 1.0)
	check("데미지 배율 기본 1.0", Progress.damageMultiplier(st) == 1.0)
	check("소환 비용 배율 기본 1.0", Progress.summonCostMultiplier(st) == 1.0)
end

-- ============ 환생 조건 ============
section("환생 조건")
do
	local st = Progress.new(300)
	-- 조건 미달
	local ok, err = Progress.canRebirth(st, false)
	check("웨이브 부족 거부", ok == false and err == "NEED_WAVE")

	-- 웨이브 충족, 골드 부족
	Progress.recordWave(st, 25)
	ok, err = Progress.canRebirth(st, true)
	check("골드 부족 거부", ok == false and err == "NEED_GOLD")

	-- 골드 충족, 보스 미처치
	st.gold = 10000
	ok, err = Progress.canRebirth(st, false)
	check("보스 미처치 거부", ok == false and err == "NEED_BOSS")

	-- 전부 충족
	ok, err = Progress.canRebirth(st, true)
	check("모든 조건 충족 시 허용", ok == true, tostring(err))
end

section("환생 요구치 상승")
do
	local r0 = Progress.requirement(0)
	local r1 = Progress.requirement(1)
	local r5 = Progress.requirement(5)
	check("환생할수록 웨이브 요구 증가", r1.minWave > r0.minWave and r5.minWave > r1.minWave)
	check("환생할수록 골드 요구 증가", r1.minGold > r0.minGold and r5.minGold > r1.minGold)
	check("1회차 요구: 웨이브 20", r0.minWave == 20)
	check("1회차 요구: 골드 5000", r0.minGold == 5000)
end

-- ============ 환생 실행 ============
section("환생 실행 및 초기화/유지")
do
	local st = Progress.new(300)
	Progress.recordWave(st, 30)
	st.gold = 20000
	Progress.unlockCollect(st, "CrystalTurret")
	st.rebirths = 0
	-- 연구 포인트 확보를 위해 강제 (검증용)
	local ok = Progress.applyRebirth(st, 300)

	check("환생 실행", ok == true)
	check("환생 횟수 증가", st.rebirths == 1)
	check("골드 초기화", st.gold == 300)
	check("웨이브 초기화", st.wave == 0)
	check("최고 웨이브 유지", st.maxWaveEver == 30)
	check("도감 유지", Progress.hasCollected(st, "CrystalTurret") == true)
end

-- ============ 연구 ============
section("연구 포인트 및 구매")
do
	local st = Progress.new(300)
	st.rebirths = 1
	check("환생 1회 = 1포인트", Progress.researchPoints(st) == 1)

	st.rebirths = 6
	-- 6 + max(0, 6-5) = 6 + 1 = 7
	check("환생 6회 = 7포인트", Progress.researchPoints(st) == 7, tostring(Progress.researchPoints(st)))
end

do
	local st = Progress.new(300)
	st.rebirths = 20 -- 충분한 포인트
	local before = Progress.researchPoints(st)
	local ok, err = Progress.buyResearch(st, "goldGain")
	check("연구 구매 성공", ok == true, tostring(err))
	check("레벨 증가", Progress.researchLevel(st, "goldGain") == 1)
	check("포인트 차감", Progress.researchPoints(st) < before, string.format("%d -> %d", before, Progress.researchPoints(st)))
	check("골드 배율 상승", Progress.goldMultiplier(st) > 1.0)
end

do
	local st = Progress.new(300)
	st.rebirths = 0
	local ok, err = Progress.buyResearch(st, "goldGain")
	check("포인트 없으면 구매 거부", ok == false and err == "NOT_ENOUGH_POINTS")
	check("거부 시 레벨 불변", Progress.researchLevel(st, "goldGain") == 0)
end

do
	local st = Progress.new(300)
	st.rebirths = 1000
	local ok = true
	for _ = 1, 20 do
		local r = Progress.buyResearch(st, "goldGain")
		if not r then
			ok = false
			break
		end
	end
	check("최대 레벨 초과 구매 차단", Progress.researchLevel(st, "goldGain") == Progress.RESEARCH.goldGain.maxLevel)
	local final, err = Progress.buyResearch(st, "goldGain")
	check("최대 레벨에서 MAX_LEVEL", final == false and err == "MAX_LEVEL")
end

section("연구 배율 상한")
do
	local st = Progress.new(0)
	st.research.summonCost = Progress.RESEARCH.summonCost.maxLevel
	local m = Progress.summonCostMultiplier(st)
	check("소환 비용 배율 하한 0.4 이상", m >= 0.4, tostring(m))
	check("소환 비용 배율 1 미만", m < 1.0, tostring(m))
end

-- ============ 도감 ============
section("도감")
do
	local st = Progress.new(0)
	local keys = {}
	for _, d in TowerData.all() do
		table.insert(keys, d.key)
	end
	check("타워 4종 존재", #keys == 4)

	check("첫 해금 true", Progress.unlockCollect(st, keys[1]) == true)
	check("중복 해금 false", Progress.unlockCollect(st, keys[1]) == false)
	check("카운트 1", Progress.collectedCount(st) == 1)

	-- 전부 해금
	for _, k in keys do
		Progress.unlockCollect(st, k)
	end
	check("전체 해금 4개", Progress.collectedCount(st) == #keys)
	check("존재하지 않는 키도 기록됨(방어)", Progress.unlockCollect(st, "Bogus") == true)
end

-- ============ 지역 해금 ============
section("지역 해금")
do
	local st = Progress.new(0)
	local first = Lore.ZONES[1]
	check("unlockWave 0 지역은 즉시 해금", Progress.isZoneUnlocked(st, first.id, first.unlockWave) == true)

	local second = Lore.ZONES[2]
	check("미달 지역 잠김", Progress.isZoneUnlocked(st, second.id, second.unlockWave) == false)

	Progress.recordWave(st, second.unlockWave)
	check("웨이브 달성 시 해금", Progress.isZoneUnlocked(st, second.id, second.unlockWave) == true)
end

section("지역 해금 순서 무결성")
do
	local st = Progress.new(0)
	local prev = -1
	local mono = true
	for _, z in Lore.ZONES do
		if z.unlockWave < prev then
			mono = false
		end
		prev = z.unlockWave
	end
	check("Lore 지역 unlockWave 단조 증가", mono)
end

-- ============ 환생 후 재진행 ============
section("환생 사이클 통합")
do
	local st = Progress.new(300)
	-- 1회차: 웨이브 25, 골드 12000, 보스 처치
	Progress.recordWave(st, 25)
	st.gold = 12000
	Progress.unlockCollect(st, "ApprenticeTurret")

	local ok1 = Progress.canRebirth(st, true)
	check("1회차 환생 가능", ok1)
	Progress.applyRebirth(st, 300)

	check("환생 후 연구 포인트 1", Progress.researchPoints(st) == 1)
	check("환생 후 도감 유지", Progress.collectedCount(st) == 1)
	check("환생 후 최고웨이브 유지", st.maxWaveEver == 25)

	-- 연구 구매
	local bought = Progress.buyResearch(st, "goldGain")
	check("환생 후 연구 구매 가능", bought)
	check("환생 후 골드 배율 적용", Progress.goldMultiplier(st) > 1.0)

	-- 2회차는 요구치가 높아짐
	local req = Progress.requirement(1)
	check("2회차 요구 웨이브 상승", req.minWave == 30, tostring(req.minWave))
	local ok2, err2 = Progress.canRebirth(st, true)
	check("2회차 조건 미달 거부", ok2 == false, tostring(err2))
end

-- ============ 직렬화 ============
section("저장 요약")
do
	local st = Progress.new(300)
	Progress.recordWave(st, 42)
	Progress.unlockCollect(st, "CrystalTurret")
	local s = Progress.summary(st)
	check("summary 문자열 생성", #s > 0)
	check("summary에 웨이브 포함", string.find(s, "42") ~= nil, s)
end

print(string.format("\n===== RESULT: %d passed, %d failed =====", pass, fail))
if fail > 0 then
	print("FAILED: " .. table.concat(failures, ", "))
	error("progress tests failed")
end
