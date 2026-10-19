-- 이그드라실 세계관 데이터 검증
local Lore = require("../src/shared/Lore")
local TowerData = require("../src/shared/TowerData")

local pass, fail = 0, 0
local function check(name: string, cond: boolean, detail: string?)
	if cond then
		pass += 1
		print("  PASS  " .. name)
	else
		fail += 1
		print("  FAIL  " .. name .. "  " .. (detail or ""))
	end
end

print("\n[Lore: 9왕국]")
check("9개 지역 정의", #Lore.ZONES == 9, "got " .. #Lore.ZONES)

local nums, ids = {}, {}
for _, z in Lore.ZONES do
	nums[z.num] = true
	ids[z.id] = true
end
local nNum, nId = 0, 0
for _ in nums do nNum += 1 end
for _ in ids do nId += 1 end
check("지역 num 중복 없음", nNum == 9, "unique=" .. nNum)
check("지역 id 중복 없음", nId == 9, "unique=" .. nId)

-- 원본 챕터 번호 보존 확인 (2~10)
local expectNums = { 2, 3, 4, 5, 6, 7, 8, 9, 10 }
for _, n in expectNums do
	check("원본 챕터 num " .. n .. " 보존", nums[n] == true)
end

print("\n[Lore: 보스 9종]")
local bossCount = 0
for _ in Lore.BOSSES do bossCount += 1 end
check("보스 9종 정의", bossCount == 9, "got " .. bossCount)
check("BOSS_ORDER 9개", #Lore.BOSS_ORDER == 9)

for _, key in Lore.BOSS_ORDER do
	local b = Lore.getBoss(key)
	check("보스 존재: " .. key, b ~= nil)
	if b then
		check("  " .. key .. " hp>0", b.hp > 0)
		check("  " .. key .. " 이름 비어있지 않음", #b.name > 0)
		check("  " .. key .. " lore 존재", #b.lore > 0)
	end
end

-- 모든 지역의 bossKey가 실제 보스로 존재해야 함
print("\n[Lore: 지역-보스 참조 무결성]")
for _, z in Lore.ZONES do
	local b = Lore.getBoss(z.bossKey)
	check(z.id .. " → " .. z.bossKey .. " 참조 유효", b ~= nil)
	check(z.id .. " hpMult>0", z.hpMult > 0)
	check(z.id .. " 적 풀 비어있지 않음", #z.enemyPool > 0)
end

-- 보스 kingdomNum이 지역 num과 일치
print("\n[Lore: 보스-지역 번호 일치]")
for _, z in Lore.ZONES do
	local b = Lore.getBoss(z.bossKey)
	if b then
		check(z.kingdom .. " num 일치 (" .. z.num .. ")", b.kingdomNum == z.num,
			"boss=" .. b.kingdomNum .. " zone=" .. z.num)
	end
end

print("\n[Lore: 웨이브→지역 해금]")
check("wave 0 → 미드가르드", Lore.zoneForWave(0).id == "Midgard_Forest")
check("wave 20 → 쿠소디아", Lore.zoneForWave(20).id == "Kusodia")
check("wave 130 → 세계수의 뿌리", Lore.zoneForWave(130).id == "Abyss")
check("최종 보스 키 유효", Lore.getBoss(Lore.FINAL_BOSS_KEY) ~= nil)

-- 해금 웨이브가 단조 증가해야 함
print("\n[Lore: 해금 곡선 단조성]")
local prev = -1
local mono = true
for _, z in Lore.ZONES do
	if z.unlockWave < prev then mono = false end
	prev = z.unlockWave
end
check("unlockWave 단조 증가", mono)

-- hpMult도 단조 증가
local prevM = -1
local monoM = true
for _, z in Lore.ZONES do
	if z.hpMult < prevM then monoM = false end
	prevM = z.hpMult
end
check("hpMult 단조 증가", monoM)

print("\n[Lore: 타워와 독립성]")
-- 세계관 데이터가 타워 밸런스에 영향을 주지 않아야 함
local t1 = TowerData.get("ApprenticeTurret")
check("타워 데이터는 Lore 미참조", t1 ~= nil and t1.damage == 10)

print(string.format("\n===== RESULT: %d passed, %d failed =====", pass, fail))
if fail > 0 then error("lore tests failed") end
