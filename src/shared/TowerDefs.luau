--!strict
-- 타워 데이터 조립자 (3계열 × 4단계 = 12종).
-- 실제 정의는 FamilyArcane / FamilyFrost / FamilyInferno 에 있다.
-- 계열별 정체성:
--   Arcane  : 단일 → 관통 → 연쇄 → 광역 (범용 화력)
--   Frost   : 단일 → 관통(둔화) → 광역 빙결 → 절대영도 (제어)
--   Inferno : 단일 → 관통 → 폭발 → 심판 (고화력 저속)

export type AttackKind = "Single" | "Pierce" | "Chain" | "Aoe"

export type TowerDef = {
	key: string,
	name: string,
	tier: number,
	rarity: string,
	family: string,
	damage: number,
	attackSpeed: number,
	range: number,
	attackKind: AttackKind,
	projectileSpeed: number,
	pierceCount: number?,
	chainCount: number?,
	chainFalloff: number?,
	aoeRadius: number?,
	slowFactor: number?,
	slowDuration: number?,
	nextKey: string?,
	fuseCost: number,
	collectionHint: string,
}

-- Roblox: script.Parent, Lune: 파일 경로 (양쪽 호환)
local function load(name: string): any
	if script then
		return require(script.Parent:WaitForChild(name))
	end
	return require("./" .. name)
end

local FAMILY_ROOTS = {
	Arcane = "ApprenticeTurret",
	Frost = "FrostShard",
	Inferno = "EmberTurret",
}

local FAMILY_KEYS = { "Arcane", "Frost", "Inferno" }

local SOURCES = {
	Arcane = "FamilyArcane",
	Frost = "FamilyFrost",
	Inferno = "FamilyInferno",
}

-- 계열 파일들을 하나의 테이블로 병합
local Towers: { [string]: TowerDef } = {}
for _, fam in FAMILY_KEYS do
	for key, d in load(SOURCES[fam]) do
		if Towers[key] then
			warn(string.format("[TowerDefs] 중복 타워 키: %s", key))
		end
		Towers[key] = d
	end
end

return {
	Towers = Towers,
	FAMILY_ROOTS = FAMILY_ROOTS,
	FAMILY_KEYS = FAMILY_KEYS,
}
