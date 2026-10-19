--!strict
-- 순수 전투 계산 로직. Roblox API에 의존하지 않으므로 Lune으로 직접 검증 가능.
-- 서버는 이 모듈의 결과만 신뢰하고, 클라이언트 계산값은 절대 사용하지 않는다.

local Combat = {}

export type Enemy = {
	id: number,
	hp: number,
	maxHp: number,
	pos: number, -- 경로상 진행도 (0..1 아님, 월드 거리 기반 누적)
	alive: boolean,
	reward: number,
	isBoss: boolean,
}

export type Hit = {
	enemyId: number,
	damage: number,
}

-- 체력 스케일: 웨이브가 오를수록 강해진다
function Combat.enemyHp(wave: number, hpBase: number, hpGrowth: number): number
	local w = math.max(1, math.floor(wave))
	return math.floor(hpBase * (hpGrowth ^ (w - 1)))
end

function Combat.enemyReward(hp: number): number
	-- 처치 보상은 체력에 비례하되 최소 1
	return math.max(1, math.floor(hp * 0.15))
end

function Combat.isBossWave(wave: number, bossEvery: number): boolean
	return wave > 0 and wave % bossEvery == 0
end

-- 타워 공격 1회의 피해 목록을 계산한다.
-- enemies: 거리순으로 정렬되지 않아도 되며, range 내 대상만 고려한다.
-- distanceOf: enemy -> 타워로부터의 거리
function Combat.computeHits(
	towerDef: { damage: number, attackKind: string, range: number, pierceCount: number?, chainCount: number?, chainFalloff: number?, aoeRadius: number? },
	enemies: { Enemy },
	distanceOf: (Enemy) -> number,
	nearestPairDistance: ((Enemy, Enemy) -> number)?
): { Hit }
	local hits: { Hit } = {}

	-- 사거리 내 생존 적 수집
	local inRange: { Enemy } = {}
	for _, e in enemies do
		if e.alive and distanceOf(e) <= towerDef.range then
			table.insert(inRange, e)
		end
	end
	if #inRange == 0 then
		return hits
	end

	-- 가장 가까운 적을 1차 대상으로
	table.sort(inRange, function(a, b)
		return distanceOf(a) < distanceOf(b)
	end)

	local primary = inRange[1]
	local kind = towerDef.attackKind

	if kind == "Single" then
		table.insert(hits, { enemyId = primary.id, damage = towerDef.damage })
	elseif kind == "Pierce" then
		local n = math.min(towerDef.pierceCount or 1, #inRange)
		for i = 1, n do
			table.insert(hits, { enemyId = inRange[i].id, damage = towerDef.damage })
		end
	elseif kind == "Chain" then
		-- 1차 대상에서 가장 가까운 적으로 연쇄, 매 연쇄마다 피해 감소
		local maxChain = math.min(towerDef.chainCount or 1, #inRange)
		local falloff = towerDef.chainFalloff or 1
		local hitSet: { [number]: boolean } = {}
		local current = primary
		local dmg = towerDef.damage
		for _ = 1, maxChain do
			if hitSet[current.id] then
				break
			end
			hitSet[current.id] = true
			table.insert(hits, { enemyId = current.id, damage = dmg })
			dmg = dmg * falloff
			-- 다음 대상: 아직 안 맞은 것 중 현재와 가장 가까운 적
			local best: Enemy? = nil
			local bestDist = math.huge
			for _, e in inRange do
				if not hitSet[e.id] and nearestPairDistance then
					local d = nearestPairDistance(current, e)
					if d < bestDist then
						bestDist = d
						best = e
					end
				end
			end
			if not best then
				break
			end
			current = best
		end
	elseif kind == "Aoe" then
		-- 1차 대상 위치 기준 광역
		local radius = towerDef.aoeRadius or 0
		local origin = primary.pos
		for _, e in inRange do
			if math.abs(e.pos - origin) <= radius then
				table.insert(hits, { enemyId = e.id, damage = towerDef.damage })
			end
		end
		if #hits == 0 then
			table.insert(hits, { enemyId = primary.id, damage = towerDef.damage })
		end
	end

	return hits
end

-- 피해 적용. 이미 죽은 적은 무시하고, 사망한 적 목록을 반환한다.
-- 보상 중복 지급 방지를 위해 alive 플래그를 즉시 내린다.
function Combat.applyHits(enemies: { [number]: Enemy }, hits: { Hit }): ({ Enemy }, number)
	local killed: { Enemy } = {}
	local totalDamage = 0
	for _, h in hits do
		local e = enemies[h.enemyId]
		if e and e.alive then
			e.hp -= h.damage
			totalDamage += h.damage
			if e.hp <= 0 then
				e.hp = 0
				e.alive = false -- 중복 보상 방지의 핵심
				table.insert(killed, e)
			end
		end
	end
	return killed, totalDamage
end

return Combat
