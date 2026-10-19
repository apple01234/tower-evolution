--!strict
-- 데이터 저장. 세션 간 성장 유지. 실패 시 재시도, 퇴장 시 저장.
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config"))
local Inventory = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Inventory"))

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

function Save.load(player: Player): Inventory.State
	if cache[player.UserId] then
		return cache[player.UserId]
	end
	local st = defaultState()
	if store then
		local success, result = pcall(function()
			return (store :: DataStore):GetAsync(keyOf(player.UserId))
		end)
		if success then
			st = sanitize(result)
		else
			warn("[Save] 로드 실패 " .. player.Name .. ": " .. tostring(result))
		end
	end
	cache[player.UserId] = st
	return st
end

function Save.get(player: Player): Inventory.State?
	return cache[player.UserId]
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
			ds:SetAsync(keyOf(player.UserId), {
				gold = st.gold,
				slots = st.slots,
				nextUid = st.nextUid,
				version = 1,
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

function Save.release(player: Player)
	cache[player.UserId] = nil
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
