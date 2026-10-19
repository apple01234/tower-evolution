-- 분기 진화 검증
local TowerData = require("../src/shared/TowerData")

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

section("분기점 식별")
do
	-- 각 계열 3단계가 분기점
	for _, fam in { "Arcane", "Frost", "Inferno" } do
		local nodes = TowerData.familyChain(fam)
		local branchPoint = nil
		for _, d in nodes do
			if TowerData.requiresChoice(d.key) then
				branchPoint = d
				break
			end
		end
		check(fam .. " 분기점 존재", branchPoint ~= nil)
		if branchPoint then
			check(fam .. " 분기점은 3단계", branchPoint.tier == 3, tostring(branchPoint.tier))
			local opts = TowerData.nextOptions(branchPoint.key)
			check(fam .. " 분기 경로 2개", #opts == 2, tostring(#opts))
		end
	end
end

section("선택 없이는 진화 불가")
do
	check("ArcaneArtillery 선택 필요", TowerData.requiresChoice("ArcaneArtillery"))
	check("Permafrost 선택 필요", TowerData.requiresChoice("Permafrost"))
	check("BlastForge 선택 필요", TowerData.requiresChoice("BlastForge"))
	check("1단계는 선택 불필요", TowerData.requiresChoice("ApprenticeTurret") == false)
	check("2단계는 선택 불필요", TowerData.requiresChoice("CrystalTurret") == false)
end

section("분기 선택 검증 (서버 게이트)")
do
	-- 올바른 선택
	local a = TowerData.fuseResult("ArcaneArtillery", "AstralSovereign")
	check("A 경로 허용", a == "AstralSovereign")
	local b = TowerData.fuseResult("ArcaneArtillery", "StellarInquisitor")
	check("B 경로 허용", b == "StellarInquisitor")

	-- 다른 계열 타워를 선택하면 거부 (핵심 보안)
	local cross = TowerData.fuseResult("ArcaneArtillery", "AbsoluteZero")
	check("교차 계열 선택 거부", cross == nil)
	local bogus = TowerData.fuseResult("ArcaneArtillery", "NoSuchTower")
	check("존재하지 않는 키 거부", bogus == nil)
	local lower = TowerData.fuseResult("ArcaneArtillery", "Crystalturret")
	check("대소문자 변형 거부", lower == nil)
end

section("자동 진행 (단일 경로)")
do
	check("1→2 자동", TowerData.fuseResult("ApprenticeTurret") == "CrystalTurret")
	check("2→3 자동", TowerData.fuseResult("CrystalTurret") == "ArcaneArtillery")
	check("Frost 1→2 자동", TowerData.fuseResult("FrostShard") == "GlacierSpike")
	check("Inferno 2→3 자동", TowerData.fuseResult("FlameLance") == "BlastForge")
end

section("최종 단계")
do
	local finals = {
		"AstralSovereign", "StellarInquisitor",
		"AbsoluteZero", "CryoWarden",
		"FinalJudgment", "PyreZealot",
	}
	for _, k in finals do
		check(k .. " 최종 (경로 없음)", #TowerData.nextOptions(k) == 0)
		check(k .. " 합성 불가", TowerData.fuseResult(k) == nil)
		check(k .. " 선택 불필요", TowerData.requiresChoice(k) == false)
	end
	check("최종 단계 6종", #finals == 6)
end

section("분기 간 차별화")
do
	-- Arcane: 광역 vs 연쇄
	local sov = TowerData.get("AstralSovereign")
	local inq = TowerData.get("StellarInquisitor")
	check("성운은 Aoe", sov ~= nil and sov.attackKind == "Aoe")
	check("심판관은 Chain", inq ~= nil and inq.attackKind == "Chain")
	check("심판관 연쇄 수 많음", (inq.chainCount or 0) > 3, tostring(inq and inq.chainCount))
	check("성운 단일피해 높음", (sov.damage or 0) > (inq.damage or 0))

	-- Frost: 광역 둔화 vs 집중 냉동
	local az = TowerData.get("AbsoluteZero")
	local cw = TowerData.get("CryoWarden")
	check("절대영도는 Aoe", az ~= nil and az.attackKind == "Aoe")
	check("파수꾼은 Single", cw ~= nil and cw.attackKind == "Single")
	check("파수꾼 둔화 더 강함", (cw.slowFactor or 1) < (az.slowFactor or 1))
	check("파수꾼 둔화 더 김", (cw.slowDuration or 0) > (az.slowDuration or 0))

	-- Inferno: 초광역 vs 연사
	local fj = TowerData.get("FinalJudgment")
	local pz = TowerData.get("PyreZealot")
	check("심판은 Aoe", fj ~= nil and fj.attackKind == "Aoe")
	check("광신도는 Pierce", pz ~= nil and pz.attackKind == "Pierce")
	check("광신도 공속 빠름", (pz.attackSpeed or 0) > (fj.attackSpeed or 0))
	check("심판 단일피해 높음", (fj.damage or 0) > (pz.damage or 0))
end

section("트리 무결성")
do
	-- 순환 참조 없음
	for _, fam in TowerData.FAMILY_KEYS do
		local nodes = TowerData.familyChain(fam)
		local seen = {}
		local hasCycle = false
		for _, d in nodes do
			if seen[d.key] then
				hasCycle = true
			end
			seen[d.key] = true
		end
		check(fam .. " 순환 참조 없음", hasCycle == false)
		check(fam .. " 노드 수 5", #nodes == 5, tostring(#nodes))
	end

	-- 모든 nextKeys 대상이 존재
	for _, d in TowerData.all() do
		for _, nk in TowerData.nextOptions(d.key) do
			check(d.key .. "→" .. nk .. " 대상 존재", TowerData.exists(nk))
		end
	end
end

section("subtree 탐색")
do
	local tree = TowerData.subtree("ArcaneArtillery")
	check("3단계 서브트리 3개 (자기+분기2)", #tree == 3, tostring(#tree))
	local rootTree = TowerData.subtree("ApprenticeTurret")
	check("루트 서브트리 5개", #rootTree == 5, tostring(#rootTree))
end

section("도감 수집 가능성")
do
	-- 모든 타워가 도감 대상 (15종)
	local all = TowerData.all()
	check("전체 15종", #all == 15, tostring(#all))
	local tiers = {}
	for _, d in all do
		tiers[d.tier] = (tiers[d.tier] or 0) + 1
	end
	check("1단계 3종", tiers[1] == 3, tostring(tiers[1]))
	check("2단계 3종", tiers[2] == 3, tostring(tiers[2]))
	check("3단계 3종", tiers[3] == 3, tostring(tiers[3]))
	check("4단계 6종 (분기)", tiers[4] == 6, tostring(tiers[4]))
end

print(string.format("\n===== RESULT: %d passed, %d failed =====", pass, fail))
if fail > 0 then
	print("FAILED: " .. table.concat(failures, ", "))
	error("branch tests failed")
end
