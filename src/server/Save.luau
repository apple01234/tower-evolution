--!strict
-- 데이터 저장. 세션 간 성장 유지. 실패 시 재시도, 퇴장 시 저장.
-- 정규화 로직은 Sanitize.luau 에 있다.
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Inventory = require(Shared:WaitForChild("Inventory"))
local Missions = require(Shared:WaitForChild("Missions"))
local Progress = require(Shared:WaitForChild("Progress"))

local Sanitize = require(script.Parent:WaitForChild("Sanitize"))

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
local missionCache: { [number]: Missions.State } = {}

-- Battle.init()이 주입한다 (순환 require 회피)
Save._events = nil :: any

local RETRY = 3

local function keyOf(userId: number): string
	return "p_" .. tostring(userId)
end

-- DataStore 읽기 (재시도)
local function readStore(userId: number, name: string): (boolean, any)
	if not store then
		return false, nil
	end
	local success, result = false, nil
	for attempt = 1, RETRY do
		local ds = store
		success, result = pcall(function()
			return ds:GetAsync(keyOf(userId))
		end)
		if success then
			return true, result
		end
		warn(string.format("[Save] 로드 실패(시도 %d) %s: %s", attempt, name, tostring(result)))
		task.wait(attempt * 0.5)
	end
	return false, result
end

function Save.load(player: Player): Inventory.State
	local cached = cache[player.UserId]
	if cached then
		return cached
	end

	local st = Sanitize.defaultInventory()
	local success, raw = readStore(player.UserId, player.Name)
	if success then
		st = Sanitize.inventory(raw)
		progressCache[player.UserId] = Sanitize.progress(raw)
		missionCache[player.UserId] = Sanitize.missions(raw and raw.missions, os.time())
	end

	cache[player.UserId] = st
	progressCache[player.UserId] = progressCache[player.UserId] or Sanitize.progress(nil)
	missionCache[player.UserId] = missionCache[player.UserId] or Missions.new(os.time())
	return st
end

function Save.get(player: Player): Inventory.State?
	return cache[player.UserId]
end

function Save.getProgress(player: Player): Progress.State?
	return progressCache[player.UserId]
end

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
	if not st or not store then
		return false
	end

	local payload = Sanitize.payload(st, progressCache[player.UserId], missionCache[player.UserId])
	for attempt = 1, RETRY do
		local ds = store
		local success, result = pcall(function()
			ds:SetAsync(keyOf(player.UserId), payload)
		end)
		if success then
			return true
		end
		warn(string.format("[Save] 저장 실패(시도 %d) %s: %s", attempt, player.Name, tostring(result)))
		task.wait(attempt * 0.5)
	end
	return false
end

function Save.getMissions(player: Player): Missions.State?
	return missionCache[player.UserId]
end

function Save.ensureMissions(player: Player): Missions.State
	local ms = missionCache[player.UserId]
	if not ms then
		ms = Missions.new(os.time())
		missionCache[player.UserId] = ms
	end
	if Missions.checkReset(ms, os.time()) then
		Save.syncMissions(player)
	end
	return ms
end

function Save.syncMissions(player: Player)
	local ms = missionCache[player.UserId]
	local events = Save._events
	if not ms or not events then
		return
	end
	events.MissionSync:FireClient(player, Missions.snapshot(ms))
end

-- 진행 상태 + 미션을 클라이언트로 전송
function Save.syncProgress(player: Player)
	local ps = progressCache[player.UserId]
	local events = Save._events
	if not ps or not events then
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
	Save.syncMissions(player)
end

function Save.release(player: Player)
	cache[player.UserId] = nil
	progressCache[player.UserId] = nil
	missionCache[player.UserId] = nil
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
