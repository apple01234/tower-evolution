--!strict
-- 전투 서버: 웨이브, 적 이동, 타워 공격, 보상. 모든 수치는 서버 권한.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Combat = require(Shared:WaitForChild("Combat"))
local TowerData = require(Shared:WaitForChild("TowerData"))
local Lore = require(Shared:WaitForChild("Lore"))
local Net = require(Shared:WaitForChild("Net"))

local Save = require(script.Parent:WaitForChild("Save"))
local WorldSetup = require(script.Parent:WaitForChild("WorldSetup"))
local AssetLoader = require(script.Parent:WaitForChild("AssetLoader"))

local Battle = {}

local events = Net.init()

-- 활성 적 (서버 권한)
local enemies: { [number]: any } = {}
local enemyFolder: Folder
local nextEnemyId = 1
local currentWave = 0
local waveActive = false
local baseHp = 100
local baseMaxHp = 100

-- StateSync 스로틀 (초당 과다 전송 방지 — RemoteEvent#Throttling 공식 권장)
local SYNC_INTERVAL = 0.2 -- 5Hz
local syncAccum = 0

-- 배치된 타워: [playerUserId] = { [cellKey] = {uid, key, cooldown, model} }
local placed: { [number]: { [string]: any } } = {}

local function cellKey(col: number, row: number): string
	return tostring(col) .. "," .. tostring(row)
end

local function newEnemy(wave: number, isBoss: boolean, zone: any)
	local hpDef = Combat.enemyHp(wave, Config.ENEMY_HP_BASE, Config.ENEMY_HP_GROWTH)
	local hp = math.floor(hpDef * (zone and zone.hpMult or 1))
	local speed = Config.ENEMY_SPEED

	if isBoss then
		local bossKey = zone and zone.bossKey
		local bossDef = bossKey and Lore.getBoss(bossKey) or nil
		if bossDef then
			hp = math.floor(bossDef.hp * (1 + (wave / Config.BOSS_EVERY - 1) * 0.5))
			speed = bossDef.speed / 10
		else
			hp = math.floor(hp * Config.BOSS_HP_MULT)
			speed = Config.ENEMY_SPEED * Config.BOSS_SPEED_MULT
		end
	end

	-- 마켓플레이스 모델 사용, 실패 시 절차적 폴백
	local assetModel = AssetLoader.template(isBoss and "enemy_alt" or "enemy")
	local model: Instance
	if assetModel and assetModel:IsA("Model") then
		model = assetModel
		model.Name = isBoss and "Boss" or "Enemy"
		local target = isBoss and Vector3.new(6, 6, 6) or Vector3.new(3, 3, 3)
		AssetLoader.fit(model, target)
		-- 물리/충돌 정리: 모든 파트 고정
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") then
				d.Anchored = true
				d.CanCollide = false
				d.CanTouch = false
			end
		end
		model.Parent = enemyFolder
	else
		local fallback = Instance.new("Part")
		fallback.Name = isBoss and "Boss" or "Enemy"
		fallback.Shape = Enum.PartType.Ball
		fallback.Size = isBoss and Vector3.new(5, 5, 5) or Vector3.new(2.5, 2.5, 2.5)
		fallback.Color = isBoss and Color3.fromRGB(220, 40, 40) or Color3.fromRGB(200, 120, 60)
		fallback.Material = Enum.Material.Neon
		fallback.Anchored = true
		fallback.CanCollide = false
		fallback.Parent = enemyFolder
		model = fallback
	end

	local id = nextEnemyId
	nextEnemyId += 1

	local e = {
		id = id,
		hp = hp,
		maxHp = hp,
		pos = 0,
		t = 0,
		alive = true,
		reward = Combat.enemyReward(hp),
		isBoss = isBoss,
		speed = speed,
		model = model,
	}
	enemies[id] = e
	return e
end

local function removeEnemy(id: number)
	local e = enemies[id]
	if e then
		if e.model then
			e.model:Destroy()
		end
		enemies[id] = nil
	end
end

-- 클라이언트에 웨이브 상태 전송
local function broadcastWave()
	local boss = nil
	for _, e in enemies do
		if e.isBoss and e.alive then
			boss = e
			break
		end
	end
	events.WaveSync:FireAllClients(
		currentWave,
		boss ~= nil,
		boss and boss.hp or 0,
		boss and boss.maxHp or 0,
		baseHp,
		baseMaxHp
	)
end

-- 타워 사거리 판정용 거리 함수
local function makeDistanceFn(towerPos: Vector3)
	return function(e: any): number
		local ep = WorldSetup.pointAt(math.clamp(e.pos / WorldSetup.pathLength(), 0, 1))
		return (ep - towerPos).Magnitude
	end
end

local function makePairDistance()
	return function(a: any, b: any): number
		return math.abs(a.pos - b.pos)
	end
end

-- 모든 플레이어의 타워를 갱신
local function updateTowers(dt: number)
	local pathLen = WorldSetup.pathLength()
	if pathLen <= 0 then
		return
	end

	for userId, cells in placed do
		local player = Players:GetPlayerByUserId(userId)
		local state = player and Save.get(player) or nil

		for _, t in cells do
			t.cooldown -= dt
			if t.cooldown > 0 then
				continue
			end

			local def = TowerData.get(t.key)
			if not def then
				continue
			end

			-- 배치 시 계산한 위치를 재사용 (Model은 Position 속성이 없음)
			local towerPos = t.pos or WorldSetup.ORIGIN

			-- 살아있는 적 목록
			local list: { any } = {}
			for _, e in enemies do
				if e.alive then
					table.insert(list, e)
				end
			end
			if #list == 0 then
				continue
			end

			local distOf = makeDistanceFn(towerPos)
			local pairOf = makePairDistance()
			local hits = Combat.computeHits(def :: any, list, distOf, pairOf)
			if #hits == 0 then
				continue
			end

			local killed, _ = Combat.applyHits(enemies, hits)

			-- 보상 지급 (사망 즉시 alive=false이므로 중복 불가)
			for _, k in killed do
				if player and state then
					state.gold = math.min(Config.MAX_GOLD, state.gold + k.reward)
				end
				removeEnemy(k.id)
			end

			-- 공격 이펙트
			t.cooldown = 1 / math.max(0.05, def.attackSpeed)

			if #killed > 0 then
				broadcastWave()
			end
		end
	end

	-- 상태 동기화 (골드 변경 반영)
	-- 공식 문서: "To avoid throttling and latency issues, limit recurring remote events
	-- whenever possible." (RemoteEvent#Throttling) → Heartbeat마다 전송하지 않고 5Hz로 제한.
	syncAccum += dt
	if syncAccum >= SYNC_INTERVAL then
		syncAccum = 0
		for _, p in Players:GetPlayers() do
			local st = Save.get(p)
			if st then
				events.StateSync:FireClient(p, {
					gold = st.gold,
					slots = st.slots,
					wave = currentWave,
				})
			end
		end
	end
end

-- 적 이동
local function updateEnemies(dt: number)
	local pathLen = WorldSetup.pathLength()
	if pathLen <= 0 then
		return
	end
	for id, e in enemies do
		if not e.alive then
			removeEnemy(id)
			continue
		end
		e.pos += e.speed * dt
		if e.pos >= pathLen then
			-- 기지 도달
			baseHp -= e.isBoss and 25 or 5
			e.alive = false
			removeEnemy(id)
			if baseHp <= 0 then
				baseHp = baseMaxHp
				currentWave = math.max(0, currentWave - 1)
				events.Notify:FireAllClients("기지가 함락되었습니다. 웨이브가 1 감소합니다.", "bad")
			end
			broadcastWave()
			continue
		end
		local t = math.clamp(e.pos / pathLen, 0, 1)
		local wp = WorldSetup.pointAt(t)
		if e.model then
			local lift = e.isBoss and 3 or 1.5
			if e.model:IsA("Model") then
				-- Model은 Position 속성이 없다 → PivotTo 사용
				e.model:PivotTo(CFrame.new(wp + Vector3.new(0, lift, 0)))
			else
				e.model.Position = wp + Vector3.new(0, lift, 0)
			end
		end
	end
end

-- 웨이브 진행
local function runWaves()
	while true do
		task.wait(1)
		if not waveActive then
			waveActive = true
			currentWave += 1
			local zone = Lore.zoneForWave(currentWave)
			local isBoss = Combat.isBossWave(currentWave, Config.BOSS_EVERY)

			if isBoss then
				newEnemy(currentWave, true, zone)
			else
				local count = 4 + math.floor(currentWave / 2)
				for _ = 1, count do
					newEnemy(currentWave, false, zone)
				end
			end
			events.Notify:FireAllClients(
				string.format("웨이브 %d 시작 — %s", currentWave, zone.name),
				isBoss and "boss" or "info"
			)
			broadcastWave()
			task.wait(Config.WAVE_BREAK_SECONDS)
			waveActive = false
		end
	end
end

-- 원격 요청 핸들러 등록
local rateLimit: { [number]: { [string]: number } } = {}

local function allow(player: Player, action: string): boolean
	local now = os.clock()
	rateLimit[player.UserId] = rateLimit[player.UserId] or {}
	local rec = rateLimit[player.UserId]
	local limit = (Config.RATE :: any)[action] or 5
	if rec[action] and now - rec[action] < 1 / limit then
		return false
	end
	rec[action] = now
	return true
end

function Battle.init()
	enemyFolder = Instance.new("Folder")
	enemyFolder.Name = "Enemies"
	enemyFolder.Parent = workspace:FindFirstChild("TowerArena") or workspace

	WorldSetup.build()
	enemyFolder.Parent = workspace.TowerArena

	events.RequestSummon.OnServerEvent:Connect(function(player)
		if not allow(player, "SUMMON") then
			return
		end
		local st = Save.get(player)
		if not st then
			return
		end
		local cost = math.floor(Config.SUMMON_COST_BASE * (Config.SUMMON_COST_GROWTH ^ (#st.slots)))
		if st.gold < cost then
			events.Notify:FireClient(player, "골드가 부족합니다.", "bad")
			return
		end
		if #st.slots >= Config.INVENTORY_CAP then
			events.Notify:FireClient(player, "인벤토리가 가득 찼습니다.", "bad")
			return
		end
		st.gold -= cost
		local slot = Inventory.add(st, "ApprenticeTurret")
		events.StateSync:FireClient(player, { gold = st.gold, slots = st.slots, wave = currentWave })
		events.Notify:FireClient(player, "타워 소환: " .. (TowerData.get(slot.key) or { name = slot.key }).name, "good")
	end)

	events.RequestFuse.OnServerEvent:Connect(function(player, uids)
		if not allow(player, "FUSE") then
			return
		end
		local st = Save.get(player)
		if not st then
			return
		end
		if type(uids) ~= "table" then
			return
		end
		local firstKey = nil
		for _, uid in uids do
			for _, s in st.slots do
				if s.uid == uid then
					firstKey = s.key
					break
				end
			end
			if firstKey then
				break
			end
		end
		local def = firstKey and TowerData.get(firstKey) or nil
		local fuseCost = def and def.fuseCost or 0

		local result = Inventory.fuse(st, { uids = uids }, fuseCost, Config.INVENTORY_CAP)
		if not result.ok then
			events.Notify:FireClient(player, "합성 실패: " .. tostring(result.err), "bad")
			return
		end
		local nextKey = firstKey and TowerData.fuseResult(firstKey) or nil
		if not nextKey then
			events.Notify:FireClient(player, "더 이상 진화할 수 없습니다.", "bad")
			return
		end
		if not Inventory.commitFuse(st, result, nextKey, Config.INVENTORY_CAP) then
			events.Notify:FireClient(player, "합성 처리 중 오류.", "bad")
			return
		end
		local newSlot = Inventory.add(st, nextKey)
		local nd = TowerData.get(nextKey)
		events.StateSync:FireClient(player, { gold = st.gold, slots = st.slots, wave = currentWave })
		events.Notify:FireClient(player, "진화 성공: " .. (nd and nd.name or nextKey), "good")
		-- 도감 해금은 후속 단계
		;newSlot.level = 1
	end)

	events.RequestPlace.OnServerEvent:Connect(function(player, uid, col, row)
		if not allow(player, "PLACE") then
			return
		end
		local st = Save.get(player)
		if not st then
			return
		end
		if type(uid) ~= "string" or type(col) ~= "number" or type(row) ~= "number" then
			return
		end
		if col < 0 or col >= Config.GRID_COLS or row < 0 or row >= Config.GRID_ROWS then
			return
		end
		-- 소유 확인
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
		placed[player.UserId] = placed[player.UserId] or {}
		local ck = cellKey(col, row) .. "@" .. tostring(player.UserId)
		if placed[player.UserId][ck] then
			events.Notify:FireClient(player, "이미 타워가 있습니다.", "bad")
			return
		end
		local def = TowerData.get(owned.key)
		if not def then
			return
		end
		local wp = WorldSetup.cellToWorld(col, row)
		local towerFolder = workspace.TowerArena:FindFirstChild("Towers") or (function()
			local f = Instance.new("Folder")
			f.Name = "Towers"
			f.Parent = workspace.TowerArena
			return f
		end)()

		-- 마켓플레이스 모델 사용, 실패 시 파트 폴백
		local assetModel = AssetLoader.template(owned.key)
		local model: Instance
		if assetModel and assetModel:IsA("Model") then
			model = assetModel
			model.Name = owned.key
			AssetLoader.fit(model, Vector3.new(4, 6, 4))
			for _, d in model:GetDescendants() do
				if d:IsA("BasePart") then
					d.Anchored = true
					d.CanCollide = false
					d.CanTouch = false
				end
			end
			AssetLoader.place(model, wp)
			model.Parent = towerFolder
		else
			local fallback = Instance.new("Part")
			fallback.Name = owned.key
			fallback.Size = Vector3.new(3, 4, 3)
			fallback.Position = wp + Vector3.new(0, 2, 0)
			fallback.Anchored = true
			fallback.CanCollide = false
			fallback.Material = Enum.Material.Metal
			fallback.Color = Color3.fromRGB(90, 140, 220)
			fallback.Parent = towerFolder
			model = fallback
		end

		-- 사거리 판정용 위치 (Model은 Position 속성이 없으므로 미리 확정)
		local towerPos: Vector3
		if model:IsA("Model") then
			local okBox, bbox = pcall(model.GetBoundingBox, model)
			towerPos = okBox and bbox.Position or (wp + Vector3.new(0, 2, 0))
		else
			towerPos = (model :: BasePart).Position
		end

		placed[player.UserId][ck] = {
			uid = uid,
			key = owned.key,
			cooldown = 0,
			model = model,
			pos = towerPos,
		}
		-- 인벤토리에서 제거 (배치된 타워는 별도 관리)
		Inventory.removeUid(st, uid)
		events.StateSync:FireClient(player, { gold = st.gold, slots = st.slots, wave = currentWave })
		events.Notify:FireClient(player, def.name .. " 배치 완료", "good")
	end)

	events.RequestUpgrade.OnServerEvent:Connect(function(player, uid)
		if not allow(player, "UPGRADE") then
			return
		end
		-- 후속 단계에서 구현
		events.Notify:FireClient(player, "업그레이드는 준비 중입니다.", "info")
	end)

	events.RequestSell.OnServerEvent:Connect(function(player, uid)
		if not allow(player, "UPGRADE") then
			return
		end
		local st = Save.get(player)
		if not st then
			return
		end
		local cells = placed[player.UserId]
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
				events.StateSync:FireClient(player, { gold = st.gold, slots = st.slots, wave = currentWave })
				events.Notify:FireClient(player, (d and d.name or t.key) .. " 회수", "info")
				return
			end
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		placed[player.UserId] = nil
		rateLimit[player.UserId] = nil
	end)

	task.spawn(runWaves)

	RunService.Heartbeat:Connect(function(dt)
		updateEnemies(dt)
		updateTowers(dt)
	end)
end

return Battle
