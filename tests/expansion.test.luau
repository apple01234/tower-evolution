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
		local chain = TowerData.familyChain(fam)
		check(fam .. " 체인 4단계", #chain == 4, tostring(#chain))
		if #chain == 4 then
			check(fam .. " 단계 순서 1..4", chain[1].tier == 1 and chain[4].tier == 4)
			check(fam .. " 최종은 nextKey 없음", chain[4].nextKey == nil)
			for i = 1, 3 do
				check(fam .. " " .. i .. "→" .. (i + 1) .. " 연결", chain[i].nextKey == chain[i + 1].key)
			end
		end
	end
	check("전체 타워 12종", #TowerData.all() == 12, tostring(#TowerData.all()))
end

section("계열별 정체성")
do
	local arcane = TowerData.familyChain("Arcane")
	local frost = TowerData.familyChain("Frost")
	local inferno = TowerData.familyChain("Inferno")

	check("Arcane 3단계는 Chain", arcane[3].attackKind == "Chain")
	check("Frost는 둔화 보유", frost[1].slowFactor ~= nil)
	check("Frost 최종 둔화 강함(<0.5)", (frost[4].slowFactor or 1) < 0.5, tostring(frost[4].slowFactor))
	check("Inferno 최종 최고 단일 피해", inferno[4].damage == 280, tostring(inferno[4].damage))
	check("Inferno는 느린 공속", inferno[4].attackSpeed < arcane[4].attackSpeed)
end

section("DPS 곡선 (계열 간 균형)")
do
	local sum = TowerData.familySummary()
	for _, fam in { "Arcane", "Frost", "Inferno" } do
		check(fam .. " 요약 존재", sum[fam] ~= nil)
		if sum[fam] then
			print(string.format("  %-8s 최종 %-20s DPS=%.1f", fam, sum[fam].finalName, sum[fam].finalDps))
		end
	end
	-- 4단계 DPS가 1단계보다 커야 함
	for _, fam in TowerData.FAMILY_KEYS do
		local c = TowerData.familyChain(fam)
		local dps1 = c[1].damage * c[1].attackSpeed
		local dps4 = c[4].damage * c[4].attackSpeed
		check(fam .. " 4단계 DPS > 1단계", dps4 > dps1, string.format("%.1f vs %.1f", dps4, dps1))
	end
end

section("합성 결과 (계열 내)")
do
	check("FrostShard→GlacierSpike", TowerData.fuseResult("FrostShard") == "GlacierSpike")
	check("EmberTurret→FlameLance", TowerData.fuseResult("EmberTurret") == "FlameLance")
	check("최종 단계 합성 불가", TowerData.fuseResult("AbsoluteZero") == nil)
	check("교차 계열 합성 경로 없음", TowerData.fuseResult("AstralSovereign") == nil)
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
