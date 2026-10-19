-- 협동 보스 검증
local CoopBoss = require("../src/shared/CoopBoss")

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

local T0 = 1000

section("생성")
do
	local b = CoopBoss.new("abudditos", "종언의 마룡", 10000, T0)
	check("HP 10000", b.hp == 10000)
	check("활성 상태", b.active == true)
	check("참가자 0", CoopBoss.participantCount(b) == 0)
	check("진행률 0", CoopBoss.progress(b) == 0)
	check("사망 아님", CoopBoss.isDead(b) == false)
end

section("단일 피해")
do
	local b = CoopBoss.new("g", "수호자", 1000, T0)
	local applied = CoopBoss.applyDamage(b, 1, 100, T0)
	check("100 피해 적용", applied == 100)
	check("HP 900", b.hp == 900, tostring(b.hp))
	check("참가자 1명", CoopBoss.participantCount(b) == 1)
	check("진행률 0.1", math.abs(CoopBoss.progress(b) - 0.1) < 0.001)
	check("막타 기록", b.lastHitUserId == 1)
end

section("다중 참가자 누적")
do
	local b = CoopBoss.new("g", "수호자", 1000, T0)
	CoopBoss.applyDamage(b, 1, 100, T0)
	CoopBoss.applyDamage(b, 2, 300, T0)
	CoopBoss.applyDamage(b, 1, 50, T0)
	check("참가자 2명", CoopBoss.participantCount(b) == 2)
	check("총 피해 450", CoopBoss.totalDamage(b) == 450, tostring(CoopBoss.totalDamage(b)))
	check("userId1 기여 150", b.participants[1].damage == 150, tostring(b.participants[1].damage))
	check("userId2 기여 300", b.participants[2].damage == 300)
	check("막타는 1", b.lastHitUserId == 1)
end

section("오버킬 처리 (HP 초과 피해 무시)")
do
	local b = CoopBoss.new("g", "수호자", 100, T0)
	local applied = CoopBoss.applyDamage(b, 1, 500, T0)
	check("적용 피해는 100로 제한", applied == 100, tostring(applied))
	check("HP 0", b.hp == 0)
	check("기여도도 100", b.participants[1].damage == 100, tostring(b.participants[1].damage))
	check("사망 상태", CoopBoss.isDead(b))
end

section("사망 후 피해 무시 (중복 보상 차단)")
do
	local b = CoopBoss.new("g", "수호자", 100, T0)
	CoopBoss.applyDamage(b, 1, 100, T0)
	check("사망", CoopBoss.isDead(b))

	local applied = CoopBoss.applyDamage(b, 2, 500, T0)
	check("사망 후 피해 0", applied == 0, tostring(applied))
	check("참가자 추가 안 됨", CoopBoss.participantCount(b) == 1)
	check("HP 음수 아님", b.hp == 0)
end

section("잘못된 입력")
do
	local b = CoopBoss.new("g", "수호자", 100, T0)
	check("0 피해 무시", CoopBoss.applyDamage(b, 1, 0, T0) == 0)
	check("음수 피해 무시", CoopBoss.applyDamage(b, 1, -50, T0) == 0)
	check("HP 변화 없음", b.hp == 100)
	check("참가자 없음", CoopBoss.participantCount(b) == 0)
end

section("보상 분배 — 단독")
do
	local b = CoopBoss.new("g", "수호자", 100, T0)
	CoopBoss.applyDamage(b, 1, 100, T0)
	local rewards = CoopBoss.distribute(b, 1000)
	check("단독 참가자 전액", rewards[1] == 1000, tostring(rewards[1]))
end

section("보상 분배 — 기여도 비례")
do
	local b = CoopBoss.new("g", "수호자", 1000, T0)
	-- 1번이 100, 2번이 900
	CoopBoss.applyDamage(b, 1, 100, T0)
	CoopBoss.applyDamage(b, 2, 900, T0)

	local rewards = CoopBoss.distribute(b, 10000)
	local r1 = rewards[1] or 0
	local r2 = rewards[2] or 0

	check("2번이 더 많이 받음", r2 > r1, string.format("%d vs %d", r1, r2))
	check("총액 초과 없음", r1 + r2 <= 10000, tostring(r1 + r2))
	check("총액 근접 (90% 이상)", (r1 + r2) >= 9000, tostring(r1 + r2))
	-- 2번은 90% 기여 + 막타(마지막 피해자)
	check("2번 비중 큼 (>=70%)", r2 >= 7000, string.format("%d", r2))
end

