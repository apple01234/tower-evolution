--!strict
-- 인벤토리 관련 요청 핸들러 (소환/합성/배치/회수)
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Inventory = require(Shared:WaitForChild("Inventory"))
local Missions = require(Shared:WaitForChild("Missions"))
local Progress = require(Shared:WaitForChild("Progress"))
local TowerData = require(Shared:WaitForChild("TowerData"))

local TowerModel = require(script.Parent:WaitForChild("TowerModel"))
local Save = require(script.Parent:WaitForChild("Save"))
local State = require(script.Parent:WaitForChild("BattleState"))
local WorldSetup = require(script.Parent:WaitForChild("WorldSetup"))

local Handlers = {}

-- 공용 유틸은 Battle에서 주입
local allow: (Player, string) -> boolean = function()
	return false
end
local notifyMission: (Player, { string }) -> () = function() end

function Handlers.inject(opts: { allow: any, notifyMission: any })
	allow = opts.allow
	notifyMission = opts.notifyMission
end

local function pushState(player: Player, st: any)
	local events = State.events
	if events then
		events.StateSync:FireClient(player, { gold = st.gold, slots = st.slots, wave = State.wave })
	end
end

local function notify(player: Player, msg: string, kind: string)
	local events = State.events
	if events then
		events.Notify:FireClient(player, msg, kind)
	end
end

-- ============ 소환 ============
function Handlers.summon(player: Player)
	if not allow(player, "SUMMON") then
		return
	end
	local st = Save.get(player)
	if not st then
		return
	end
	local ps = Save.ensureProgress(player)
	local baseCost = Config.SUMMON_COST_BASE * (Config.SUMMON_COST_GROWTH ^ (#st.slots))
	local cost = math.floor(baseCost * Progress.summonCostMultiplier(ps))

	if st.gold < cost then
		notify(player, "골드가 부족합니다.", "bad")
		return
	end
	if #st.slots >= Config.INVENTORY_CAP then
		notify(player, "인벤토리가 가득 찼습니다.", "bad")
		return
	end

	st.gold -= cost
	local slot = Inventory.add(st, "ApprenticeTurret")
	local ms = Save.ensureMissions(player)
	notifyMission(player, Missions.record(ms, "summon", 1))

	pushState(player, st)
	local def = TowerData.get(slot.key)
	notify(player, "타워 소환: " .. (def and def.name or slot.key), "good")
end

-- ============ 합성 ============
local function firstKeyOf(st: any, uids: { string }): string?
	for _, uid in uids do
		for _, s in st.slots do
			if s.uid == uid then
				return s.key
			end
		end
	end
	return nil
end

function Handlers.fuse(player: Player, uids: any)
	if not allow(player, "FUSE") then
		return
	end
	if type(uids) ~= "table" then
		return
	end
	local st = Save.get(player)
	if not st then
		return
	end

	local firstKey = firstKeyOf(st, uids)
	local def = firstKey and TowerData.get(firstKey) or nil
	local fuseCost = def and def.fuseCost or 0

	local result = Inventory.fuse(st, { uids = uids }, fuseCost, Config.INVENTORY_CAP)
	if not result.ok then
		notify(player, "합성 실패: " .. tostring(result.err), "bad")
		return
	end

	local nextKey = firstKey and TowerData.fuseResult(firstKey) or nil
	if not nextKey then
		notify(player, "더 이상 진화할 수 없습니다.", "bad")
		return
	end
	if not Inventory.commitFuse(st, result, nextKey, Config.INVENTORY_CAP) then
		notify(player, "합성 처리 중 오류.", "bad")
		return
	end

	Inventory.add(st, nextKey)
	local ps = Save.ensureProgress(player)
	local nd = TowerData.get(nextKey)
	if Progress.unlockCollect(ps, nextKey) then
		notify(player, "도감 등록: " .. (nd and nd.name or nextKey), "good")
	end

	local ms = Save.ensureMissions(player)
	notifyMission(player, Missions.record(ms, "fuse", 1))

	pushState(player, st)
	notify(player, "진화 성공: " .. (nd and nd.name or nextKey), "good")
end

function Handlers.place(player: Player, uid: any, col: any, row: any)
	if not allow(player, "PLACE") then
		return
	end
	if type(uid) ~= "string" or type(col) ~= "number" or type(row) ~= "number" then
		return
	end
	if col < 0 or col >= Config.GRID_COLS or row < 0 or row >= Config.GRID_ROWS then
		return
	end

	local st = Save.get(player)
	if not st then
		return
	end

	local owned = nil
	for _, s in st.slots do
		if s.uid == uid then
			owned = s
			break
		end
	end
	if not owned then
		return
	end

	State.placed[player.UserId] = State.placed[player.UserId] or {}
	local ck = State.cellKey(col, row) .. "@" .. tostring(player.UserId)
	if State.placed[player.UserId][ck] then
		notify(player, "이미 타워가 있습니다.", "bad")
		return
	end

	local def = TowerData.get(owned.key)
	if not def then
		return
	end

	local wp = WorldSetup.cellToWorld(col, row)
	local model, towerPos = TowerModel.build(owned.key, wp)

	State.placed[player.UserId][ck] = {
		uid = uid,
		key = owned.key,
		cooldown = 0,
		model = model,
		pos = towerPos,
	}
	Inventory.removeUid(st, uid)
	pushState(player, st)
	notify(player, def.name .. " 배치 완료", "good")
end

-- ============ 회수 ============
function Handlers.sell(player: Player, uid: any)
	if not allow(player, "PLACE") then
		return
	end
	local st = Save.get(player)
	if not st then
		return
	end
	local cells = State.placed[player.UserId]
	if not cells then
		return
	end

	for ck, t in cells do
		if t.uid == uid then
			if t.model then
				t.model:Destroy()
			end
			cells[ck] = nil
			Inventory.add(st, t.key)
			local d = TowerData.get(t.key)
			pushState(player, st)
			notify(player, (d and d.name or t.key) .. " 회수", "info")
			return
		end
	end
end

function Handlers.upgrade(player: Player, _uid: any)
	if not allow(player, "UPGRADE") then
		return
	end
	notify(player, "업그레이드는 준비 중입니다.", "info")
end

return Handlers
