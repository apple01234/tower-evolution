--!strict
-- Inferno 계열: 단일 → 관통 → [분기] 광역 폭발 / 고속 연사
-- 3단계(BlastForge)에서 두 갈래로 나뉜다.
local Towers: { [string]: any } = {}

local function def(d: any): any
	Towers[d.key] = d
	return d
end

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
	nextKeys = { "FlameLance" },
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
	nextKeys = { "BlastForge" },
	fuseCost = 150,
	collectionHint = "잔불 포탑 3개 합성",
})

-- ============ 분기점: 3단계 ============
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
	nextKeys = { "FinalJudgment", "PyreZealot" },
	fuseCost = 400,
	collectionHint = "화염 창 3개 합성 후 진화 방향 선택",
})

-- ============ 분기 A: 초광역 심판 ============
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
	nextKeys = {},
	fuseCost = 0,
	collectionHint = "폭발 용광로 → 초광역 분기",
})

-- ============ 분기 B: 고속 연사 (관통) ============
def({
	key = "PyreZealot",
	name = "화형 광신도",
	tier = 4,
	rarity = "Legendary",
	family = "Inferno",
	damage = 88,
	attackSpeed = 1.4,
	range = 16,
	attackKind = "Pierce",
	projectileSpeed = 130,
	pierceCount = 4,
	nextKeys = {},
	fuseCost = 0,
	collectionHint = "폭발 용광로 → 연사 분기",
})

return Towers
