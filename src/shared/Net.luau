--!strict
-- 서버-클라이언트 통신 정의. 모든 요청은 서버에서 재검증된다.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Net = {}

local EVENTS = {
	"RequestSummon", -- () -> 서버가 골드 차감 후 타워 지급
	"RequestFuse", -- (uids: {string})
	"RequestPlace", -- (uid: string, col: number, row: number)
	"RequestPickup", -- (col, row)
	"RequestUpgrade", -- (uid: string)
	"RequestSell", -- (uid: string)
	"RequestRebirth", -- () 환생
	"RequestResearch", -- (key: string) 연구 구매
	"RequestZone", -- (zoneId: string) 지역 이동
	"RequestClaimMission", -- (key: string) 미션 보상 수령

	"StateSync", -- (state) 서버 -> 클라이언트
	"WaveSync", -- (wave, isBoss, bossHp, bossMaxHp)
	"ProgressSync", -- (progress) 서버 -> 클라이언트
	"MissionSync", -- (missions) 서버 -> 클라이언트
	"Notify", -- (msg, kind)
}

function Net.init(): { [string]: RemoteEvent }
	local folder = ReplicatedStorage:FindFirstChild("SertzNet")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "SertzNet"
		folder.Parent = ReplicatedStorage
	end

	local map: { [string]: RemoteEvent } = {}
	for _, name in EVENTS do
		local ev = (folder :: Folder):FindFirstChild(name)
		if not ev then
			ev = Instance.new("RemoteEvent")
			ev.Name = name
			ev.Parent = folder
		end
		map[name] = ev :: RemoteEvent
	end
	return map
end

function Net.get(name: string): RemoteEvent?
	if RunService:IsServer() then
		local folder = ReplicatedStorage:FindFirstChild("SertzNet")
		if not folder then
			return nil
		end
		return (folder :: Folder):FindFirstChild(name) :: RemoteEvent?
	end
	local folder = ReplicatedStorage:WaitForChild("SertzNet", 30)
	if not folder then
		return nil
	end
	return (folder :: Folder):WaitForChild(name, 30) :: RemoteEvent?
end

return Net
