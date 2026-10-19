--!strict
-- 협동 보스: 여러 플레이어의 피해를 하나의 HP로 집계한다.
-- Roblox API 무의존 (순수 로직) → Lune 검증 가능.
--
-- 설계 원칙:
--   - 보스 HP는 전역 1개. 참가자 전원이 같은 값을 본다.
--   - 피해 기여도를 참가자별로 누적해 보상 차등에 쓴다 (기여도 없으면 보상 없음).
--   - 막타 보너스는 마지막으로 피해를 준 사람에게만.
--   - 보스가 죽으면 상태를 즉시 종료해 중복 보상 지급을 막는다.

local CoopBoss = {}

export type Participant = {
	userId: number,
	damage: number,
	lastHitAt: number,
}

export type Boss = {
	key: string,
	name: string,
	maxHp: number,
	hp: number,
	active: boolean,
	startedAt: number,
	participants: { [number]: Participant },
	lastHitUserId: number?,
}

-- 보상 비율: 기여도 비례 + 막타 보너스
CoopBoss.LAST_HIT_BONUS = 0.15 -- 전체 보상 풀의 15%
CoopBoss.MIN_SHARE = 0.05 -- 참여만 해도 최소 5%

-- 보스 생성
function CoopBoss.new(key: string, name: string, hp: number, now: number): Boss
	return {
		key = key,
		name = name,
		maxHp = math.max(1, math.floor(hp)),
		hp = math.max(1, math.floor(hp)),
		active = true,
		startedAt = now,
		participants = {},
		lastHitUserId = nil,
	}
end

-- 피해 적용. 이미 종료된 보스면 0 반환 (중복 보상 차단).
function CoopBoss.applyDamage(boss: Boss, userId: number, damage: number, now: number): number
	if not boss.active then
		return 0
	end
	if damage <= 0 then
		return 0
	end

	-- 실제로 들어간 피해만 집계 (오버킬 제외)
	local applied = math.min(math.floor(damage), boss.hp)
	if applied <= 0 then
		return 0
	end

	boss.hp -= applied
	boss.lastHitUserId = userId

	local p = boss.participants[userId]
	if not p then
		p = { userId = userId, damage = 0, lastHitAt = now }
		boss.participants[userId] = p
	end
	p.damage += applied
	p.lastHitAt = now

	if boss.hp <= 0 then
		boss.hp = 0
		boss.active = false
	end

	return applied
end

function CoopBoss.isDead(boss: Boss): boolean
	return not boss.active and boss.hp <= 0
end

-- 총 피해량 (기여도 합계)
function CoopBoss.totalDamage(boss: Boss): number
	local total = 0
	for _, p in boss.participants do
		total += p.damage
	end
	return total
end

-- 참가자 수
function CoopBoss.participantCount(boss: Boss): number
	local n = 0
	for _ in boss.participants do
		n += 1
	end
	return n
end

-- 기여도 순위 (내림차순)
function CoopBoss.ranking(boss: Boss): { Participant }
	local list = {}
	for _, p in boss.participants do
		table.insert(list, p)
	end
	table.sort(list, function(a, b)
		if a.damage ~= b.damage then
			return a.damage > b.damage
		end
		return a.userId < b.userId -- 동점 시 결정론적 정렬
	end)
	return list
end

-- 보상 분배. totalReward 를 기여도 비례로 나누고 막타 보너스를 얹는다.
-- 반환: { [userId] = reward }
function CoopBoss.distribute(boss: Boss, totalReward: number): { [number]: number }
	local out: { [number]: number } = {}
	local total = CoopBoss.totalDamage(boss)
	local count = CoopBoss.participantCount(boss)

	if count == 0 or total <= 0 then
		return out
	end

	local pool = math.max(0, math.floor(totalReward))
	if pool <= 0 then
		return out
	end

	-- 막타 보너스분 분리
	local lastUserId = boss.lastHitUserId
	local bonus = 0
	if lastUserId and boss.participants[lastUserId] and count > 1 then
		bonus = math.floor(pool * CoopBoss.LAST_HIT_BONUS)
	end
	local share = pool - bonus

	-- 기여도 비례 분배 (내림)
	local given = 0
	for _, p in boss.participants do
		local amount = math.floor(share * (p.damage / total))
		out[p.userId] = (out[p.userId] or 0) + amount
		given += amount
	end

	-- 최소 보장: 남은 예산 안에서만 지급한다.
	-- (핵심: 최소 보장 때문에 총액을 넘으면 안 된다 — 경제 파괴 방지)
	local minAmount = math.floor(pool * CoopBoss.MIN_SHARE)
	local budget = pool - bonus - given
	-- 부족한 참가자를 금액 오름차순으로 처리해 예산 소진을 고르게
	local needy = {}
	for _, p in boss.participants do
		local cur = out[p.userId] or 0
		if cur < minAmount then
			table.insert(needy, { userId = p.userId, cur = cur })
		end
	end
	table.sort(needy, function(a, b)
		return a.cur < b.cur
	end)

	for _, n in needy do
		local need = minAmount - n.cur
		if budget <= 0 then
			break
		end
		local pay = math.min(need, budget)
		out[n.userId] = n.cur + pay
		given += pay
		budget -= pay
	end

	-- 막타 보너스 (분리해 둔 몫)
	if bonus > 0 and lastUserId then
		out[lastUserId] = (out[lastUserId] or 0) + bonus
		given += bonus
	end

	-- 반올림 잔여를 1위에게 (총액 절대 초과 금지)
	local leftover = pool - given
	if leftover > 0 then
		local top = CoopBoss.ranking(boss)[1]
		if top then
			out[top.userId] = (out[top.userId] or 0) + leftover
		end
	end

	return out
end

-- 보스 진행률 (0..1, UI 바 표시용)
function CoopBoss.progress(boss: Boss): number
	if boss.maxHp <= 0 then
		return 0
	end
	return math.clamp((boss.maxHp - boss.hp) / boss.maxHp, 0, 1)
end

-- 만료 판정 (참가자가 아무도 피해를 주지 않은 채 timeout 초과)
function CoopBoss.isExpired(boss: Boss, now: number, timeout: number): boolean
	if not boss.active then
		return true
	end
	return (now - boss.startedAt) > timeout
end

return CoopBoss
