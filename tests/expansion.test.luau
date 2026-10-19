-- 3계열 확장 + 둔화 효과 검증
local TowerData = require("../src/shared/TowerData")
local Combat = require("../src/shared/Combat")

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

section("3계열 구조")
do
	check("계열 3종 정의", #TowerData.FAMILY_KEYS == 3, tostring(#TowerData.FAMILY_KEYS))
	for _, fam in { "Arcane", "Frost", "Inferno" } do
		local nodes = TowerData.familyChain(fam)
		-- 1,2,3단계 각 1개 + 4단계 2개(분기) = 5
		check(fam .. " 노드 5개 (분기 포함)", #nodes == 5, tostring(#nodes))
		local finals = 0
		for _, d in nodes do
			if #TowerData.nextOptions(d.key) == 0 then
				finals += 1
			end
		end
		check(fam .. " 최종 2개 (분기)", finals == 2, tostring(finals))
	end
	check("전체 타워 15종", #TowerData.all() == 15, tostring(#TowerData.all()))
end

section("계열별 정체성")
do
	local arcane = TowerData.familyChain("Arcane")
	local frost = TowerData.familyChain("Frost")
	local inferno = TowerData.familyChain("Inferno")

	local a3 = TowerData.get("ArcaneArtillery")
	check("Arcane 3단계는 Chain", a3 ~= nil and a3.attackKind == "Chain")
	local fs = TowerData.get("FrostShard")
	check("Frost는 둔화 보유", fs ~= nil and fs.slowFactor ~= nil)
	local fz = TowerData.get("CryoWarden")
	check("Frost 분기B 둔화 강함(<0.5)", fz ~= nil and (fz.slowFactor or 1) < 0.5, tostring(fz and fz.slowFactor))
	local fj = TowerData.get("FinalJudgment")
	check("Inferno 분기A 최고 단일 피해", fj ~= nil and fj.damage == 280, tostring(fj and fj.damage))
	local pz = TowerData.get("PyreZealot")
	check("Inferno 분기B는 고속", pz ~= nil and pz.attackSpeed > 1.0, tostring(pz and pz.attackSpeed))
end

section("DPS 곡선 (계열 간 균형)")
do
	local sum = TowerData.familySummary()
	for _, fam in { "Arcane", "Frost", "Inferno" } do
		check(fam .. " 요약 존재", sum[fam] ~= nil)
		if sum[fam] then
			print(string.format("  %-8s 노드 %d · 최종 %d · 최고 DPS %.1f",
				fam, sum[fam].nodes, sum[fam].finals, sum[fam].maxDps))
		end
	end
	-- 최고 DPS는 1단계보다 커야 함
	for _, fam in TowerData.FAMILY_KEYS do
		local root = TowerData.get(TowerData.FAMILY_ROOTS[fam])
		local dps1 = root and (root.damage * root.attackSpeed) or 0
		check(fam .. " 최고 DPS > 1단계", sum[fam].maxDps > dps1,
			string.format("%.1f vs %.1f", sum[fam].maxDps, dps1))
	end
end

section("합성 결과 (계열 내)")
do
	check("FrostShard→GlacierSpike", TowerData.fuseResult("FrostShard") == "GlacierSpike")
	check("EmberTurret→FlameLance", TowerData.fuseResult("EmberTurret") == "FlameLance")
	check("최종 단계 합성 불가", TowerData.fuseResult("AbsoluteZero") == nil)
	check("교차 계열 합성 경로 없음", TowerData.fuseResult("AstralSovereign") == nil)
	-- 분기: 선택 없이는 nil
	check("분기점은 선택 없이 nil", TowerData.fuseResult("ArcaneArtillery") == nil)
	check("분기 선택 A", TowerData.fuseResult("ArcaneArtillery", "AstralSovereign") == "AstralSovereign")
	check("분기 선택 B", TowerData.fuseResult("ArcaneArtillery", "StellarInquisitor") == "StellarInquisitor")
	check("잘못된 분기 거부", TowerData.fuseResult("ArcaneArtillery", "AbsoluteZero") == nil)
end

section("계열 루트 무결성")
do
	for _, fam in TowerData.FAMILY_KEYS do
		local root = TowerData.FAMILY_ROOTS[fam]
		check(fam .. " 루트 존재", root ~= nil)
		if root then
			local d = TowerData.get(root)
			check(fam .. " 루트 tier 1", d ~= nil and d.tier == 1)
			check(fam .. " 루트 계열 일치", d ~= nil and d.family == fam)
		end
	end
end

-- ============ 둔화 ============
section("둔화 효과")
do
	local e = { id = 1, hp = 1000, maxHp = 1000, pos = 0, alive = true, reward = 1, isBoss = false, speed = 10 }
	local enemies = { [1] = e }

	-- 둔화 없이
	local killed = Combat.applyHits(enemies, { { enemyId = 1, damage = 10 } })
	check("둔화 없으면 slowUntil 없음", e.slowUntil == nil)
	check("일반 피해 적용", e.hp == 990, tostring(e.hp))

	-- 둔화 적용 (now 주입)
	e.now = 100
	Combat.applyHits(enemies, { { enemyId = 1, damage = 10 } }, { factor = 0.5, duration = 2 })
	check("slowFactor 0.5", e.slowFactor == 0.5, tostring(e.slowFactor))
	check("slowUntil = 102", e.slowUntil == 102, tostring(e.slowUntil))

	-- 지속 시간 내 유효 속도
	local s1 = Combat.effectiveSpeed(e, 101)
	check("지속 중 속도 절반", s1 == 5, tostring(s1))

	-- 만료 후 원래 속도
	local s2 = Combat.effectiveSpeed(e, 103)
	check("만료 후 원래 속도", s2 == 10, tostring(s2))
end

section("둔화 중첩 규칙")
do
	local e = { id = 2, hp = 1000, maxHp = 1000, pos = 0, alive = true, reward = 1, isBoss = false, speed = 10, now = 50 }
	local enemies = { [2] = e }

	-- 약한 둔화 먼저
	Combat.applyHits(enemies, { { enemyId = 2, damage = 1 } }, { factor = 0.8, duration = 1 })
	check("1차 둔화 0.8", e.slowFactor == 0.8)

	-- 더 강한 둔화 → 더 강한 쪽 유지
	Combat.applyHits(enemies, { { enemyId = 2, damage = 1 } }, { factor = 0.5, duration = 3 })
	check("강한 둔화로 갱신", e.slowFactor == 0.5, tostring(e.slowFactor))
	check("지속시간 연장", e.slowUntil == 53, tostring(e.slowUntil))

	-- 약한 둔화 다시 → 배율은 강한 쪽 유지
	Combat.applyHits(enemies, { { enemyId = 2, damage = 1 } }, { factor = 0.9, duration = 1 })
	check("약한 둔화가 강한 것을 덮지 않음", e.slowFactor == 0.5, tostring(e.slowFactor))
end

section("죽은 적은 둔화되지 않음")
do
	local e = { id = 3, hp = 5, maxHp = 5, pos = 0, alive = true, reward = 1, isBoss = false, speed = 10 }
	local enemies = { [3] = e }
	local killed = Combat.applyHits(enemies, { { enemyId = 3, damage = 100 } }, { factor = 0.5, duration = 5 })
	check("사망 처리", #killed == 1)
	check("죽은 적 둔화 없음", e.slowFactor == nil)
end

section("계열별 공격 방식 확인")
do
	for _, fam in TowerData.FAMILY_KEYS do
		local c = TowerData.familyChain(fam)
		local kinds = {}
		for _, d in c do
			kinds[d.attackKind] = true
		end
		local n = 0
		for _ in kinds do
			n += 1
		end
		check(fam .. " 최소 2종 공격 방식", n >= 2, tostring(n))
	end
end

print(string.format("\n===== RESULT: %d passed, %d failed =====", pass, fail))
if fail > 0 then
	print("FAILED: " .. table.concat(failures, ", "))
	error("expansion tests failed")
end
