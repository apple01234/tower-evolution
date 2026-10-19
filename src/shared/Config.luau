--!strict
-- 중앙 밸런스 설정. 모든 수치는 이 파일에서만 관리한다.
local Config = {}

Config.VERSION = "0.1.0"

-- 그리드 (타워 배치)
Config.GRID_COLS = 7
Config.GRID_ROWS = 5
Config.CELL_SIZE = 6

-- 경제
Config.START_GOLD = 300
Config.SUMMON_COST_BASE = 50
Config.SUMMON_COST_GROWTH = 1.15 -- 소환할수록 비싸짐
Config.FUSE_COST_BASE = 75
Config.INVENTORY_CAP = 60

-- 재화 검증 상한 (비정상 요청 차단)
Config.MAX_GOLD = 1e15

-- 웨이브
Config.BASE_HP = 100 -- 기지 체력
Config.WAVE_BREAK_SECONDS = 6
Config.BOSS_EVERY = 5 -- 5웨이브마다 보스
Config.ENEMY_HP_BASE = 30
Config.ENEMY_HP_GROWTH = 1.18
Config.ENEMY_SPEED = 8
Config.BOSS_HP_MULT = 8
Config.BOSS_SPEED_MULT = 0.6

-- 협동 보스 (여러 플레이어가 HP 공유)
Config.COOP_BOSS_HP_MULT = 6 -- 일반 보스 대비 배율 (참가자 수 고려)
Config.COOP_BOSS_REWARD_PER_HP = 0.5 -- HP 1당 보상 골드
Config.COOP_BOSS_TIMEOUT = 180 -- 초과 시 퇴장
Config.COOP_BOSS_INTERVAL = 45 -- 자동 등장 간격(초)

-- 적 경로 (그리드 좌표를 월드 좌표로 변환해 사용)
-- 값은 (col, row) 그리드 좌표. 서버가 월드 좌표로 환산한다.
Config.PATH = {
	{ -1, 2 },
	{ 1, 2 },
	{ 1, 0 },
	{ 3, 0 },
	{ 3, 4 },
	{ 5, 4 },
	{ 5, 1 },
	{ 7, 1 },
}

-- 요청 빈도 제한 (초당)
Config.RATE = {
	SUMMON = 6,
	FUSE = 6,
	PLACE = 10,
	UPGRADE = 10,
}

-- 데이터 저장
Config.DATASTORE_NAME = "TowerEvolution_v1"
Config.AUTOSAVE_SECONDS = 120

-- 지역: 이그드라실 9왕국 (src/shared/Lore.luau에서 정의)
-- Config는 밸런스만 담고, 세계관은 Lore 모듈이 담당한다.

return Config
