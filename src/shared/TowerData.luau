--!strict
-- 타워 정의 및 진화 트리. 새 타워 계열은 이 테이블에만 추가하면 된다.
-- 전투 코드는 key 기반으로 동작하므로 타워가 늘어도 복사가 필요 없다.

export type AttackKind = "Single" | "Pierce" | "Chain" | "Aoe"

export type TowerDef = {
	key: string,
	name: string,
	tier: number,
	rarity: string,
	damage: number,
	attackSpeed: number, -- 초당 공격 횟수
	range: number,
	attackKind: AttackKind,
	projectileSpeed: number,
	-- 진화별 차별화 파라미터
	pierceCount: number?, -- Pierce
	chainCount: number?, -- Chain
	chainFalloff: number?, -- Chain
	aoeRadius: number?, -- Aoe
	-- 진화 조건
	nextKey: string?,
	fuseCost: number,
	-- 도감
	collectionHint: string,
}

local Towers: { [string]: TowerDef } = {}

local function def(d: TowerDef): TowerDef
	Towers[d.key] = d
	return d
end

-- MVP: 단일 계열 4단계
def({
	key = "ApprenticeTurret",
	name = "견습 포탑",
	tier = 1,
	rarity = "Common",
	damage = 10,
	attackSpeed = 1.0,
	range = 14,
	attackKind = "Single",
	projectileSpeed = 60,
	nextKey = "CrystalTurret",
	fuseCost = 75,
	collectionHint = "기본 타워. 게임 시작 시 지급",
})

def({
	key = "CrystalTurret",
	name = "수정 포탑",
	tier = 2,
	rarity = "Uncommon",
	damage = 26,
	attackSpeed = 1.2,
	range = 16,
	attackKind = "Pierce",
	projectileSpeed = 70,
	pierceCount = 3,
	nextKey = "ArcaneArtillery",
	fuseCost = 150,
	collectionHint = "견습 포탑 3개 합성",
})

def({
	key = "ArcaneArtillery",
	name = "아케인 포병",
	tier = 3,
	rarity = "Rare",
	damage = 62,
	attackSpeed = 0.9,
	range = 19,
	attackKind = "Chain",
	projectileSpeed = 90,
	chainCount = 3,
	chainFalloff = 0.7,
	nextKey = "AstralSovereign",
	fuseCost = 400,
	collectionHint = "수정 포탑 3개 합성",
})

def({
	key = "AstralSovereign",
	name = "성운의 지배자",
	tier = 4,
	rarity = "Legendary",
	damage = 180,
	attackSpeed = 0.7,
	range = 22,
	attackKind = "Aoe",
	projectileSpeed = 80,
	aoeRadius = 9,
	nextKey = nil,
	fuseCost = 0,
	collectionHint = "아케인 포병 3개 합성",
})

local TowerData = {}

TowerData.DEFS = Towers

TowerData.ROOT_KEY = "ApprenticeTurret"

function TowerData.get(key: string): TowerDef?
	return Towers[key]
end

function TowerData.exists(key: string): boolean
	return Towers[key] ~= nil
end

-- 합성 결과 조회: 같은 key 3개 -> nextKey 1개
function TowerData.fuseResult(key: string): string?
	local d = Towers[key]
	if not d then
		return nil
	end
	return d.nextKey
end

-- 진화 체인(도감 표시용)
function TowerData.chain(key: string): { TowerDef }
	local out = {}
	local cur: string? = key
	local guard = 0
	while cur and guard < 32 do
		local d = Towers[cur]
		if not d then
			break
		end
		table.insert(out, d)
		cur = d.nextKey
		guard += 1
	end
	return out
end

function TowerData.all(): { TowerDef }
	local out = {}
	for _, d in Towers do
		table.insert(out, d)
	end
	table.sort(out, function(a, b)
		return a.tier < b.tier
	end)
	return out
end

return TowerData
