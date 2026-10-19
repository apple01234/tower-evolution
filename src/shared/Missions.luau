--!strict
-- 일일 / 주간 미션. Roblox API 무의존 → Lune 검증 가능.
-- 기간 판정은 Unix 초(now)를 주입받아 순수 함수로 유지한다.

local Missions = {}

-- 미션 정의. target: 요구량, reward: 골드, points: 연구 포인트
-- kind: "kill" | "summon" | "fuse" | "wave" | "boss"
Missions.DEFS = {
	-- 일일
	d_kill_30 = { kind = "kill", target = 30, reward = 300, period = "daily", title = "몬스터 30마리 처치" },
	d_wave_5 = { kind = "wave", target = 5, reward = 250, period = "daily", title = "웨이브 5 도달" },
	d_summon_3 = { kind = "summon", target = 3, reward = 200, period = "daily", title = "타워 3회 소환" },
	d_fuse_1 = { kind = "fuse", target = 1, reward = 400, period = "daily", title = "타워 1회 합성" },
	-- 주간
	w_kill_500 = { kind = "kill", target = 500, reward = 3000, period = "weekly", title = "몬스터 500마리 처치" },
	w_fuse_10 = { kind = "fuse", target = 10, reward = 2500, period = "weekly", title = "타워 10회 합성" },
	w_boss_1 = { kind = "boss", target = 1, reward = 2000, period = "weekly", title = "보스 1회 처치" },
	w_wave_30 = { kind = "wave", target = 30, reward = 2200, period = "weekly", title = "웨이브 30 도달" },
}

Missions.DAILY_ORDER = { "d_kill_30", "d_wave_5", "d_summon_3", "d_fuse_1" }
Missions.WEEKLY_ORDER = { "w_kill_500", "w_fuse_10", "w_boss_1", "w_wave_30" }

export type Entry = {
	progress: number,
	claimed: boolean,
}

export type State = {
	daily: { [string]: Entry },
	weekly: { [string]: Entry },
	dailyReset: number, -- 다음 리셋 시각 (unix)
	weeklyReset: number,
	dailySeed: number, -- 회차 식별용
	weeklySeed: number,
}

local DAY, WEEK = 86400, 604800
Missions.DAY, Missions.WEEK = DAY, WEEK

local function emptyEntries(order: { string }): { [string]: Entry }
	local t: { [string]: Entry } = {}
	for _, key in order do
		t[key] = { progress = 0, claimed = false }
	end
	return t
end

-- 다음 자정(UTC)까지의 시각
function Missions.nextDailyReset(now: number): number
	return now - (now % DAY) + DAY
end

-- 다음 주(UTC 월요일 00:00) 리셋
function Missions.nextWeeklyReset(now: number): number
	-- 1970-01-01 은 목요일. 월요일 정렬을 위해 +3일 오프셋.
	local shifted = now + 3 * DAY
	return shifted - (shifted % WEEK) + WEEK - 3 * DAY
end

function Missions.new(now: number): State
	return {
		daily = emptyEntries(Missions.DAILY_ORDER),
		weekly = emptyEntries(Missions.WEEKLY_ORDER),
		dailyReset = Missions.nextDailyReset(now),
		weeklyReset = Missions.nextWeeklyReset(now),
		dailySeed = math.floor(now / DAY),
		weeklySeed = math.floor((now + 3 * DAY) / WEEK),
	}
end

-- 리셋이 필요하면 초기화하고 true 반환. 필요 없으면 false.
function Missions.checkReset(state: State, now: number): boolean
	local reset = false
	if now >= state.dailyReset then
		state.daily = emptyEntries(Missions.DAILY_ORDER)
		state.dailyReset = Missions.nextDailyReset(now)
		state.dailySeed = math.floor(now / DAY)
		reset = true
	end
	if now >= state.weeklyReset then
		state.weekly = emptyEntries(Missions.WEEKLY_ORDER)
		state.weeklyReset = Missions.nextWeeklyReset(now)
		state.weeklySeed = math.floor((now + 3 * DAY) / WEEK)
		reset = true
	end
	return reset
end

local function bucketOf(state: State, key: string): (any, Entry?)
	local def = Missions.DEFS[key]
	if not def then
		return nil, nil
	end
	local b = def.period == "daily" and state.daily or state.weekly
	return b, b[key]
