--!strict
-- 서버 진입점. 모든 서버 시스템을 순서대로 초기화한다.
--
-- 견고성 원칙:
--   WaitForChild 는 무한 대기하므로 타임아웃을 준다.
--   모듈이 없으면 조용히 멈추지 말고 "무엇이 없는지" 명확히 로그에 남긴다.

local Players = game:GetService("Players")

local MODULE_TIMEOUT = 10

-- 타임아웃 있는 require. 실패 시 nil + 사유.
local function need(name: string): any?
	local parent = script
	if not parent then
		warn(string.format("[TowerEvolution] script 없음 (모듈 %s)", name))
		return nil
	end

	local child = parent:FindFirstChild(name)
	if not child then
		-- 아직 복제 중일 수 있으므로 잠깐 기다린다
		child = parent:WaitForChild(name, MODULE_TIMEOUT)
	end

	if not child then
		local available = {}
		for _, c in parent:GetChildren() do
			table.insert(available, c.Name)
		end
		warn(string.format(
			"[TowerEvolution] 모듈 '%s' 를 %d초 안에 찾지 못했습니다. 사용 가능: %s",
			name, MODULE_TIMEOUT, table.concat(available, ", ")
		))
		return nil
	end

	local ok, mod = pcall(require, child)
	if not ok then
		warn(string.format("[TowerEvolution] require('%s') 실패: %s", name, tostring(mod)))
		return nil
	end
	return mod
end

print("[TowerEvolution] 서버 시작")

local Save = need("Save")
local Battle = need("Battle")

if not Save or not Battle then
	warn("[TowerEvolution] 핵심 모듈 누락 — 초기화 중단")
	return
end

-- 플레이어 입장 시 데이터 로드 + 최초 동기화
Players.PlayerAdded:Connect(function(player)
	local st = Save.load(player)
	print(string.format("[TowerEvolution] %s 로드 — 골드 %d, 타워 %d", player.Name, st.gold, #st.slots))

	task.delay(1.5, function()
		if not player.Parent then
			return
		end
		Battle.syncPlayer(player)
	end)
end)

-- 서버 시작 전에 이미 접속해 있던 플레이어 처리 (Studio 테스트 대비)
for _, player in Players:GetPlayers() do
	task.spawn(function()
		Save.load(player)
		task.wait(1.5)
		if player.Parent then
			Battle.syncPlayer(player)
		end
	end)
end

Battle.init()

print("[TowerEvolution] 전투 시스템 초기화 완료")