section("보상 분배 — 막타 보너스")
do
	local b = CoopBoss.new("g", "수호자", 1000, T0)
	-- 동일 기여, 2번이 막타
	CoopBoss.applyDamage(b, 1, 500, T0)
	CoopBoss.applyDamage(b, 2, 500, T0)

	check("막타는 2번", b.lastHitUserId == 2)
	local rewards = CoopBoss.distribute(b, 10000)
	check("막타가 약간 더 받음", (rewards[2] or 0) >= (rewards[1] or 0),
		string.format("%d vs %d", rewards[2] or 0, rewards[1] or 0))
end

section("보상 분배 — 참가자 없음")
do
	local b = CoopBoss.new("g", "수호자", 1000, T0)
	local rewards = CoopBoss.distribute(b, 10000)
	local n = 0
	for _ in rewards do n += 1 end
	check("참가자 없으면 빈 테이블", n == 0)
end

section("보상 분배 — 음수/0 보상")
do
	local b = CoopBoss.new("g", "수호자", 100, T0)
	CoopBoss.applyDamage(b, 1, 100, T0)
	local z = CoopBoss.distribute(b, 0)
	local n0 = 0
	for _ in z do n0 += 1 end
	check("0 보상은 빈 테이블", n0 == 0)

	local neg = CoopBoss.distribute(b, -500)
	local n1 = 0
	for _ in neg do n1 += 1 end
	check("음수 보상은 빈 테이블", n1 == 0)
end

section("순위")
do
	local b = CoopBoss.new("g", "수호자", 10000, T0)
	CoopBoss.applyDamage(b, 10, 100, T0)
	CoopBoss.applyDamage(b, 20, 500, T0)
	CoopBoss.applyDamage(b, 30, 300, T0)

	local rank = CoopBoss.ranking(b)
	check("순위 3명", #rank == 3)
	check("1위 userId 20", rank[1].userId == 20, tostring(rank[1].userId))
	check("2위 userId 30", rank[2].userId == 30)
	check("3위 userId 10", rank[3].userId == 10)
end

section("동점 시 결정론적 정렬")
do
	local b = CoopBoss.new("g", "수호자", 10000, T0)
	CoopBoss.applyDamage(b, 50, 100, T0)
	CoopBoss.applyDamage(b, 40, 100, T0)
	local rank = CoopBoss.ranking(b)
	check("동점은 userId 오름차순", rank[1].userId == 40, tostring(rank[1].userId))
end

section("만료")
do
	local b = CoopBoss.new("g", "수호자", 1000, T0)
	check("직후 만료 아님", CoopBoss.isExpired(b, T0 + 10, 300) == false)
	check("초과 시 만료", CoopBoss.isExpired(b, T0 + 400, 300) == true)

	-- 사망한 보스는 만료 취급
	CoopBoss.applyDamage(b, 1, 1000, T0)
	check("사망 보스는 만료", CoopBoss.isExpired(b, T0 + 1, 300) == true)
end

section("보상 총액 무결성 (여러 시나리오)")
do
	local scenarios = {
		{ damages = { 10, 20, 30 }, reward = 1000 },
		{ damages = { 1, 1, 1, 1, 1 }, reward = 777 },
		{ damages = { 999 }, reward = 100 },
		{ damages = { 5, 995 }, reward = 12345 },
	}
	for i, sc in scenarios do
		local b = CoopBoss.new("g", "수호자", 100000, T0)
		for uid, dmg in sc.damages do
			CoopBoss.applyDamage(b, uid, dmg, T0)
		end
		local rewards = CoopBoss.distribute(b, sc.reward)
		local sum = 0
		for _, v in rewards do
			sum += v
		end
		check(string.format("시나리오%d 총액 초과 없음", i), sum <= sc.reward,
			string.format("%d > %d", sum, sc.reward))
		check(string.format("시나리오%d 총액 근접", i), sum >= math.floor(sc.reward * 0.9),
			string.format("%d / %d", sum, sc.reward))
	end
end

section("진행률 경계")
do
	local b = CoopBoss.new("g", "수호자", 1000, T0)
	check("초기 0", CoopBoss.progress(b) == 0)
	CoopBoss.applyDamage(b, 1, 500, T0)
	check("중간 0.5", math.abs(CoopBoss.progress(b) - 0.5) < 0.001)
	CoopBoss.applyDamage(b, 1, 500, T0)
	check("완료 1.0", math.abs(CoopBoss.progress(b) - 1.0) < 0.001)
end

print(string.format("\n===== RESULT: %d passed, %d failed =====", pass, fail))
if fail > 0 then
	print("FAILED: " .. table.concat(failures, ", "))
	error("coop boss tests failed")
end
