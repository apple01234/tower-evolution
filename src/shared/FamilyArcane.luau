--!strict
-- Arcane 계열 (단일→관통→연쇄→광역)
local Towers: { [string]: any } = {}

local function def(d: any): any
	Towers[d.key] = d
	return d
end

-- ============ Arcane 계열 ============
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
	nextKey = "CrystalTurret",
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
	nextKey = "ArcaneArtillery",
	fuseCost = 150,
	collectionHint = "견습 포탑 3개 합성",
})

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
	nextKey = "AstralSovereign",
	fuseCost = 400,
	collectionHint = "수정 포탑 3개 합성",
})

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
	nextKey = nil,
	fuseCost = 0,
	collectionHint = "아케인 포병 3개 합성",
})

return Towers
