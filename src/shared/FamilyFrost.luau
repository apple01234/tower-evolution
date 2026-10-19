--!strict
-- Frost 계열 (제어 특화, 둔화)
local Towers: { [string]: any } = {}

local function def(d: any): any
	Towers[d.key] = d
	return d
end

-- ============ Frost 계열 ============
def({
	key = "FrostShard",
	name = "서리 파편",
	tier = 1,
	rarity = "Common",
	family = "Frost",
	damage = 7,
	attackSpeed = 1.1,
	range = 13,
	attackKind = "Single",
	projectileSpeed = 55,
	slowFactor = 0.88,
	slowDuration = 1.0,
	nextKey = "GlacierSpike",
	fuseCost = 75,
	collectionHint = "무료 계열 루트 (소환)",
})

def({
	key = "GlacierSpike",
	name = "빙하 쐐기",
	tier = 2,
	rarity = "Uncommon",
	family = "Frost",
	damage = 19,
	attackSpeed = 1.25,
	range = 15,
	attackKind = "Pierce",
	projectileSpeed = 65,
	pierceCount = 2,
	slowFactor = 0.8,
	slowDuration = 1.4,
	nextKey = "Permafrost",
	fuseCost = 150,
	collectionHint = "서리 파편 3개 합성",
})

def({
	key = "Permafrost",
	name = "영구 동토",
	tier = 3,
	rarity = "Rare",
	family = "Frost",
	damage = 44,
	attackSpeed = 1.1,
	range = 18,
	attackKind = "Aoe",
	projectileSpeed = 75,
	aoeRadius = 7,
	slowFactor = 0.65,
	slowDuration = 2.0,
	nextKey = "AbsoluteZero",
	fuseCost = 400,
	collectionHint = "빙하 쐐기 3개 합성",
})

def({
	key = "AbsoluteZero",
	name = "절대영도",
	tier = 4,
	rarity = "Legendary",
	family = "Frost",
	damage = 120,
	attackSpeed = 1.0,
	range = 21,
	attackKind = "Aoe",
	projectileSpeed = 70,
	aoeRadius = 11,
	slowFactor = 0.45,
	slowDuration = 3.0,
	nextKey = nil,
	fuseCost = 0,
	collectionHint = "영구 동토 3개 합성",
})

return Towers
