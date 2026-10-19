--!strict
-- 인벤토리 및 합성 규칙. 순수 로직만 담아 Lune으로 검증 가능하게 한다.
-- 서버는 이 모듈의 반환값만 신뢰한다. 클라이언트는 요청만 보낸다.

local Inventory = {}

export type Slot = {
	uid: string,
	key: string,
	level: number,
}

export type State = {
	gold: number,
	slots: { Slot },
	nextUid: number,
}

Inventory.Result = nil :: any

function Inventory.new(gold: number): State
	return {
		gold = gold,
		slots = {},
		nextUid = 1,
	}
end

function Inventory.count(state: State): number
	return #state.slots
end

function Inventory.countKey(state: State, key: string): number
	local n = 0
	for _, s in state.slots do
		if s.key == key then
			n += 1
		end
	end
	return n
end

function Inventory.add(state: State, key: string, level: number?): Slot
	local uid = "u" .. tostring(state.nextUid)
	state.nextUid += 1
	local slot: Slot = {
		uid = uid,
		key = key,
		level = level or 1,
	}
	table.insert(state.slots, slot)
	return slot
end

function Inventory.removeUid(state: State, uid: string): boolean
	for i, s in state.slots do
		if s.uid == uid then
			table.remove(state.slots, i)
			return true
		end
	end
	return false
end

export type FuseRequest = {
	uids: { string },
}

export type FuseResult = {
	ok: boolean,
	err: string?,
	spent: { Slot }?,
	gained: Slot?,
	goldSpent: number?,
}

-- 합성 규칙 검증 + 실행. 실패 시 상태를 절대 변경하지 않는다(원자성).
function Inventory.fuse(state: State, req: FuseRequest, fuseCost: number, cap: number): FuseResult
	local uids = req.uids

	-- 1) 입력 형태 검증
	if type(uids) ~= "table" or #uids ~= 3 then
		return { ok = false, err = "INVALID_INPUT" }
	end

	-- 2) 중복 uid 검증 (같은 타워 3번 세는 어뷰징 차단)
	local seen: { [string]: boolean } = {}
	for _, uid in uids do
		if type(uid) ~= "string" then
			return { ok = false, err = "INVALID_INPUT" }
		end
		if seen[uid] then
			return { ok = false, err = "DUPLICATE_UID" }
		end
		seen[uid] = true
	end

	-- 3) 실제 소유 확인
	local found: { Slot } = {}
	for _, uid in uids do
		local slot: Slot? = nil
		for _, s in state.slots do
			if s.uid == uid then
				slot = s
				break
			end
		end
		if not slot then
			return { ok = false, err = "NOT_OWNED" }
		end
		table.insert(found, slot)
	end

	-- 4) 동일 key 검증
	local key = found[1].key
	for i = 2, 3 do
		if found[i].key ~= key then
			return { ok = false, err = "DIFFERENT_TOWER" }
		end
	end

	-- 5) 인벤토리 여유 검증 (3개 빠지고 1개 들어오므로 순감이지만 방어적으로 확인)
	if #state.slots - 3 + 1 > cap then
		return { ok = false, err = "INVENTORY_FULL" }
	end

	-- 6) 골드 검증
	if fuseCost > 0 and state.gold < fuseCost then
		return { ok = false, err = "NOT_ENOUGH_GOLD" }
	end

	-- 7) 진화 경로 존재 확인은 호출자가 넘긴 nextKeyResolver로 한다
	--    (여기서는 key만 돌려주고, 생성은 호출자가 결정)
	return {
		ok = true,
		spent = found,
		goldSpent = fuseCost,
	}
end

-- 검증 통과 후 실제 커밋. 반드시 fuse()가 ok=true일 때만 호출한다.
function Inventory.commitFuse(state: State, result: FuseResult, nextKey: string, cap: number): boolean
	if not result.ok or not result.spent then
		return false
	end
	-- 재검증: 그 사이 사라졌을 수 있음
	local present = 0
	for _, s in result.spent do
		for _, cur in state.slots do
			if cur.uid == s.uid then
				present += 1
				break
			end
		end
	end
	if present ~= 3 then
		return false
	end
	if #state.slots - 3 + 1 > cap then
		return false
	end
	if (result.goldSpent or 0) > state.gold then
		return false
	end

	-- 차감
	for _, s in result.spent do
		Inventory.removeUid(state, s.uid)
	end
	if (result.goldSpent or 0) > 0 then
		state.gold -= result.goldSpent or 0
	end
	-- 지급
	return true
end

return Inventory
