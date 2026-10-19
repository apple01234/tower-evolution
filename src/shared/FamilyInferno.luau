--!strict
-- Inferno 계열 (고화력 저속)
local Towers: { [string]: any } = {}

local function def(d: any): any
	Towers[d.key] = d
	return d
end

-- ============ Inferno 계열 ============
def({
	key = "EmberTurret",
	name = "잔불 포탑",
	tier = 1,
	rarity = "Common",
	family = "Inferno",
	damage = 14,
	attackSpeed = 0.75,
	range = 12,
	attackKind = "Single",
	projectileSpeed = 50,
	nextKey = "FlameLance",
	fuseCost = 75,
	collectionHint = "무료 계열 루트 (소환)",
})

def({
	key = "FlameLance",
	name = "화염 창",
	tier = 2,
	rarity = "Uncommon",
	family = "Inferno",
	damage = 38,
	attackSpeed = 0.85,
	range = 14,
	attackKind = "Pierce",
	projectileSpeed = 60,
	pierceCount = 2,
	nextKey = "BlastForge",
	fuseCost = 150,
	collectionHint = "잔불 포탑 3개 합성",
})

def({
	key = "BlastForge",
	name = "폭발 용광로",
	tier = 3,
	rarity = "Rare",
	family = "Inferno",
	damage = 95,
	attackSpeed = 0.65,
	range = 17,
	attackKind = "Aoe",
	projectileSpeed = 65,
	aoeRadius = 8,
	nextKey = "FinalJudgment",
	fuseCost = 400,
	collectionHint = "화염 창 3개 합성",
})

def({
	key = "FinalJudgment",
	name = "최종 심판",
	tier = 4,
	rarity = "Legendary",
	family = "Inferno",
	damage = 280,
	attackSpeed = 0.5,
	range = 20,
	attackKind = "Aoe",
	projectileSpeed = 60,
	aoeRadius = 10,
	nextKey = nil,
	fuseCost = 0,
	collectionHint = "폭발 용광로 3개 합성",
})

return Towers
