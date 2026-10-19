--!strict
-- 서버 진입점. 모든 서버 시스템을 순서대로 초기화한다.
local Players = game:GetService("Players")

local Save = require(script.Parent:WaitForChild("Save"))
local Battle = require(script.Parent:WaitForChild("Battle"))

print("[TowerEvolution] 서버 시작")

-- 플레이어 입장 시 데이터 로드
Players.PlayerAdded:Connect(function(player)
	local st = Save.load(player)
	print(string.format("[TowerEvolution] %s 로드 — 골드 %d, 타워 %d", player.Name, st.gold, #st.slots))
end)

Battle.init()

print("[TowerEvolution] 전투 시스템 초기화 완료")
