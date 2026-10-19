--!strict
-- 데이터 저장. 세션 간 성장 유지. 실패 시 재시도, 퇴장 시 저장.
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config"))
local Inventory = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Inventory"))
local Progress = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Progress"))

local Save = {}

local store: DataStore? = nil
local ok, err = pcall(function()
	store = DataStoreService:GetDataStore(Config.DATASTORE_NAME)
end)
if not ok then
	warn("[Save] DataStore 접근 실패: " .. tostring(err))
	store = nil
end

local cache: { [number]: Inventory.State } = {}
local progressCache: { [number]: Progress.State } = {}

local function defaultState(): Inventory.State
	local st = Inventory.new(Config.START_GOLD)
	Inventory.add(st, "ApprenticeTurret")
	return st
end

local function keyOf(userId: number): string
	return "p_" .. tostring(userId)
end

-- 저장 데이터 -> 상태 (구조 검증 포함)
local function sanitize(raw: any): Inventory.State
	local st = defaultState()
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
local function sanitizeProgress(raw: any): Progress.State
	local ps = Progress.new(Config.START_GOLD)
	if type(raw) ~= "table" then
		return ps
	end
	ps.rebirths = math.max(0, math.floor(tonumber(raw.rebirths) or 0))
	ps.maxWaveEver = math.max(0, math.floor(tonumber(raw.maxWaveEver) or 0))
	ps.wave = math.max(0, math.floor(tonumber(raw.wave) or 0))

	if type(raw.research) == "table" then
		for k, v in raw.research do
			if type(k) == "string" and Progress.RESEARCH[k] then
				local lv = math.max(0, math.floor(tonumber(v) or 0))
				ps.research[k] = math.min(lv, Progress.RESEARCH[k].maxLevel)
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

function Save.load(player: Player): Inventory.State
	if cache[player.UserId] then
		return cache[player.UserId]
	end
	local st = defaultState()
	if store then
		-- DataStore 호출은 실패할 수 있으므로 재시도 (공식 문서 권장 패턴)
		local success, result = false, nil
		for attempt = 1, 3 do
			local ds = store
			success, result = pcall(function()
				return ds:GetAsync(keyOf(player.UserId))
			end)
			if success then
				break
			end
			warn("[Save] 로드 실패(시도 " .. attempt .. ") " .. player.Name .. ": " .. tostring(result))
			task.wait(attempt * 0.5)
		end
		if success then
			st = sanitize(result)
			progressCache[player.UserId] = sanitizeProgress(result)
		else
			warn("[Save] 로드 실패 " .. player.Name .. ": " .. tostring(result))
		end
	end
	cache[player.UserId] = st
	progressCache[player.UserId] = progressCache[player.UserId] or sanitizeProgress(nil)
	return st
end

function Save.get(player: Player): Inventory.State?
	return cache[player.UserId]
end

function Save.getProgress(player: Player): Progress.State?
	return progressCache[player.UserId]
end

-- 진행 상태를 확보 (없으면 생성)
function Save.ensureProgress(player: Player): Progress.State
	local ps = progressCache[player.UserId]
	if not ps then
		ps = Progress.new(Config.START_GOLD)
		progressCache[player.UserId] = ps
	end
	return ps
end

function Save.save(player: Player): boolean
	local st = cache[player.UserId]
	if not st then
		return false
	end
	if not store then
		return false
	end
	-- 재시도 3회
	for attempt = 1, 3 do
		local ds = store
		local success, result = pcall(function()
			local ps = progressCache[player.UserId]
			ds:SetAsync(keyOf(player.UserId), {
				gold = st.gold,
				slots = st.slots,
				nextUid = st.nextUid,
				version = 2, -- v2: progress 필드 추가
				rebirths = ps and ps.rebirths or 0,
				maxWaveEver = ps and ps.maxWaveEver or 0,
				wave = ps and ps.wave or 0,
				research = ps and ps.research or {},
				collection = ps and ps.collection or {},
				zoneUnlocked = ps and ps.zoneUnlocked or {},
			})
		end)
		if success then
			return true
		end
		warn("[Save] 저장 실패(시도 " .. attempt .. ") " .. player.Name .. ": " .. tostring(result))
		task.wait(attempt * 0.5)
	end
	return false
end

-- Battle.init()이 주입한다 (순환 require 회피)
Save._events = nil :: any

-- 진행 상태를 클라이언트로 전송 (Research 비용/배율 포함)
function Save.syncProgress(player: Player)
	local ps = progressCache[player.UserId]
	if not ps then
		return
	end
	local events = Save._events
	if not events then
		return
	end
	local costs = {}
	for _, key in Progress.RESEARCH_ORDER do
		costs[key] = Progress.researchCost(key, Progress.researchLevel(ps, key))
	end
	events.ProgressSync:FireClient(player, {
		rebirths = ps.rebirths,
		points = Progress.researchPoints(ps),
		research = ps.research,
		costs = costs,
		collection = ps.collection,
		collectedCount = Progress.collectedCount(ps),
		maxWaveEver = ps.maxWaveEver,
		zoneUnlocked = ps.zoneUnlocked,
		goldMult = Progress.goldMultiplier(ps),
		damageMult = Progress.damageMultiplier(ps),
		summonMult = Progress.summonCostMultiplier(ps),
		summary = Progress.summary(ps),
	})
end

function Save.release(player: Player)
	cache[player.UserId] = nil
	progressCache[player.UserId] = nil
end

Players.PlayerRemoving:Connect(function(player)
	Save.save(player)
	Save.release(player)
end)

-- 주기적 자동 저장
task.spawn(function()
	while true do
		task.wait(Config.AUTOSAVE_SECONDS)
		for _, p in Players:GetPlayers() do
			if cache[p.UserId] then
				Save.save(p)
			end
		end
	end
end)

game:BindToClose(function()
	for _, p in Players:GetPlayers() do
		Save.save(p)
	end
end)

return Save
