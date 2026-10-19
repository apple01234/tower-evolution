--!strict
-- 타워 공격 처리: 사거리 판정, 피해 적용, 보상 지급.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Combat = require(Shared:WaitForChild("Combat"))
local Config = require(Shared:WaitForChild("Config"))
local Missions = require(Shared:WaitForChild("Missions"))
local Progress = require(Shared:WaitForChild("Progress"))
local TowerData = require(Shared:WaitForChild("TowerData"))
local Anim = require(Shared:WaitForChild("Anim"))

local EnemyManager = require(script.Parent:WaitForChild("EnemyManager"))
local Save = require(script.Parent:WaitForChild("Save"))
local State = require(script.Parent:WaitForChild("BattleState"))
local WorldSetup = require(script.Parent:WaitForChild("WorldSetup"))

local TowerCombat = {}

local SYNC_INTERVAL = 0.2 -- 5Hz (RemoteEvent#Throttling 공식 권장)
local syncAccum = 0

-- 타워로부터 적까지 거리 함수
local function distanceFn(towerPos: Vector3)
	return function(e: any): number
		local ep = WorldSetup.pointAt(math.clamp(e.pos / WorldSetup.pathLength(), 0, 1))
		return (ep - towerPos).Magnitude
	end
end

local function pairDistance(a: any, b: any): number
	return math.abs(a.pos - b.pos)
end

-- 연구 배율을 적용한 타워 정의 사본
local function scaledDef(def: any, mult: number)
	return {
		damage = def.damage * mult,
		attackKind = def.attackKind,
		range = def.range,
		pierceCount = def.pierceCount,
		chainCount = def.chainCount,
		chainFalloff = def.chainFalloff,
		aoeRadius = def.aoeRadius,
	}
end

-- 둔화 파라미터가 있으면 slow 테이블 반환
local function slowOf(def: any)
	if def.slowFactor and def.slowDuration then
		return { factor = def.slowFactor, duration = def.slowDuration }
	end
	return nil
end

-- 적 처치 보상 처리 (중복 지급 불가: applyHits가 alive=false를 선행)
local function grantKill(player: Player, enemy: any)
	local st = Save.get(player)
	if not st then
		return
	end
	local ps = Save.ensureProgress(player)
	local gain = math.floor(enemy.reward * Progress.goldMultiplier(ps))
	st.gold = math.min(Config.MAX_GOLD, st.gold + gain)

	local ms = Save.ensureMissions(player)
	if enemy.isBoss then
		State.bossDefeatedThisRun = true
		Missions.record(ms, "boss", 1)
	end
	Missions.record(ms, "kill", 1)
end

-- 단일 타워 공격 시도. 사망한 적이 있으면 true.
local function fireTower(player: Player, tower: any): boolean
	local def = TowerData.get(tower.key)
	if not def then
		return false
	end

	local list = EnemyManager.aliveList()
	if #list == 0 then
		return false
	end

	local ps = Save.ensureProgress(player)
	local mult = Progress.damageMultiplier(ps)
	local towerPos = tower.pos or WorldSetup.ORIGIN

	local hits = Combat.computeHits(scaledDef(def, mult), list, distanceFn(towerPos), pairDistance)
	if #hits == 0 then
		return false
	end

	local now = os.clock()
	for _, e in State.enemies do
		e.now = now
	end
	local killed = Combat.applyHits(State.enemies, hits, slowOf(def))
	for _, k in killed do
		grantKill(player, k)
		EnemyManager.removeAnimated(k.id)
	end

	-- 발사 반동 연출
	if tower.model then
		Anim.towerFire(tower.model)
	end

	tower.cooldown = 1 / math.max(0.05, def.attackSpeed)
	return #killed > 0
end

-- 모든 배치 타워 갱신 + 상태 동기화(스로틀)
function TowerCombat.update(dt: number)
	if WorldSetup.pathLength() <= 0 then
		return
	end

	local anyKilled = false
	for userId, cells in State.placed do
		local player = Players:GetPlayerByUserId(userId)
		if player then
			for _, tower in cells do
				tower.cooldown -= dt
				if tower.cooldown <= 0 then
					if fireTower(player, tower) then
						anyKilled = true
					end
				end
			end
		end
	end

	-- 골드/인벤토리 동기화 (5Hz)
	syncAccum += dt
	if syncAccum >= SYNC_INTERVAL then
		syncAccum = 0
		local events = State.events
		if events then
			for _, p in Players:GetPlayers() do
				local st = Save.get(p)
				if st then
					events.StateSync:FireClient(p, {
						gold = st.gold,
						slots = st.slots,
						wave = State.wave,
					})
				end
			end
		end
	end

	if anyKilled and State.events then
		State.events.WaveSync:FireAllClients(
			State.wave,
			EnemyManager.findBoss() ~= nil,
			(EnemyManager.findBoss() or { hp = 0 }).hp,
			(EnemyManager.findBoss() or { maxHp = 0 }).maxHp,
			State.baseHp,
			State.baseMaxHp
		)
	end
end

function TowerCombat.resetSync()
	syncAccum = 0
end

return TowerCombat
