--!strict
-- 에셋 카탈로그: 마켓플레이스 무료 모델 (AssetTypeId=10, IsPublicDomain=true)
-- 모든 ID는 economy/v2/assets/{id}/details 로 검증된 것만 등록한다.
-- TowerData / Lore 의 키와 1:1 대응.

local AssetCatalog = {}

AssetCatalog.CATALOG = {
	-- ============ Arcane 계열 ============
	ApprenticeTurret = { id = 8957759081, label = "Turrets and Cannons" },
	CrystalTurret = { id = 5131549882, label = "Crystal Tower" },
	ArcaneArtillery = { id = 10813822708, label = "Artillery Cannon" },
	AstralSovereign = { id = 8801736674, label = "Old astral tower" },
	StellarInquisitor = { id = 2156035002, label = "Sci-Fi Tower" },

	-- ============ Frost 계열 ============
	FrostShard = { id = 399646012, label = "ice shard" },
	GlacierSpike = { id = 1719243153, label = "ice spikes" },
	Permafrost = { id = 1311148459, label = "FROZEN TOWER" },
	AbsoluteZero = { id = 185696510, label = "Frozen Castle" },
	CryoWarden = { id = 4612459935, label = "Ice Guardian" },

	-- ============ Inferno 계열 ============
	EmberTurret = { id = 80844193826300, label = "Campfire Bonfire" },
	FlameLance = { id = 1652707728, label = "torch/flame" },
	BlastForge = { id = 232016503, label = "blacksmith forge" },
	FinalJudgment = { id = 10434207174, label = "Lava Tower" },
	PyreZealot = { id = 76832029, label = "Statue Wielding Fire" },

	-- ============ 적 ============
	enemy = { id = 15115599443, label = "Slime Monster" },
	enemy_alt = { id = 7985172146, label = "Skeleton Warrior" },
	enemy_fast = { id = 15211332631, label = "Slime Monster Goo" },

	-- ============ 환경 / 장식 ============
	env_tower = { id = 277678404, label = "City Tower Building" },
	env_tree = { id = 12549617200, label = "Low Poly Tree" },
	env_rock = { id = 7299047040, label = "Low Poly Rock" },
	env_crystal = { id = 157006174, label = "Crystal Cluster Mesh" },
	env_castle = { id = 138140282688443, label = "Medieval House With Tower" },

	-- ============ 보스 ============
	boss_dragon = { id = 9158540450, label = "Dragon sculpture (low poly)" },
	boss_dragon_alt = { id = 9158526606, label = "Dragon sculpture (low poly)" },
}

-- 타워 키 → 에셋 키 매핑 (TowerDefs 의 key 를 그대로 쓴다)
AssetCatalog.TOWER_KEYS = {
	ApprenticeTurret = true,
	CrystalTurret = true,
	ArcaneArtillery = true,
	AstralSovereign = true,
	StellarInquisitor = true,
	FrostShard = true,
	GlacierSpike = true,
	Permafrost = true,
	AbsoluteZero = true,
	CryoWarden = true,
	EmberTurret = true,
	FlameLance = true,
	BlastForge = true,
	FinalJudgment = true,
	PyreZealot = true,
}

function AssetCatalog.get(key: string): any
	return AssetCatalog.CATALOG[key]
end

function AssetCatalog.has(key: string): boolean
	return AssetCatalog.CATALOG[key] ~= nil
end

-- 전체 키 목록 (진단용)
function AssetCatalog.allKeys(): { string }
	local out = {}
	for k in AssetCatalog.CATALOG do
		table.insert(out, k)
	end
	table.sort(out)
	return out
end

return AssetCatalog
