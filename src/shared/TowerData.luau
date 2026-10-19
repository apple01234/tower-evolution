--!strict
-- 타워 진화 트리 접근자. 실제 정의는 Family*.luau 에 있다.
-- 새 타워는 계열 파일에만 추가하면 되고, 전투 코드는 key 기반으로 동작한다.
--
-- 분기 진화: 한 타워가 nextKeys 로 여러 상위 타워를 가질 수 있다.
--   nextKeys 가 1개  → 자동 진행 (기존 동작)
--   nextKeys 가 2개+ → 플레이어가 선택 (RequestFuse 에 선택 키 전달)

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
	-- 하위 호환: 단일 경로. nextKeys 가 있으면 그쪽을 우선한다.
	nextKey: string?,
	-- 분기 진화 경로 (0개=최종, 1개=자동, 2개+=선택)
	nextKeys: { string }?,
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

-- 진화 가능한 상위 타워 목록 (분기 포함). 최종 단계면 빈 배열.
function TowerData.nextOptions(key: string): { string }
	local d = Towers[key]
	if not d then
		return {}
	end
	if d.nextKeys and #d.nextKeys > 0 then
		local out = {}
		for _, k in d.nextKeys do
			if Towers[k] then
				table.insert(out, k)
			end
		end
		return out
	end
	if d.nextKey and Towers[d.nextKey] then
		return { d.nextKey }
	end
	return {}
end

-- 경로가 2개 이상이면 플레이어 선택이 필요하다
function TowerData.requiresChoice(key: string): boolean
	return #TowerData.nextOptions(key) >= 2
end

-- 합성 결과. chosen 이 주어지면 그 경로를 검증해 반환한다.
-- chosen 이 없으면: 경로 1개일 때만 자동 반환, 2개 이상이면 nil (선택 필요).
function TowerData.fuseResult(key: string, chosen: string?): string?
	local options = TowerData.nextOptions(key)
	if #options == 0 then
		return nil
	end
	if chosen then
		for _, k in options do
			if k == chosen then
				return k
			end
		end
		return nil -- 허용되지 않은 경로
	end
	if #options == 1 then
		return options[1]
	end
	return nil
end

-- 진화 체인 (첫 경로 기준, 도감 요약용)
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
		local opts = TowerData.nextOptions(cur)
		cur = #opts > 0 and opts[1] or nil
		guard += 1
	end
	return out
end

-- 분기 트리 전체 (BFS). UI 트리 표시에 사용.
function TowerData.subtree(key: string): { TowerDef }
	local seen: { [string]: boolean } = {}
	local out: { TowerDef } = {}
	local queue = { key }
	while #queue > 0 do
		local cur = table.remove(queue, 1)
		if not seen[cur] and Towers[cur] then
			seen[cur] = true
			table.insert(out, Towers[cur])
			for _, nxt in TowerData.nextOptions(cur) do
				table.insert(queue, nxt)
			end
		end
	end
	return out
end

-- 전체 타워 (계열 → 단계 → key 순)
function TowerData.all(): { TowerDef }
	local out = {}
	for _, d in Towers do
		table.insert(out, d)
	end
	table.sort(out, function(a, b)
		if a.family ~= b.family then
			return a.family < b.family
		end
		if a.tier ~= b.tier then
			return a.tier < b.tier
		end
		return a.key < b.key
	end)
	return out
end

-- 특정 계열의 모든 타워 (분기 포함)
function TowerData.familyChain(family: string): { TowerDef }
	local root = Defs.FAMILY_ROOTS[family]
	if not root then
		return {}
	end
	return TowerData.subtree(root)
end

-- 계열 통계 (UI/밸런스 확인용)
function TowerData.familySummary(): { [string]: any }
	local out = {}
	for _, fam in TowerData.FAMILY_KEYS do
		local nodes = TowerData.familyChain(fam)
		if #nodes > 0 then
			local finals, maxTier, maxDps = 0, 0, 0
			for _, d in nodes do
				if #TowerData.nextOptions(d.key) == 0 then
					finals += 1
				end
				maxTier = math.max(maxTier, d.tier)
				maxDps = math.max(maxDps, d.damage * d.attackSpeed)
			end
			out[fam] = {
				root = Defs.FAMILY_ROOTS[fam],
				nodes = #nodes,
				finals = finals,
				maxTier = maxTier,
				maxDps = maxDps,
			}
		end
	end
	return out
end

return TowerData
