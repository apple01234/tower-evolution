--!strict
-- 웨이브 진행: 스폰, 웨이브 카운트, 클라이언트 동기화.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Combat = require(Shared:WaitForChild("Combat"))
local Config = require(Shared:WaitForChild("Config"))
local Lore = require(Shared:WaitForChild("Lore"))
local Missions = require(Shared:WaitForChild("Missions"))
local Progress = require(Shared:WaitForChild("Progress"))

local EnemyManager = require(script.Parent:WaitForChild("EnemyManager"))
local Save = require(script.Parent:WaitForChild("Save"))
local State = require(script.Parent:WaitForChild("BattleState"))

local Waves = {}

-- 웨이브 상태를 전 클라이언트에 전송
function Waves.broadcast()
	local events = State.events
	if not events then
		return
	end
	local boss = EnemyManager.findBoss()
	events.WaveSync:FireAllClients(
		State.wave,
		boss ~= nil,
		boss and boss.hp or 0,
		boss and boss.maxHp or 0,
		State.baseHp,
		State.baseMaxHp
	)
end

-- 웨이브 도달을 플레이어 진행도/미션에 기록
local function recordArrival(wave: number)
	for _, p in Players:GetPlayers() do
		local ps = Save.ensureProgress(p)
		if Progress.recordWave(ps, wave) then
			Save.syncProgress(p)
		end
		local ms = Save.ensureMissions(p)
		local done = Missions.recordWave(ms, wave)
		if #done > 0 then
			Save.syncMissions(p)
		end
	end
end

-- 기지 피격 처리
function Waves.onBaseHit(damage: number)
	State.baseHp -= damage
	if State.baseHp > 0 then
		return
	end

	State.baseHp = State.baseMaxHp
	State.wave = math.max(0, State.wave - 1)
	local events = State.events
	if events then
		events.Notify:FireAllClients("기지가 함락되었습니다. 웨이브가 1 감소합니다.", "bad")
	end
end

-- 웨이브 1회 시작
function Waves.startNext()
	State.wave += 1
	local wave = State.wave
	local zone = Lore.zoneForWave(wave)
	local isBoss = Combat.isBossWave(wave, Config.BOSS_EVERY)

	if isBoss then
		EnemyManager.spawn(wave, true, zone)
	else
		local count = 4 + math.floor(wave / 2)
		for _ = 1, count do
			EnemyManager.spawn(wave, false, zone)
		end
	end

	recordArrival(wave)

	local events = State.events
	if events then
		events.Notify:FireAllClients(
			string.format("웨이브 %d 시작 — %s", wave, zone.name),
			isBoss and "boss" or "info"
		)
	end
	Waves.broadcast()
end

-- 메인 루프 (task.spawn 으로 실행)
function Waves.run()
	while true do
		task.wait(1)
		if not State.waveActive then
			State.waveActive = true
			Waves.startNext()
			task.wait(Config.WAVE_BREAK_SECONDS)
			State.waveActive = false
		end
	end
end

return Waves
