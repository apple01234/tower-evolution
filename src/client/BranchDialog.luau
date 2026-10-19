--!strict
-- 분기 진화 선택 팝업. 3단계 타워에서 두 방향 중 하나를 고른다.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local TowerData = require(Shared:WaitForChild("TowerData"))

local UI = require(script.Parent:WaitForChild("UiKit"))

local BranchDialog = {}

local panel: Frame
local titleLabel: TextLabel
local optionRow: Frame
local pendingUids: { string } = {}
local onChoose: (uids: { string }, chosen: string) -> () = function() end

function BranchDialog.build(parent: Instance, chooseHandler: any)
	onChoose = chooseHandler

	panel = UI.mk(parent, "Frame", {
		Name = "BranchDialog",
		Size = UDim2.new(0.76, 0, 0, 220),
		Position = UDim2.new(0.12, 0, 0.5, -110),
		BackgroundColor3 = Color3.fromRGB(18, 20, 30),
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 10,
	})

	titleLabel = UI.mk(panel, "TextLabel", {
		Size = UDim2.new(1, -20, 0, 30),
		Position = UDim2.new(0, 12, 0, 10),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextSize = 17,
		TextColor3 = Color3.fromRGB(245, 225, 150),
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "진화 방향 선택",
	})

	optionRow = UI.mk(panel, "Frame", {
		Name = "Options",
		Size = UDim2.new(1, -24, 0, 110),
		Position = UDim2.new(0, 12, 0, 48),
		BackgroundTransparency = 1,
	})
	UI.mk(optionRow, "UIListLayout", {
		FillDirection = Enum.FillDirection.Vertical,
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
	})

	local cancel = UI.mk(panel, "TextButton", {
		Size = UDim2.new(1, -24, 0, 34),
		Position = UDim2.new(0, 12, 1, -46),
		BackgroundColor3 = Color3.fromRGB(60, 64, 78),
		BorderSizePixel = 0,
		Font = Enum.Font.GothamBold,
		TextSize = 14,
		TextColor3 = Color3.fromRGB(220, 225, 235),
		Text = "취소",
	})
	cancel.Activated:Connect(function()
		BranchDialog.close()
	end)
end

-- 타워 key에 대해 선택 가능한 분기를 표시. 선택지가 1개 이하면 false 반환.
function BranchDialog.open(uids: { string }, key: string): boolean
	local options = TowerData.nextOptions(key)
	if #options < 2 then
		return false
	end

	pendingUids = uids
	titleLabel.Text = string.format("진화 방향 선택 — %s", (TowerData.get(key) or { name = key }).name)

	-- 기존 옵션 버튼 제거
	for _, child in optionRow:GetChildren() do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end

	for i, optKey in options do
		local d = TowerData.get(optKey)
		local dps = d and (d.damage * d.attackSpeed) or 0
		local detail = d and string.format(
			"%s T%d · DPS %.0f · %s · 사거리 %d",
			d.family, d.tier, dps, d.attackKind, d.range
		) or optKey

		local btn = UI.mk(optionRow, "TextButton", {
			Name = optKey,
			Size = UDim2.new(1, -8, 0, 50),
			LayoutOrder = i,
			BackgroundColor3 = Color3.fromRGB(34, 40, 58),
			BorderSizePixel = 0,
			Font = Enum.Font.Gotham,
			TextSize = 13,
			TextColor3 = Color3.fromRGB(230, 238, 250),
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = string.format("  %s\n   %s", d and d.name or optKey, detail),
		})
		btn.Activated:Connect(function()
			local chosen = optKey
			local sendUids = pendingUids
			BranchDialog.close()
			onChoose(sendUids, chosen)
		end)
	end

	panel.Visible = true
	return true
end

function BranchDialog.close()
	panel.Visible = false
	pendingUids = {}
end

return BranchDialog
