--!strict
-- 성장 관련 요청 핸들러 (환생 / 연구 / 지역 / 미션 수령)
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Inventory = require(Shared:WaitForChild("Inventory"))
local Lore = require(Shared:WaitForChild("Lore"))
local Missions = require(Shared:WaitForChild("Missions"))
local Progress = require(Shared:WaitForChild("Progress"))

local EnemyManager = require(script.Parent:WaitForChild("EnemyManager"))
local WorldSetup = require(script.Parent:WaitForChild("WorldSetup"))
local Save = require(script.Parent:WaitForChild("Save"))
local State = require(script.Parent:WaitForChild("BattleState"))

local Growth = {}

local allow: (Player, string) -> boolean = function()
	return false
end

function Growth.inject(opts: { allow: any })
	allow = opts.allow
end

local function notify(player: Player, msg: string, kind: string)
	local events = State.events
	if events then
		events.Notify:FireClient(player, msg, kind)
	end
end

local function pushState(player: Player, st: any, wave: number)
	local events = State.events
	if events then
		events.StateSync:FireClient(player, { gold = st.gold, slots = st.slots, wave = wave })
	end
end

-- ============ 환생 ============
local REBIRTH_MSG = {
	NEED_WAVE = "웨이브가 부족합니다.",
	NEED_GOLD = "골드가 부족합니다.",
	NEED_BOSS = "보스를 처치해야 합니다.",
}

function Growth.rebirth(player: Player)
	if not allow(player, "UPGRADE") then
		return
	end
	local st = Save.get(player)
	local ps = Save.getProgress(player)
	if not st or not ps then
		return
	end

	Progress.recordWave(ps, State.wave)
	local ok, err = Progress.canRebirth(ps, State.bossDefeatedThisRun)
	if not ok then
		notify(player, REBIRTH_MSG[tostring(err)] or "환생 조건 미달", "bad")
		return
	end

	if not Progress.applyRebirth(ps, Config.START_GOLD) then
		return
	end

	-- 재화/인벤토리 초기화
	st.gold = Config.START_GOLD
	st.slots = {}
	st.nextUid = 1
	Inventory.add(st, "ApprenticeTurret")

	-- 배치 타워 및 잔여 적 제거
	local cells = State.placed[player.UserId]
	if cells then
		for _, t in cells do
			if t.model then
				t.model:Destroy()
			end
		end
		State.placed[player.UserId] = {}
	end
	EnemyManager.clearAll()

	State.wave = 0
	State.baseHp = State.baseMaxHp
	State.bossDefeatedThisRun = false

	Save.save(player)
	pushState(player, st, 0)
	notify(player, string.format("환생 완료 — %d회차", ps.rebirths), "good")
	Save.syncProgress(player)
end

-- ============ 연구 ============
local RESEARCH_MSG = {
	MAX_LEVEL = "최대 레벨입니다.",
	NOT_ENOUGH_POINTS = "연구 포인트가 부족합니다.",
	UNKNOWN_RESEARCH = "알 수 없는 연구입니다.",
}

function Growth.research(player: Player, key: any)
	if not allow(player, "UPGRADE") then
		return
	end
	if type(key) ~= "string" then
		return
	end
	local ps = Save.getProgress(player)
	if not ps then
		return
	end

	local ok, err = Progress.buyResearch(ps, key)
	if not ok then
		notify(player, RESEARCH_MSG[tostring(err)] or "연구 실패", "bad")
		return
	end

	Save.save(player)
	local def = Progress.RESEARCH[key]
	notify(player, string.format("%s Lv.%d", def and def.name or key, ps.research[key] or 0), "good")
	Save.syncProgress(player)
end

-- ============ 지역 이동 ============
function Growth.zone(player: Player, zoneId: any)
	if not allow(player, "UPGRADE") then
		return
	end
	if type(zoneId) ~= "string" then
		return
	end
	local ps = Save.getProgress(player)
	if not ps then
		return
	end

	local target = nil
	for _, z in Lore.ZONES do
		if z.id == zoneId then
			target = z
			break
		end
	end
	if not target then
		return
	end

	if not Progress.isZoneUnlocked(ps, target.id, target.unlockWave) then
		notify(player, string.format("%s은(는) 웨이브 %d에서 해금됩니다.", target.kingdom, target.unlockWave), "bad")
		return
	end

	-- 실제로 맵을 재생성한다 (지역 테마 적용)
	WorldSetup.build(target.id)
	EnemyManager.clearAll()
	State.wave = 0
	State.baseHp = State.baseMaxHp
	State.bossDefeatedThisRun = false

	-- 배치된 타워는 맵과 함께 사라지므로 초기화 (인벤토리로는 돌려주지 않음 — 이동 비용)
	for userId, cells in State.placed do
		for _, t in cells do
			if t.model then
				t.model:Destroy()
			end
		end
		State.placed[userId] = {}
	end

	notify(player, target.kingdom .. " · " .. target.name .. "으로 이동", "good")
	Save.syncProgress(player)
end

-- ============ 미션 수령 ============
function Growth.claimMission(player: Player, key: any)
	if not allow(player, "UPGRADE") then
		return
	end
	if type(key) ~= "string" then
		return
	end
	local st = Save.get(player)
	local ms = Save.ensureMissions(player)
	if not st then
		return
	end

	local ok, reward = Missions.claim(ms, key)
	if not ok then
		notify(player, "수령할 수 없습니다.", "bad")
		return
	end

	st.gold = math.min(Config.MAX_GOLD, st.gold + reward)
	Save.save(player)
	notify(player, string.format("보상 수령: %dG", reward), "good")
	pushState(player, st, State.wave)
	Save.syncMissions(player)
end

return Growth