end
-- 진행도 갱신 공용 루프. apply(entry, def) 가 새 진행도를 반환한다.
local function forEachMatch(state: State, kind: string, apply: (Entry, any) -> number): { string }
	local done: { string } = {}
	for _, order in { Missions.DAILY_ORDER, Missions.WEEKLY_ORDER } do
		for _, key in order do
			local def = Missions.DEFS[key]
			if def and def.kind == kind then
				local _, entry = bucketOf(state, key)
				if entry and not entry.claimed then
					local before = entry.progress
					entry.progress = apply(entry, def)
					if before < def.target and entry.progress >= def.target then
						table.insert(done, key)
					end
				end
			end
		end
	end
	return done
end

-- 누적형 이벤트 기록 (kill / summon / fuse / boss)
function Missions.record(state: State, kind: string, amount: number?): { string }
	local inc = amount or 1
	return forEachMatch(state, kind, function(entry, def)
		return math.min(def.target, entry.progress + inc)
	end)
end

-- 절대값 이벤트 기록 (wave). 감소하지 않는다.
function Missions.recordWave(state: State, wave: number): { string }
	return forEachMatch(state, "wave", function(entry, def)
		if wave > entry.progress then
			return math.min(def.target, wave)
		end
		return entry.progress
	end)
end

function Missions.isComplete(state: State, key: string): boolean
	local def = Missions.DEFS[key]
	local _, entry = bucketOf(state, key)
	return def ~= nil and entry ~= nil and entry.progress >= def.target
end

function Missions.canClaim(state: State, key: string): boolean
	local _, entry = bucketOf(state, key)
	return entry ~= nil and not entry.claimed and Missions.isComplete(state, key)
end

-- 수령. 성공 시 (true, reward) 반환. 중복 수령 불가.
function Missions.claim(state: State, key: string): (boolean, number)
	if not Missions.canClaim(state, key) then
		return false, 0
	end
	local def = Missions.DEFS[key]
	local _, entry = bucketOf(state, key)
	if not def or not entry then
		return false, 0
	end
	entry.claimed = true
	return true, def.reward
end

-- 조건에 맞는 미션 개수
local function countWhere(state: State, pred: (string, Entry) -> boolean): number
	local n = 0
	for _, order in { Missions.DAILY_ORDER, Missions.WEEKLY_ORDER } do
		for _, key in order do
			local _, entry = bucketOf(state, key)
			if entry and pred(key, entry) then
				n += 1
			end
		end
	end
	return n
end

function Missions.claimedCount(state: State): number
	return countWhere(state, function(_, entry)
		return entry.claimed
	end)
end

function Missions.completedCount(state: State): number
	return countWhere(state, function(key)
		return Missions.isComplete(state, key)
	end)
end

-- 저장/전송용 직렬화
function Missions.snapshot(state: State): { [string]: any }
	local function pack(order: { string }): { [string]: any }
		local out: { [string]: any } = {}
		for _, key in order do
			local def = Missions.DEFS[key]
			local _, entry = bucketOf(state, key)
			out[key] = {
				title = def and def.title or key,
				period = def and def.period or "daily",
				target = def and def.target or 0,
				reward = def and def.reward or 0,
				progress = entry and entry.progress or 0,
				claimed = entry and entry.claimed or false,
				complete = Missions.isComplete(state, key),
				claimable = Missions.canClaim(state, key),
			}
		end
		return out
	end
	return {
		daily = pack(Missions.DAILY_ORDER),
		weekly = pack(Missions.WEEKLY_ORDER),
		dailyReset = state.dailyReset,
		weeklyReset = state.weeklyReset,
	}
end

-- 저장 복원
function Missions.restore(raw: any, now: number): State
	local st = Missions.new(now)
	if type(raw) ~= "table" then
		return st
	end
	st.dailyReset = tonumber(raw.dailyReset) or st.dailyReset
	st.weeklyReset = tonumber(raw.weeklyReset) or st.weeklyReset
	st.dailySeed = tonumber(raw.dailySeed) or st.dailySeed
	st.weeklySeed = tonumber(raw.weeklySeed) or st.weeklySeed

	for _, pair in { { raw.daily, st.daily }, { raw.weekly, st.weekly } } do
		local src, dst = pair[1], pair[2]
		if type(src) == "table" then
			for key, v in src do
				if dst[key] and type(v) == "table" then
					local def = Missions.DEFS[key]
					local prog = math.max(0, math.floor(tonumber(v.progress) or 0))
					if def then
						prog = math.min(prog, def.target)
					end
					dst[key].progress = prog
					dst[key].claimed = v.claimed == true
				end
			end
		end
	end
	-- 복원 후 이미 지난 리셋은 즉시 처리
	Missions.checkReset(st, now)
	return st
end

return Missions
