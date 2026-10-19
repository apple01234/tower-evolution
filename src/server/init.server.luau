--!strict
-- 서버 진입점. 모든 서버 시스템을 순서대로 초기화한다.
local Players = game:GetService("Players")

local Save = require(script.Parent:WaitForChild("Save"))
local Battle = require(script.Parent:WaitForChild("Battle"))

print("[TowerEvolution] 서버 시작")

-- 플레이어 입장 시 데이터 로드 + 최초 동기화
Players.PlayerAdded:Connect(function(player)
	local st = Save.load(player)
	print(string.format("[TowerEvolution] %s 로드 — 골드 %d, 타워 %d", player.Name, st.gold, #st.slots))

	-- 클라이언트가 RemoteEvent 연결을 마칠 시간을 준 뒤 전송
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
