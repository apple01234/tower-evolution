--!strict
-- 전투 공유 상태. 여러 모듈이 같은 상태를 참조해야 하므로 한곳에 모은다.
-- (순환 require 회피: 상태만 보유하고 로직은 두지 않는다)

local BattleState = {}

-- 활성 적: [id] = enemy
BattleState.enemies = {} :: { [number]: any }

-- 현재 웨이브
BattleState.wave = 0
BattleState.waveActive = false

-- 기지 체력
BattleState.baseHp = 100
BattleState.baseMaxHp = 100 -- Config.BASE_HP 와 동기 (init에서 재설정)

-- 이번 회차 보스 처치 여부 (환생 조건)
BattleState.bossDefeatedThisRun = false

-- 배치된 타워: [userId] = { [cellKey] = tower }
BattleState.placed = {} :: { [number]: { [string]: any } }

-- RemoteEvent 참조 (Battle.init 에서 주입)
BattleState.events = nil :: any

-- 적 폴더 (Battle.init 에서 주입)
BattleState.enemyFolder = nil :: Instance?

function BattleState.resetRun()
	BattleState.wave = 0
	BattleState.waveActive = false
	BattleState.baseHp = BattleState.baseMaxHp
	BattleState.bossDefeatedThisRun = false
end

function BattleState.cellKey(col: number, row: number): string
	return tostring(col) .. "," .. tostring(row)
end

return BattleState
