--!strict
-- 저장 데이터 검증/복원. 손상되거나 조작된 DataStore 값을 안전한 형태로 정규화한다.
-- Roblox API 무의존 (순수 함수) → Lune 검증 가능.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local Config = require(Shared:WaitForChild("Config"))
local Inventory = require(Shared:WaitForChild("Inventory"))
local Missions = require(Shared:WaitForChild("Missions"))
local Progress = require(Shared:WaitForChild("Progress"))

local Sanitize = {}

function Sanitize.defaultInventory(): Inventory.State
	local st = Inventory.new(Config.START_GOLD)
	Inventory.add(st, "ApprenticeTurret")
	return st
end

-- 인벤토리 복원
function Sanitize.inventory(raw: any): Inventory.State
	local st = Sanitize.defaultInventory()
	if type(raw) ~= "table" then
		return st
	end

	local gold = tonumber(raw.gold) or Config.START_GOLD
	st.gold = math.clamp(gold, 0, Config.MAX_GOLD)

	if type(raw.slots) == "table" then
		st.slots = {}
		for _, s in raw.slots do
			if type(s) == "table" and type(s.key) == "string" and type(s.uid) == "string" then
				table.insert(st.slots, { uid = s.uid, key = s.key, level = tonumber(s.level) or 1 })
			end
		end
	end
	st.nextUid = tonumber(raw.nextUid) or (#st.slots + 1)
	return st
end

-- 영구 성장 데이터 복원 (환생/연구/도감/지역)
function Sanitize.progress(raw: any): Progress.State
	local ps = Progress.new(Config.START_GOLD)
	if type(raw) ~= "table" then
		return ps
	end

	ps.rebirths = math.max(0, math.floor(tonumber(raw.rebirths) or 0))
	ps.maxWaveEver = math.max(0, math.floor(tonumber(raw.maxWaveEver) or 0))
	ps.wave = math.max(0, math.floor(tonumber(raw.wave) or 0))

	if type(raw.research) == "table" then
		for k, v in raw.research do
			local def = type(k) == "string" and Progress.RESEARCH[k] or nil
			if def then
				local lv = math.max(0, math.floor(tonumber(v) or 0))
				ps.research[k] = math.min(lv, def.maxLevel)
			end
		end
	end

	if type(raw.collection) == "table" then
		for k, v in raw.collection do
			if type(k) == "string" and v == true then
				ps.collection[k] = true
			end
		end
	end

	if type(raw.zoneUnlocked) == "table" then
		for k, v in raw.zoneUnlocked do
			if type(k) == "string" and v == true then
				ps.zoneUnlocked[k] = true
			end
		end
	end

	return ps
end

-- 미션 복원 (만료된 리셋도 즉시 처리)
function Sanitize.missions(raw: any, now: number): Missions.State
	return Missions.restore(raw, now)
end

-- 저장 페이로드 생성
function Sanitize.payload(inv: Inventory.State?, prog: Progress.State?, mis: Missions.State?): { [string]: any }
	return {
		gold = inv and inv.gold or 0,
		slots = inv and inv.slots or {},
		nextUid = inv and inv.nextUid or 1,
		version = 2, -- v2: progress + missions 추가
		rebirths = prog and prog.rebirths or 0,
		maxWaveEver = prog and prog.maxWaveEver or 0,
		wave = prog and prog.wave or 0,
		research = prog and prog.research or {},
		collection = prog and prog.collection or {},
		zoneUnlocked = prog and prog.zoneUnlocked or {},
		missions = mis and {
			daily = mis.daily,
			weekly = mis.weekly,
			dailyReset = mis.dailyReset,
			weeklyReset = mis.weeklyReset,
			dailySeed = mis.dailySeed,
			weeklySeed = mis.weeklySeed,
		} or nil,
	}
end

return Sanitize
