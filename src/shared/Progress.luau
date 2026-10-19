--!strict
-- 성장 시스템: 환생(rebirth), 도감(collection), 지역 해금.
-- Roblox API 의존 없음 → Lune으로 직접 검증 가능.
-- 서버는 이 모듈의 결과만 신뢰한다.

local Progress = {}

-- 현재 회차
export type State = {
	gold: number,
	wave: number,
	-- 영구 데이터 (환생해도 유지)
	rebirths: number,
	research: { [string]: number }, -- 연구 key -> 레벨
	collection: { [string]: boolean }, -- 타워 key -> 해금 여부
	maxWaveEver: number,
	zoneUnlocked: { [string]: boolean },
}

export type RebirthRequirement = {
	minWave: number,
	minGold: number,
	bossKilled: boolean,
}

-- 연구 정의: 영구 배율
Progress.RESEARCH = {
	goldGain = {
		name = "골드 획득량",
		maxLevel = 10,
		perLevel = 0.10, -- +10%/lv
		baseCost = 1, -- 첫 환생(1pt)으로 1레벨 구매 가능
	},
	towerDamage = {
		name = "타워 공격력",
		maxLevel = 10,
		perLevel = 0.08, -- +8%/lv
		baseCost = 2,
	},
	summonCost = {
		name = "소환 비용 절감",
		maxLevel = 5,
		perLevel = 0.06, -- -6%/lv
		baseCost = 3,
	},
	evolveMaterial = {
		name = "진화 재료 획득",
		maxLevel = 5,
		perLevel = 0.10,
		baseCost = 3,
	},
}

Progress.RESEARCH_ORDER = { "goldGain", "towerDamage", "summonCost", "evolveMaterial" }

function Progress.new(gold: number): State
	return {
		gold = gold,
		wave = 0,
		rebirths = 0,
		research = {},
		collection = {},
		maxWaveEver = 0,
		zoneUnlocked = {},
	}
end

-- ============ 배율 계산 ============

function Progress.researchLevel(state: State, key: string): number
	return state.research[key] or 0
end

-- 연구 비용: baseCost * (level+1)^1.5, 반올림
function Progress.researchCost(key: string, currentLevel: number): number?
	local def = Progress.RESEARCH[key]
	if not def or currentLevel >= def.maxLevel then
		return nil
	end
	return math.floor(def.baseCost * ((currentLevel + 1) ^ 1.5))
end

-- 연구 레벨업 검증 + 실행. 실패 시 상태 불변.
function Progress.buyResearch(state: State, key: string): (boolean, string?)
	local def = Progress.RESEARCH[key]
	if not def then
		return false, "UNKNOWN_RESEARCH"
	end
	local lv = Progress.researchLevel(state, key)
	if lv >= def.maxLevel then
		return false, "MAX_LEVEL"
	end
	local cost = Progress.researchCost(key, lv)
	if not cost then
		return false, "NO_COST"
	end
	-- 연구 포인트 = 환생 횟수 - 사용한 포인트
	local points = Progress.researchPoints(state)
	if points < cost then
		return false, "NOT_ENOUGH_POINTS"
	end
	state.research[key] = lv + 1
	return true, nil
end

-- 연구 포인트: 환생 1회당 1 + 누적 보너스
function Progress.researchPoints(state: State): number
	local earned = state.rebirths + math.max(0, state.rebirths - 5) -- 6회차부터 +1씩
	local spent = 0
	for key, lv in state.research do
		local def = Progress.RESEARCH[key]
		if def then
			for i = 1, lv do
				spent += math.floor(def.baseCost * (i ^ 1.5))
			end
		end
	end
	return math.max(0, earned - spent)
end

function Progress.totalResearchSpent(state: State): number
	local spent = 0
	for key, lv in state.research do
		local def = Progress.RESEARCH[key]
		if def then
			for i = 1, lv do
				spent += math.floor(def.baseCost * (i ^ 1.5))
			end
		end
	end
	return spent
end

-- 배율 조회 (1.0 = 기본)
function Progress.goldMultiplier(state: State): number
	return 1 + Progress.researchLevel(state, "goldGain") * Progress.RESEARCH.goldGain.perLevel
end

function Progress.damageMultiplier(state: State): number
	return 1 + Progress.researchLevel(state, "towerDamage") * Progress.RESEARCH.towerDamage.perLevel
end

function Progress.summonCostMultiplier(state: State): number
	local r = 1 - Progress.researchLevel(state, "summonCost") * Progress.RESEARCH.summonCost.perLevel
	return math.max(0.4, r) -- 최대 60%까지 절감
end

function Progress.materialMultiplier(state: State): number
	return 1 + Progress.researchLevel(state, "evolveMaterial") * Progress.RESEARCH.evolveMaterial.perLevel
end

-- ============ 도감 ============

function Progress.unlockCollect(state: State, towerKey: string): boolean
	if state.collection[towerKey] then
		return false -- 이미 해금
	end
	state.collection[towerKey] = true
	return true
end

function Progress.hasCollected(state: State, towerKey: string): boolean
	return state.collection[towerKey] == true
end

function Progress.collectedCount(state: State): number
	local n = 0
	for _, v in state.collection do
		if v then
			n += 1
		end
	end
	return n
end

-- ============ 환생 ============

-- 요구 조건 생성 (환생 횟수가 늘수록 엄격)
function Progress.requirement(rebirths: number): RebirthRequirement
	return {
		minWave = 20 + rebirths * 10,
		minGold = 5000 * (rebirths + 1),
		bossKilled = true,
	}
end

-- 환생 가능 여부 검증 (상태를 변경하지 않음)
function Progress.canRebirth(state: State, bossDefeatedThisRun: boolean): (boolean, string?)
	local req = Progress.requirement(state.rebirths)
	if state.maxWaveEver < req.minWave then
		return false, "NEED_WAVE"
	end
	if state.gold < req.minGold then
		return false, "NEED_GOLD"
	end
	if req.bossKilled and not bossDefeatedThisRun then
		return false, "NEED_BOSS"
	end
	return true, nil
end

-- 환생 실행. 반드시 canRebirth가 true일 때 호출한다.
-- 초기화: gold, wave / 유지: rebirths, research, collection, maxWaveEver, zoneUnlocked
function Progress.applyRebirth(state: State, startGold: number): boolean
	state.rebirths += 1
	state.gold = startGold
	state.wave = 0
	return true
end

-- ============ 지역 해금 ============

function Progress.isZoneUnlocked(state: State, zoneId: string, unlockWave: number): boolean
	if unlockWave <= 0 then
		return true
	end
	if state.zoneUnlocked[zoneId] then
		return true
	end
	return state.maxWaveEver >= unlockWave
end

function Progress.recordWave(state: State, wave: number): boolean
	if wave > state.maxWaveEver then
		state.maxWaveEver = wave
		state.wave = wave
		return true
	end
	state.wave = wave
	return false
end

function Progress.recordZoneUnlock(state: State, zoneId: string): boolean
	if state.zoneUnlocked[zoneId] then
		return false
	end
	state.zoneUnlocked[zoneId] = true
	return true
end

-- 저장 직렬화용 요약
function Progress.summary(state: State): string
	return string.format(
		"환생 %d회 · 최고 웨이브 %d · 도감 %d · 연구 %dpt",
		state.rebirths,
		state.maxWaveEver,
		Progress.collectedCount(state),
		Progress.researchPoints(state)
	)
end

return Progress
