--!strict
-- 적 생성/삭제/이동. 웨이브와 타워 공격은 별도 모듈 담당.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Combat = require(Shared:WaitForChild("Combat"))
local Lore = require(Shared:WaitForChild("Lore"))

local AssetLoader = require(script.Parent:WaitForChild("AssetLoader"))
local State = require(script.Parent:WaitForChild("BattleState"))
local WorldSetup = require(script.Parent:WaitForChild("WorldSetup"))

local EnemyManager = {}

local nextEnemyId = 1

-- 적 모델 생성 (에셋 실패 시 파트 폴백). 모델과 위치는 호출자가 parent 지정.
local function buildEnemyModel(isBoss: boolean): Instance
	local assetModel = AssetLoader.template(isBoss and "enemy_alt" or "enemy")
	if assetModel and assetModel:IsA("Model") then
		assetModel.Name = isBoss and "Boss" or "Enemy"
		AssetLoader.fit(assetModel, isBoss and Vector3.new(6, 6, 6) or Vector3.new(3, 3, 3))
		for _, d in assetModel:GetDescendants() do
			if d:IsA("BasePart") then
				d.Anchored = true
				d.CanCollide = false
				d.CanTouch = false
			end
		end
		return assetModel
	end

	local fallback = Instance.new("Part")
	fallback.Name = isBoss and "Boss" or "Enemy"
	fallback.Shape = Enum.PartType.Ball
	fallback.Size = isBoss and Vector3.new(5, 5, 5) or Vector3.new(2.5, 2.5, 2.5)
	fallback.Color = isBoss and Color3.fromRGB(220, 40, 40) or Color3.fromRGB(200, 120, 60)
	fallback.Material = Enum.Material.Neon
	fallback.Anchored = true
	fallback.CanCollide = false
	return fallback
end

-- 보스/일반 체력 및 속도 산출
local function statsFor(wave: number, isBoss: boolean, zone: any): (number, number)
	local hp = math.floor(Combat.enemyHp(wave, Config.ENEMY_HP_BASE, Config.ENEMY_HP_GROWTH) * (zone and zone.hpMult or 1))
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
	return hp, speed
end

function EnemyManager.spawn(wave: number, isBoss: boolean, zone: any): any?
	local folder = State.enemyFolder
	if not folder then
		return nil
	end

	local hp, speed = statsFor(wave, isBoss, zone)
	local model = buildEnemyModel(isBoss)
	model.Parent = folder

	local id = nextEnemyId
	nextEnemyId += 1

	local e = {
		id = id,
		hp = hp,
		maxHp = hp,
		pos = 0,
		alive = true,
		reward = Combat.enemyReward(hp),
		isBoss = isBoss,
		speed = speed,
		model = model,
	}
	State.enemies[id] = e
	return e
end

function EnemyManager.remove(id: number)
	local e = State.enemies[id]
	if e then
		if e.model then
			e.model:Destroy()
		end
		State.enemies[id] = nil
	end
end

function EnemyManager.aliveList(): { any }
	local list = {}
	for _, e in State.enemies do
		if e.alive then
			table.insert(list, e)
		end
	end
	return list
end

function EnemyManager.findBoss(): any?
	for _, e in State.enemies do
		if e.isBoss and e.alive then
			return e
		end
	end
	return nil
end

local function moveModel(model: Instance, at: Vector3)
	if model:IsA("Model") then
		model:PivotTo(CFrame.new(at))
	else
		(model :: BasePart).Position = at
	end
end

-- 적 이동 및 기지 도달 처리. 도달 시 true 반환(기지 피격 발생).
function EnemyManager.update(dt: number, onBaseHit: (number) -> ()): boolean
	local pathLen = WorldSetup.pathLength()
	if pathLen <= 0 then
		return false
	end

	local hit = false
	local now = os.clock()
	for id, e in State.enemies do
		if not e.alive then
			EnemyManager.remove(id)
			continue
		end

		-- 둔화 적용 (Frost 계열)
		e.pos += Combat.effectiveSpeed(e, now) * dt
		if e.pos >= pathLen then
			onBaseHit(e.isBoss and 25 or 5)
			e.alive = false
			EnemyManager.remove(id)
			hit = true
			continue
		end

		local t = math.clamp(e.pos / pathLen, 0, 1)
		local wp = WorldSetup.pointAt(t)
		if e.model then
			moveModel(e.model, wp + Vector3.new(0, e.isBoss and 3 or 1.5, 0))
		end
	end
	return hit
end

function EnemyManager.clearAll()
	for id in State.enemies do
		EnemyManager.remove(id)
	end
end

return EnemyManager
