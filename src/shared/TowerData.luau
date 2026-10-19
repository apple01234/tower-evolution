--!strict
-- 타워 진화 트리 접근자. 실제 정의는 TowerDefs.luau.
-- 새 타워는 TowerDefs.luau 에만 추가하면 되고, 전투 코드는 key 기반으로 동작한다.

-- Roblox: script.Parent, Lune: 파일 경로 (양쪽 호환)
local Defs
if script then
	Defs = require(script.Parent:WaitForChild("TowerDefs"))
else
	Defs = require("./TowerDefs")
end

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

local Towers: { [string]: TowerDef } = Defs.Towers
local TowerData = {}

TowerData.DEFS = Towers
TowerData.ROOT_KEY = "ApprenticeTurret"
TowerData.FAMILY_KEYS = Defs.FAMILY_KEYS
TowerData.FAMILY_ROOTS = Defs.FAMILY_ROOTS

function TowerData.get(key: string): TowerDef?
	return Towers[key]
end

function TowerData.exists(key: string): boolean
	return Towers[key] ~= nil
end

-- 합성 결과: 같은 key 3개 → nextKey 1개
function TowerData.fuseResult(key: string): string?
	local d = Towers[key]
	return d and d.nextKey or nil
end

-- 진화 체인 (도감 표시용)
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

-- 전체 타워 (계열 → 단계 순)
function TowerData.all(): { TowerDef }
	local out = {}
	for _, d in Towers do
		table.insert(out, d)
	end
	table.sort(out, function(a, b)
		if a.family ~= b.family then
			return a.family < b.family
		end
		return a.tier < b.tier
	end)
	return out
end

-- 특정 계열의 진화 체인
function TowerData.familyChain(family: string): { TowerDef }
	local root = Defs.FAMILY_ROOTS[family]
	if not root then
		return {}
	end
	return TowerData.chain(root)
end

-- 계열 통계 (UI/밸런스 확인용)
function TowerData.familySummary(): { [string]: any }
	local out = {}
	for _, fam in TowerData.FAMILY_KEYS do
		local chain = TowerData.familyChain(fam)
		if #chain > 0 then
			local last = chain[#chain]
			out[fam] = {
				root = chain[1].key,
				final = last.key,
				finalName = last.name,
				tiers = #chain,
				finalDps = last.damage * last.attackSpeed,
			}
		end
	end
	return out
end

return TowerData
