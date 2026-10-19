--!strict
-- Arcane 계열: 단일 → 관통 → 연쇄 → [분기] 광역 / 단일특화
-- 3단계(ArcaneArtillery)에서 두 갈래로 나뉜다.
local Towers: { [string]: any } = {}

local function def(d: any): any
	Towers[d.key] = d
	return d
end

def({
	key = "ApprenticeTurret",
	name = "견습 포탑",
	tier = 1,
	rarity = "Common",
	family = "Arcane",
	damage = 10,
	attackSpeed = 1.0,
	range = 14,
	attackKind = "Single",
	projectileSpeed = 60,
	nextKeys = { "CrystalTurret" },
	fuseCost = 75,
	collectionHint = "기본 타워. 게임 시작 시 지급",
})

def({
	key = "CrystalTurret",
	name = "수정 포탑",
	tier = 2,
	rarity = "Uncommon",
	family = "Arcane",
	damage = 26,
	attackSpeed = 1.2,
	range = 16,
	attackKind = "Pierce",
	projectileSpeed = 70,
	pierceCount = 3,
	nextKeys = { "ArcaneArtillery" },
	fuseCost = 150,
	collectionHint = "견습 포탑 3개 합성",
})

-- ============ 분기점: 3단계 ============
def({
	key = "ArcaneArtillery",
	name = "아케인 포병",
	tier = 3,
	rarity = "Rare",
	family = "Arcane",
	damage = 62,
	attackSpeed = 0.9,
	range = 19,
	attackKind = "Chain",
	projectileSpeed = 90,
	chainCount = 3,
	chainFalloff = 0.7,
	-- 분기: 광역형(성운) / 연쇄특화형(별의 심판관)
	nextKeys = { "AstralSovereign", "StellarInquisitor" },
	fuseCost = 400,
	collectionHint = "수정 포탑 3개 합성 후 진화 방향 선택",
})

-- ============ 분기 A: 광역 폭발형 ============
def({
	key = "AstralSovereign",
	name = "성운의 지배자",
	tier = 4,
	rarity = "Legendary",
	family = "Arcane",
	damage = 180,
	attackSpeed = 0.7,
	range = 22,
	attackKind = "Aoe",
	projectileSpeed = 80,
	aoeRadius = 9,
	nextKeys = {},
	fuseCost = 0,
	collectionHint = "아케인 포병 → 광역 분기",
})

-- ============ 분기 B: 연쇄 특화형 ============
def({
	key = "StellarInquisitor",
	name = "별의 심판관",
	tier = 4,
	rarity = "Legendary",
	family = "Arcane",
	damage = 96,
	attackSpeed = 1.15,
	range = 24,
	attackKind = "Chain",
	projectileSpeed = 110,
	chainCount = 6,
	chainFalloff = 0.85,
	nextKeys = {},
	fuseCost = 0,
	collectionHint = "아케인 포병 → 연쇄 분기",
})

return Towers
