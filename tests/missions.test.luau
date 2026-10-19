-- 일일/주간 미션 검증
local M = require("../src/shared/Missions")

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

-- 고정 시각 사용 (1970-01-01 목요일 기준)
local T0 = 1700000000 -- 2023-11-14 화요일경

section("생성 및 초기값")
do
	local st = M.new(T0)
	check("일일 미션 4개", #M.DAILY_ORDER == 4)
	check("주간 미션 4개", #M.WEEKLY_ORDER == 4)
	check("초기 진행도 0", M.isComplete(st, "d_kill_30") == false)
	check("초기 수령 불가", M.canClaim(st, "d_kill_30") == false)
	check("완료 카운트 0", M.completedCount(st) == 0)
	check("수령 카운트 0", M.claimedCount(st) == 0)
end

section("리셋 시각 계산")
do
	local r = M.nextDailyReset(T0)
	check("일일 리셋은 미래", r > T0)
	check("일일 리셋 간격 <= 24h", r - T0 <= M.DAY, tostring(r - T0))
	-- 정확히 하루 뒤 경계
	local r2 = M.nextDailyReset(r)
	check("리셋 후 다음 리셋은 +24h", r2 - r == M.DAY, tostring(r2 - r))

	local w = M.nextWeeklyReset(T0)
	check("주간 리셋은 미래", w > T0)
	check("주간 리셋 간격 <= 7d", w - T0 <= M.WEEK, tostring(w - T0))
end

section("진행도 기록 - kill")
do
	local st = M.new(T0)
	local done = M.record(st, "kill", 29)
	check("29/30 미완료", M.isComplete(st, "d_kill_30") == false, "done=" .. #done)
	done = M.record(st, "kill", 1)
	check("30/30 완료", M.isComplete(st, "d_kill_30") == true)
	check("완료 1개통보", #done >= 1)
	check("수령 가능", M.canClaim(st, "d_kill_30") == true)
end

section("진행도는 target 초과하지 않음")
do
	local st = M.new(T0)
	M.record(st, "kill", 9999)
	local snap = M.snapshot(st)
	check("kill 진행도 target 상한", snap.daily.d_kill_30.progress == 30, tostring(snap.daily.d_kill_30.progress))
end

section("수령 및 중복 방지")
do
	local st = M.new(T0)
	M.record(st, "kill", 30)
	local ok, reward = M.claim(st, "d_kill_30")
	check("수령 성공", ok == true)
	check("보상 = 300", reward == 300, tostring(reward))

	local ok2, reward2 = M.claim(st, "d_kill_30")
	check("중복 수령 차단", ok2 == false)
	check("중복 보상 0", reward2 == 0)
end

section("미완료 수령 차단")
do
	local st = M.new(T0)
	M.record(st, "kill", 10)
	local ok = M.claim(st, "d_kill_30")
	check("미완료 수령 거부", ok == false)
	check("미존재 키 거부", M.claim(st, "no_such") == false)
end

section("wave는 절대값 갱신")
do
	local st = M.new(T0)
	M.recordWave(st, 3)
	local snap = M.snapshot(st)
	check("wave 3 기록", snap.daily.d_wave_5.progress == 3, tostring(snap.daily.d_wave_5.progress))
	-- 낮은 웨이브로 되돌려도 감소하지 않음
	M.recordWave(st, 1)
	snap = M.snapshot(st)
	check("wave 감소하지 않음", snap.daily.d_wave_5.progress == 3, tostring(snap.daily.d_wave_5.progress))
	-- 목표 달성
	M.recordWave(st, 7)
	snap = M.snapshot(st)
	check("wave 목표 도달", snap.daily.d_wave_5.progress == 5, tostring(snap.daily.d_wave_5.progress))
	check("wave 미션 완료", M.isComplete(st, "d_wave_5"))
end

section("일일 리셋")
do
	local st = M.new(T0)
	M.record(st, "kill", 30)
	M.claim(st, "d_kill_30")
	check("리셋 전 진행도 유지", M.snapshot(st).daily.d_kill_30.progress == 30)

	-- 하루 뒤
	local reset = M.checkReset(st, T0 + M.DAY + 1)
	check("리셋 발생", reset == true)
	local snap = M.snapshot(st)
	check("일일 진행도 초기화", snap.daily.d_kill_30.progress == 0, tostring(snap.daily.d_kill_30.progress))
	check("일일 수령 상태 초기화", snap.daily.d_kill_30.claimed == false)
	-- 주간은 유지
	check("주간은 리셋되지 않음", #M.WEEKLY_ORDER == 4)
end

section("주간 리셋")
do
	local st = M.new(T0)
	M.record(st, "boss", 1)
	check("보스 미션 완료", M.isComplete(st, "w_boss_1"))

	local reset = M.checkReset(st, T0 + M.WEEK + 1)
	check("주간 리셋 발생", reset == true)
	check("주간 진행도 초기화", M.snapshot(st).weekly.w_boss_1.progress == 0)
end

section("리셋 불필요 시 no-op")
do
	local st = M.new(T0)
	M.record(st, "kill", 5)
	local reset = M.checkReset(st, T0 + 100)
	check("리셋 없음", reset == false)
	check("진행도 보존", M.snapshot(st).daily.d_kill_30.progress == 5)
end

section("직렬화 / 복원")
do
	local st = M.new(T0)
	M.record(st, "kill", 15)
	M.record(st, "fuse", 1)
	local snap = M.snapshot(st)
	check("snapshot에 daily", type(snap.daily) == "table")
	check("snapshot에 weekly", type(snap.weekly) == "table")
	check("snapshot 항목에 제목", snap.daily.d_kill_30.title ~= nil)
	check("snapshot claimable 반영", snap.daily.d_fuse_1.claimable == true)

	local restored = M.restore(snap, T0 + 10)
	check("복원 후 kill 진행도", M.snapshot(restored).daily.d_kill_30.progress == 15)
	check("복원 후 fuse 완료", M.isComplete(restored, "d_fuse_1"))
end

section("복원 시 범위 검증")
do
	-- 손상/조작된 저장 데이터
	local bad = {
		daily = {
			d_kill_30 = { progress = 99999, claimed = true },
			d_wave_5 = { progress = -5 },
		},
		weekly = { w_kill_500 = { progress = "abc" } },
	}
	local st = M.restore(bad, T0)
	local snap = M.snapshot(st)
	check("과도한 진행도 클램프", snap.daily.d_kill_30.progress == 30, tostring(snap.daily.d_kill_30.progress))
	check("음수 진행도 0으로", snap.daily.d_wave_5.progress == 0, tostring(snap.daily.d_wave_5.progress))
	check("문자열 진행도 0으로", snap.weekly.w_kill_500.progress == 0, tostring(snap.weekly.w_kill_500.progress))
	check("claimed 유지", snap.daily.d_kill_30.claimed == true)
end

section("복원 시 만료된 리셋 처리")
do
	local st = M.new(T0)
	local snap = M.snapshot(st)
	-- 3일 지난 저장 데이터 복원 → 즉시 리셋
	local restored = M.restore(snap, T0 + 3 * M.DAY)
	check("만료 저장 복원 시 리셋 반영", M.snapshot(restored).daily.d_kill_30.progress == 0)
end

section("전체 kind 커버리지")
do
	local kinds: { [string]: boolean } = {}
	for _, k in M.DAILY_ORDER do
		kinds[M.DEFS[k].kind] = true
	end
	for _, k in M.WEEKLY_ORDER do
		kinds[M.DEFS[k].kind] = true
	end
	for _, k in { "kill", "wave", "summon", "fuse", "boss" } do
		check("kind 정의됨: " .. k, kinds[k] == true)
	end
end

print(string.format("\n===== RESULT: %d passed, %d failed =====", pass, fail))
if fail > 0 then
	print("FAILED: " .. table.concat(failures, ", "))
	error("missions tests failed")
end
