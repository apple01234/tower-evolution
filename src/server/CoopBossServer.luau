--!strict
-- 협동 보스 서버 관리: 웨이브와 별개로 주기적으로 등장하며,
-- 참가자 전원의 피해를 하나의 HP로 집계한다.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local CoopBoss = require(Shared:WaitForChild("CoopBoss"))
local Lore = require(Shared:WaitForChild("Lore"))

local Save = require(script.Parent:WaitForChild("Save"))
local State = require(script.Parent:WaitForChild("BattleState"))

local CoopBossServer = {}

local current: any = nil -- CoopBoss.Boss
local bossPart: Part? = nil
local bossModel: Instance? = nil

local function arena(): Instance?
	return workspace:FindFirstChild("TowerArena")
end

local function buildBossVisual(boss: any)
	local a = arena()
	if not a then
		return
	end

	local baseCF: CFrame
	local basePart = a:FindFirstChild("BaseMark")
	if basePart and basePart:IsA("BasePart") then
		baseCF = basePart.CFrame + Vector3.new(0, 12, 12)
	else
		baseCF = CFrame.new(0, 12, 12)
	end

	-- 마켓플레이스 드래곤 에셋 우선
	local asset = AssetLoader.template("boss_dragon")
	if asset and asset:IsA("Model") then
		AssetLoader.fit(asset, Vector3.new(12, 12, 12))
		for _, d in asset:GetDescendants() do
			if d:IsA("BasePart") then
				d.Anchored = true
				d.CanCollide = false
				d.CanTouch = false
			end
		end
		asset.Name = "CoopBoss"
		asset:PivotTo(baseCF)
		asset.Parent = a
		bossModel = asset
		_ = boss
		return
	end

	local child = Instance.new("Part")
	child.Name = "CoopBoss"
	child.Shape = Enum.PartType.Ball
	child.Anchored = true
	child.CanCollide = false
	child.Size = Vector3.new(10, 10, 10)
	child.Material = Enum.Material.Neon
	child.Color = Color3.fromRGB(220, 40, 60)

	child.CFrame = baseCF
	child.Parent = a
	bossPart = child
end

local function clearVisual()
	if bossPart then
		bossPart:Destroy()
		bossPart = nil
	end
	if bossModel then
		bossModel:Destroy()
		bossModel = nil
	end
end

-- 클라이언트에 보스 상태 전송
function CoopBossServer.broadcast()
	local events = State.events
	if not events then
		return
	end
	if not current then
		events.CoopSync:FireAllClients(nil)
		return
	end
	events.CoopSync:FireAllClients({
		key = current.key,
		name = current.name,
		hp = current.hp,
		maxHp = current.maxHp,
		active = current.active,
		progress = CoopBoss.progress(current),
		participants = CoopBoss.participantCount(current),
	})
end

-- 보스 시작
function CoopBossServer.start(bossKey: string)
	if current and current.active then
		return -- 이미 진행 중
	end

	local def = Lore.getBoss(bossKey)
	if not def then
		return
	end

	-- 협동 보스는 HP를 크게 (참가자 수 고려)
	local hp = math.floor(def.hp * Config.COOP_BOSS_HP_MULT)
	current = CoopBoss.new(bossKey, def.name, hp, os.clock())
	buildBossVisual(current)

	local events = State.events
	if events then
		events.Notify:FireAllClients(
			string.format("협동 보스 등장 — %s", def.name),
			"boss"
		)
	end
	CoopBossServer.broadcast()
end

-- 피해 누적 (타워 공격에서 호출)
function CoopBossServer.damage(player: Player, amount: number): number
	if not current or not current.active then
		return 0
	end
	local applied = CoopBoss.applyDamage(current, player.UserId, amount, os.clock())
	if applied > 0 then
		CoopBossServer.broadcast()
	end
	return applied
end

-- 보스 처치 보상 분배
local function payout()
	if not current or current.active then
		return
	end

	local totalReward = math.floor(current.maxHp * Config.COOP_BOSS_REWARD_PER_HP)
	local rewards = CoopBoss.distribute(current, totalReward)

	for userId, reward in rewards do
		local player = Players:GetPlayerByUserId(userId)
		if player then
			local st = Save.get(player)
			if st then
				st.gold = math.min(Config.MAX_GOLD, st.gold + reward)
				local events = State.events
				if events then
					events.Notify:FireClient(
						player,
						string.format("협동 보스 보상: %dG (기여도 순위 반영)", reward),
						"good"
					)
					events.StateSync:FireClient(player, {
						gold = st.gold,
						slots = st.slots,
						wave = State.wave,
					})
				end
			end
		end
	end

	-- 참가자 전원 보스 처치 기록
	for userId in current.participants do
		local player = Players:GetPlayerByUserId(userId)
		if player then
			State.bossDefeatedThisRun = true
		end
	end
end

function CoopBossServer.finish()
	if not current then
		return
	end
	payout()
	clearVisual()
	CoopBossServer.broadcast()
	current = nil
end

function CoopBossServer.get(): any
	return current
end

function CoopBossServer.isActive(): boolean
	return current ~= nil and current.active == true
end

-- 만료 감시 (참가자가 없거나 시간 초과 시 정리)
function CoopBossServer.tick()
	if not current then
		return
	end
	if CoopBoss.isExpired(current, os.clock(), Config.COOP_BOSS_TIMEOUT) then
		if current.active then
			-- 시간 초과로 사라짐 (보상 없음)
			local events = State.events
			if events then
				events.Notify:FireAllClients("협동 보스가 퇴장했습니다.", "info")
			end
			clearVisual()
			current = nil
			CoopBossServer.broadcast()
		else
			CoopBossServer.finish()
		end
	end
end

return CoopBossServer
