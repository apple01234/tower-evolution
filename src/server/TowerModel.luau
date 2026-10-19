--!strict
-- 타워 3D 모델 생성. 마켓플레이스 에셋 우선, 실패 시 파트 폴백.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")

local AssetLoader = require(script.Parent:WaitForChild("AssetLoader"))

local TowerModel = {}

local TOWER_SIZE = Vector3.new(4, 6, 4)
local FALLBACK_SIZE = Vector3.new(3, 4, 3)

local function towersFolder(): Instance
	local arena = workspace:FindFirstChild("TowerArena")
	if not arena then
		error("[TowerModel] TowerArena 없음")
	end
	local f = arena:FindFirstChild("Towers")
	if not f then
		local nf = Instance.new("Folder")
		nf.Name = "Towers"
		nf.Parent = arena
		f = nf
	end
	return f
end

-- 모델과 사거리 판정용 위치를 반환
function TowerModel.build(key: string, wp: Vector3): (Instance, Vector3)
	local folder = towersFolder()

	local assetModel = AssetLoader.template(key)
	if assetModel then
		assetModel.Name = key
		AssetLoader.fit(assetModel, TOWER_SIZE)
		AssetLoader.anchor(assetModel)
		AssetLoader.place(assetModel, wp)
		assetModel.Parent = folder

		local pos = wp + Vector3.new(0, 2, 0)
		if assetModel:IsA("PVInstance") then
			local okPivot, pivot = pcall(function()
				return (assetModel :: any):GetPivot()
			end)
			if okPivot and typeof(pivot) == "CFrame" then
				pos = pivot.Position
			end
		end
		return assetModel, pos
	end

	local part = Instance.new("Part")
	part.Name = key
	part.Size = FALLBACK_SIZE
	part.Position = wp + Vector3.new(0, 2, 0)
	part.Anchored = true
	part.CanCollide = false
	part.Material = Enum.Material.Metal
	part.Color = Color3.fromRGB(90, 140, 220)
	part.Parent = folder
	return part, part.Position
end

return TowerModel
