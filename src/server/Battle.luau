--!strict
-- 전투 시스템 조립자. 실제 로직은 각 모듈에 있고 여기서는 배선만 한다.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Lore = require(Shared:WaitForChild("Lore"))
local Missions = require(Shared:WaitForChild("Missions"))
local Net = require(Shared:WaitForChild("Net"))

local CoopBossServer = require(script.Parent:WaitForChild("CoopBossServer"))
local EnemyManager = require(script.Parent:WaitForChild("EnemyManager"))
local Growth = require(script.Parent:WaitForChild("HandlersGrowth"))
local Handlers = require(script.Parent:WaitForChild("HandlersInventory"))
local Save = require(script.Parent:WaitForChild("Save"))
local State = require(script.Parent:WaitForChild("BattleState"))
local TowerCombat = require(script.Parent:WaitForChild("TowerCombat"))
local Waves = require(script.Parent:WaitForChild("Waves"))
local WorldSetup = require(script.Parent:WaitForChild("WorldSetup"))
local Diag = require(script.Parent:WaitForChild("Diag"))

local Battle = {}

-- ============ 레이트 리밋 ============
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

-- ============ 미션 알림 ============
local function notifyMission(player: Player, done: { string })
	if #done == 0 then
		return
	end
	local events = State.events
	if not events then
		return
	end
	for _, key in done do
		local def = Missions.DEFS[key]
		if def then
			events.Notify:FireClient(player, "미션 완료: " .. def.title, "good")
		end
	end
	Save.syncMissions(player)
end

-- ============ 전체 상태 전송 ============
function Battle.syncPlayer(player: Player)
	local st = Save.get(player)
	if not st then
		return
	end
	local events = State.events
	if events then
		events.StateSync:FireClient(player, { gold = st.gold, slots = st.slots, wave = State.wave })
	end
	Save.syncProgress(player)
	Save.syncMissions(player)
end

-- ============ 초기화 ============
function Battle.init()
	local events = Net.init()
	Save._events = events
	State.events = events

	-- 핸들러 유틸 주입
	Handlers.inject({ allow = allow, notifyMission = notifyMission })
	Growth.inject({ allow = allow })

	-- 월드 생성 (첫 지역 테마)
	Diag.log("== Battle.init ==")
	if not Diag.step("WorldSetup.build", function()
		WorldSetup.build("Midgard_Forest")
	end) then
		Diag.log("  -> 이후 단계 중단")
		return
	end
	local arena = workspace:FindFirstChild("TowerArena")
	if not arena then
		Diag.log("FAIL TowerArena 없음")
		warn("[Battle] TowerArena 생성 실패")
		return
	end
	Diag.log("OK   TowerArena (" .. tostring(#arena:GetChildren()) .. " children)")

	local folder = Instance.new("Folder")
	folder.Name = "Enemies"
	folder.Parent = arena
	State.enemyFolder = folder
	State.baseMaxHp = Config.BASE_HP or 100
	State.baseHp = State.baseMaxHp

	-- 원격 핸들러 배선
	events.RequestSummon.OnServerEvent:Connect(Handlers.summon)
	events.RequestFuse.OnServerEvent:Connect(Handlers.fuse)
	events.RequestPlace.OnServerEvent:Connect(Handlers.place)
	events.RequestSell.OnServerEvent:Connect(Handlers.sell)
	events.RequestUpgrade.OnServerEvent:Connect(Handlers.upgrade)

	events.RequestRebirth.OnServerEvent:Connect(Growth.rebirth)
	events.RequestResearch.OnServerEvent:Connect(Growth.research)
	events.RequestZone.OnServerEvent:Connect(Growth.zone)
	events.RequestClaimMission.OnServerEvent:Connect(Growth.claimMission)

	-- 클라이언트가 UI 준비를 마치면 전체 상태를 다시 보낸다.
	-- (PlayerAdded 시점의 1회성 전송은 클라가 아직 안 붙었을 수 있어 유실된다)
	events.RequestState.OnServerEvent:Connect(function(player)
		if not allow(player, "STATE") then
			return
		end
		Battle.syncPlayer(player)
		Waves.broadcast()
	end)

	-- 퇴장 정리
	Players.PlayerRemoving:Connect(function(player)
		local cells = State.placed[player.UserId]
		if cells then
			for _, t in cells do
				if t.model then
					t.model:Destroy()
				end
			end
		end
		State.placed[player.UserId] = nil
		rateLimit[player.UserId] = nil
	end)

	-- 웨이브 루프 (Waves.run 은 while true 라 pcall 로 감싸면 반환하지 않는다)
	task.spawn(Waves.run)
	Diag.log("OK   Waves.run 스폰됨")

	-- 협동 보스 자동 등장 루프
	task.spawn(function()
		while true do
			task.wait(Config.COOP_BOSS_INTERVAL)
			CoopBossServer.tick()
			if not CoopBossServer.isActive() then
				-- 지역의 보스를 순환 등장
				local zone = Lore.zoneForWave(State.wave)
				CoopBossServer.start(zone.bossKey)
			end
		end
	end)

	-- 프레임 루프
	local beats = 0
	local lastReport = 0
	RunService.Heartbeat:Connect(function(dt)
		beats += 1
		if beats == 1 then
			Diag.log("OK   Heartbeat 첫 프레임")
		end
		local ok1, e1 = pcall(CoopBossServer.tick)
		if not ok1 then
			Diag.log("FAIL CoopBossServer.tick: " .. tostring(e1))
		end
		local ok2, anyHit = pcall(EnemyManager.update, dt, Waves.onBaseHit)
		if not ok2 then
			Diag.log("FAIL EnemyManager.update: " .. tostring(anyHit))
		elseif anyHit then
			Waves.broadcast()
		end
		local ok3, e3 = pcall(TowerCombat.update, dt)
		if not ok3 then
			Diag.log("FAIL TowerCombat.update: " .. tostring(e3))
		end
		-- 3초마다 상태 요약
		local now = os.clock()
		if now - lastReport >= 3 then
			lastReport = now
			Diag.log(string.format("beat=%d wave=%d enemies=%d towers=%d",
				beats, State.wave, (function()
					local n = 0
					for _ in State.enemies do n += 1 end
					return n
				end)(), (function()
					local n = 0
					for _, cells in State.placed do
						for _ in cells do n += 1 end
					end
					return n
				end)()))
		end
	end)
end

return Battle
