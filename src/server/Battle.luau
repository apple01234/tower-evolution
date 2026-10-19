--!strict
-- 전투 시스템 조립자. 실제 로직은 각 모듈에 있고 여기서는 배선만 한다.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Missions = require(Shared:WaitForChild("Missions"))
local Net = require(Shared:WaitForChild("Net"))

local EnemyManager = require(script.Parent:WaitForChild("EnemyManager"))
local Growth = require(script.Parent:WaitForChild("HandlersGrowth"))
local Handlers = require(script.Parent:WaitForChild("HandlersInventory"))
local Save = require(script.Parent:WaitForChild("Save"))
local State = require(script.Parent:WaitForChild("BattleState"))
local TowerCombat = require(script.Parent:WaitForChild("TowerCombat"))
local Waves = require(script.Parent:WaitForChild("Waves"))
local WorldSetup = require(script.Parent:WaitForChild("WorldSetup"))

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

	-- 월드 생성
	WorldSetup.build()
	local arena = workspace:FindFirstChild("TowerArena")
	if not arena then
		warn("[Battle] TowerArena 생성 실패")
		return
	end

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

	-- 웨이브 루프
	task.spawn(Waves.run)

	-- 프레임 루프
	RunService.Heartbeat:Connect(function(dt)
		local anyHit = EnemyManager.update(dt, Waves.onBaseHit)
		if anyHit then
			Waves.broadcast()
		end
		TowerCombat.update(dt)
	end)
end

return Battle
