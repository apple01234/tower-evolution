--!strict
-- 에셋 카탈로그 (25종) — 썸네일 API로 전부 state=Completed 검증 완료.
--
-- 검증 방법:
--   https://thumbnails.roblox.com/v1/assets?assetIds={id}&size=420x420
--   → state == "Completed" 이면 에셋이 존재하고 렌더 가능
--
-- 주의: 모델 원본(.rbxm) 파일 다운로드는 Roblox 계정 세션이 필요하다.
--   assetdelivery 는 무료 공개 에셋에도 401 "Authentication required" 를 반환한다.
--   HTTP 허용과 무관한 인증 문제이므로, 런타임 InsertService:LoadAsset 만이 공식 경로.
--
-- TowerData / Lore 의 키와 1:1 대응.

local AssetCatalog = {}

AssetCatalog.CATALOG = {
	-- ============ Arcane 계열 ============
	ApprenticeTurret = { id = 8957759081, label = "Turrets and Cannons", tier = 1 },
	CrystalTurret = { id = 5131549882, label = "Crystal Tower", tier = 2 },
	ArcaneArtillery = { id = 10813822708, label = "Artillery Cannon", tier = 3 },
	AstralSovereign = { id = 8801736674, label = "Old astral tower", tier = 4 },
	StellarInquisitor = { id = 2156035002, label = "Sci-Fi Tower", tier = 4 },

	-- ============ Frost 계열 ============
	FrostShard = { id = 399646012, label = "ice shard", tier = 1 },
	GlacierSpike = { id = 1719243153, label = "ice spikes", tier = 2 },
	Permafrost = { id = 1311148459, label = "FROZEN TOWER", tier = 3 },
	AbsoluteZero = { id = 185696510, label = "Frozen Castle", tier = 4 },
	CryoWarden = { id = 4612459935, label = "Ice Guardian", tier = 4 },

	-- ============ Inferno 계열 ============
	EmberTurret = { id = 80844193826300, label = "Campfire Bonfire", tier = 1 },
	FlameLance = { id = 1652707728, label = "torch/flame", tier = 2 },
	BlastForge = { id = 232016503, label = "blacksmith forge", tier = 3 },
	FinalJudgment = { id = 10434207174, label = "Lava Tower", tier = 4 },
	PyreZealot = { id = 76832029, label = "Statue Wielding Fire", tier = 4 },

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

-- 타워 키 매핑 (TowerDefs 의 key 를 그대로 쓴다)
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

function AssetCatalog.allKeys(): { string }
	local out = {}
	for k in AssetCatalog.CATALOG do
		table.insert(out, k)
	end
	table.sort(out)
	return out
end

-- 썸네일 조회 URL (Studio 미리보기 / 외부 검증용)
function AssetCatalog.thumbnailUrl(assetId: number, size: number?): string
	local s = size or 420
	return string.format(
		"https://thumbnails.roblox.com/v1/assets?assetIds=%d&size=%dx%d&format=Png",
		assetId, s, s
	)
end

return AssetCatalog
