-- Lune 헤드리스 테스트. Roblox 런타임 없이 순수 로직을 실제 실행해 검증한다.
local Combat = require("../src/shared/Combat")
local TowerData = require("../src/shared/TowerData")
local Inventory = require("../src/shared/Inventory")
local Config = require("../src/shared/Config")

local pass, fail = 0, 0
local failures = {}

local function check(name: string, cond: boolean, detail: string?)
	if cond then
		pass += 1
		print(string.format("  PASS  %s", name))
	else
		fail += 1
		table.insert(failures, name)
		print(string.format("  FAIL  %s  %s", name, detail or ""))
	end
end

local function section(s: string)
	print("\n[" .. s .. "]")
end

-- ============ 1. 타워 데이터 ============
section("TowerData")
check("4단계 체인 존재", #TowerData.chain("ApprenticeTurret") == 4)
check("견습→수정", TowerData.fuseResult("ApprenticeTurret") == "CrystalTurret")
check("수정→아케인", TowerData.fuseResult("CrystalTurret") == "ArcaneArtillery")
check("아케인→성운", TowerData.fuseResult("ArcaneArtillery") == "AstralSovereign")
check("성운은 최종(합성 불가)", TowerData.fuseResult("AstralSovereign") == nil)
check("미존재 키 반환 nil", TowerData.get("NoSuchTower") == nil)

do
	local kinds = {}
	for _, d in TowerData.all() do
		kinds[d.attackKind] = true
	end
	check("공격 방식 4종 모두 사용", kinds.Single and kinds.Pierce and kinds.Chain and kinds.Aoe)
	local t3 = TowerData.get("ArcaneArtillery")
	check("3단계는 Chain", t3 ~= nil and t3.attackKind == "Chain")
	local t4 = TowerData.get("AstralSovereign")
	check("4단계는 Aoe + 반경 보유", t4 ~= nil and t4.attackKind == "Aoe" and (t4.aoeRadius or 0) > 0)
end

-- ============ 2. 전투 계산 ============
section("Combat")

local function mkEnemy(id: number, hp: number, pos: number)
	return { id = id, hp = hp, maxHp = hp, pos = pos, alive = true, reward = 0, isBoss = false }
end

do
	-- Single: 가장 가까운 1마리만
	local enemies = { mkEnemy(1, 100, 2), mkEnemy(2, 100, 5), mkEnemy(3, 100, 9) }
	local distOf = function(e) return e.pos end
	local t1 = TowerData.get("ApprenticeTurret") :: any
	local hits = Combat.computeHits(t1, enemies, distOf, nil)
	check("Single은 1마리만 타격", #hits == 1)
	check("Single은 최근접 대상", #hits == 1 and hits[1].enemyId == 1)

	-- Pierce: 3마리 관통
	local t2 = TowerData.get("CrystalTurret") :: any
	local h2 = Combat.computeHits(t2, enemies, distOf, nil)
	check("Pierce는 3마리 관통", #h2 == 3, "got " .. #h2)

	-- Aoe: pos 2 기준 반경 9 이내
	local t4 = TowerData.get("AstralSovereign") :: any
	local h4 = Combat.computeHits(t4, enemies, distOf, nil)
	check("Aoe는 반경 내 다수 타격", #h4 >= 2, "got " .. #h4)
end

do
	-- Chain: 근접 연쇄 + 피해 감소
	local enemies = { mkEnemy(1, 500, 1), mkEnemy(2, 500, 2), mkEnemy(3, 500, 3), mkEnemy(4, 500, 50) }
	local distOf = function(e) return e.pos end
	local pairDist = function(a, b) return math.abs(a.pos - b.pos) end
	local t3 = TowerData.get("ArcaneArtillery") :: any
	local hits = Combat.computeHits(t3, enemies, distOf, pairDist)
	check("Chain은 3연쇄", #hits == 3, "got " .. #hits)
	check("Chain 피해 체감", #hits == 3 and hits[1].damage > hits[3].damage,
		#hits == 3 and (tostring(hits[1].damage) .. ">" .. tostring(hits[3].damage)) or "")
	local uniq = {}
	for _, h in hits do uniq[h.enemyId] = true end
	local n = 0
	for _ in uniq do n += 1 end
	check("Chain은 중복 대상 없음", n == #hits)
end

do
	-- 사거리 밖은 무시
	local enemies = { mkEnemy(1, 100, 999) }
	local distOf = function(e) return e.pos end
	local t1 = TowerData.get("ApprenticeTurret") :: any
	local hits = Combat.computeHits(t1, enemies, distOf, nil)
	check("사거리 밖 적 무시", #hits == 0)
end

-- ============ 3. 피해 적용 / 보상 중복 방지 ============
section("Damage & reward integrity")
do
	local e = mkEnemy(1, 50, 1)
	local map = { [1] = e }
	local killed, dmg = Combat.applyHits(map, { { enemyId = 1, damage = 60 } })
	check("치사 피해로 사망 처리", #killed == 1 and not e.alive)
	check("총 피해 집계", dmg == 60)

	-- 이미 죽은 적에게 추가 피해 → 중복 사망 없음
	local killed2, dmg2 = Combat.applyHits(map, { { enemyId = 1, damage = 60 } })
	check("죽은 적 재타격 무시(중복 보상 차단)", #killed2 == 0 and dmg2 == 0)
end

do
	-- 다중 히트에 같은 적이 두 번 들어와도 1회만 사망
	local e2 = mkEnemy(9, 10, 1)
	local map = { [9] = e2 }
	local killed = Combat.applyHits(map, {
		{ enemyId = 9, damage = 7 },
		{ enemyId = 9, damage = 7 },
	})
	check("한 틱 내 중복 히트도 사망 1회", #killed == 1)
end

-- ============ 4. 인벤토리 / 합성 ============
section("Inventory & fuse")
do
	local st = Inventory.new(1000)
	Inventory.add(st, "ApprenticeTurret")
	Inventory.add(st, "ApprenticeTurret")
	Inventory.add(st, "ApprenticeTurret")
	check("3개 추가", Inventory.count(st) == 3)

	local r = Inventory.fuse(st, { uids = { st.slots[1].uid, st.slots[2].uid, st.slots[3].uid } }, 75, Config.INVENTORY_CAP)
	check("정상 합성 검증 통과", r.ok == true)
	check("검증만으로는 상태 미변경(원자성)", Inventory.count(st) == 3)
	check("골드 차감액 보고", r.goldSpent == 75)

	local ok = Inventory.commitFuse(st, r, "CrystalTurret", Config.INVENTORY_CAP)
	check("커밋 성공", ok == true)
	check("재료 3개 소모", Inventory.count(st) == 0)
end

do
	-- 서로 다른 타워
	local st = Inventory.new(1000)
	Inventory.add(st, "ApprenticeTurret")
	Inventory.add(st, "ApprenticeTurret")
	Inventory.add(st, "CrystalTurret")
	local r = Inventory.fuse(st, { uids = { st.slots[1].uid, st.slots[2].uid, st.slots[3].uid } }, 0, 60)
	check("다른 타워 합성 거부", r.ok == false and r.err == "DIFFERENT_TOWER")
	check("거부 시 상태 유지", Inventory.count(st) == 3)
end

do
	-- 중복 uid 어뷰징
	local st = Inventory.new(1000)
	local s = Inventory.add(st, "ApprenticeTurret")
	local r = Inventory.fuse(st, { uids = { s.uid, s.uid, s.uid } }, 0, 60)
	check("중복 uid 거부", r.ok == false and r.err == "DUPLICATE_UID")
end

do
	-- 개수 부족
	local st = Inventory.new(1000)
	local s = Inventory.add(st, "ApprenticeTurret")
	local r = Inventory.fuse(st, { uids = { s.uid } }, 0, 60)
	check("2개 이하 합성 거부", r.ok == false and r.err == "INVALID_INPUT")
end

do
	-- 미소유 uid
	local st = Inventory.new(1000)
	Inventory.add(st, "ApprenticeTurret")
	Inventory.add(st, "ApprenticeTurret")
	Inventory.add(st, "ApprenticeTurret")
	local r = Inventory.fuse(st, { uids = { st.slots[1].uid, st.slots[2].uid, "u999" } }, 0, 60)
	check("미소유 uid 거부", r.ok == false and r.err == "NOT_OWNED")
end

do
	-- 골드 부족
	local st = Inventory.new(10)
	Inventory.add(st, "ApprenticeTurret")
	Inventory.add(st, "ApprenticeTurret")
	Inventory.add(st, "ApprenticeTurret")
	local r = Inventory.fuse(st, { uids = { st.slots[1].uid, st.slots[2].uid, st.slots[3].uid } }, 75, 60)
	check("골드 부족 거부", r.ok == false and r.err == "NOT_ENOUGH_GOLD")
end

do
	-- 커밋 이중 실행 방지 (같은 결과로 두 번 커밋)
	local st = Inventory.new(1000)
	Inventory.add(st, "ApprenticeTurret")
	Inventory.add(st, "ApprenticeTurret")
	Inventory.add(st, "ApprenticeTurret")
	local r = Inventory.fuse(st, { uids = { st.slots[1].uid, st.slots[2].uid, st.slots[3].uid } }, 0, 60)
	Inventory.commitFuse(st, r, "CrystalTurret", 60)
	local second = Inventory.commitFuse(st, r, "CrystalTurret", 60)
	check("동일 결과 이중 커밋 차단", second == false)
	check("이중 커밋 후 상태 변화 없음", Inventory.count(st) == 0)
end

-- ============ 5. 밸런스 / 웨이브 ============
section("Balance & waves")
do
	check("1웨이브 HP = 기본", Combat.enemyHp(1, Config.ENEMY_HP_BASE, Config.ENEMY_HP_GROWTH) == Config.ENEMY_HP_BASE)
	local hp10 = Combat.enemyHp(10, Config.ENEMY_HP_BASE, Config.ENEMY_HP_GROWTH)
	check("10웨이브 HP 증가", hp10 > Config.ENEMY_HP_BASE, "hp10=" .. hp10)
	check("보스 웨이브 판정(5)", Combat.isBossWave(5, Config.BOSS_EVERY) == true)
	check("일반 웨이브 판정(4)", Combat.isBossWave(4, Config.BOSS_EVERY) == false)
	check("보상은 최소 1", Combat.enemyReward(1) >= 1)
end

-- ============ 6. DPS 곡선 (밸런스 확인) ============
section("DPS curve")
for _, d in TowerData.all() do
	local dps = d.damage * d.attackSpeed
	print(string.format("  tier%d %-18s dps=%6.1f range=%d kind=%s", d.tier, d.key, dps, d.range, d.attackKind))
end

print(string.format("\n===== RESULT: %d passed, %d failed =====", pass, fail))
if fail > 0 then
	print("FAILED: " .. table.concat(failures, ", "))
	error("tests failed")
end
