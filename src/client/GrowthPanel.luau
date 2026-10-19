--!strict
-- 성장 패널 (환생 / 영구 연구)
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))

local UI = require(script.Parent:WaitForChild("UiKit"))

local GrowthPanel = {}

local RESEARCH_KEYS = { "goldGain", "towerDamage", "summonCost", "evolveMaterial" }
local RESEARCH_NAMES = {
	goldGain = "골드 획득량",
	towerDamage = "타워 공격력",
	summonCost = "소환 비용 절감",
	evolveMaterial = "진화 재료 획득",
}

local state: any = nil
local open = false
local panel: Frame
local summary: TextLabel
local pointLabel: TextLabel
local scroll: ScrollingFrame
local rows: { [string]: any } = {}

function GrowthPanel.build(parent: Instance)
	local size, pos = UI.panelBounds(340)
	panel = UI.mk(parent, "Frame", {
		Name = "GrowthPanel",
		Size = size,
		Position = pos,
		BackgroundColor3 = Color3.fromRGB(16, 18, 26),
		BorderSizePixel = 0,
		Visible = false,
	})
	UI.panelHeader(panel, "성장", Color3.fromRGB(240, 220, 150))

	summary = UI.mk(panel, "TextLabel", {
		Size = UDim2.new(1, -20, 0, 20),
		Position = UDim2.new(0, 12, 0, 36),
		BackgroundTransparency = 1,
		Font = Enum.Font.Gotham,
		TextSize = 13,
		TextColor3 = Color3.fromRGB(170, 180, 200),
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "환생 0회",
	})

	pointLabel = UI.mk(panel, "TextLabel", {
		Size = UDim2.new(1, -20, 0, 20),
		Position = UDim2.new(0, 12, 0, 56),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextSize = 14,
		TextColor3 = Color3.fromRGB(140, 220, 255),
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "연구 포인트: 0",
	})

	scroll = UI.scrollList(panel, 80, -132)

	local rebirthBtn = UI.mk(panel, "TextButton", {
		Size = UDim2.new(1, -24, 0, 40),
		Position = UDim2.new(0, 12, 1, -50),
		BackgroundColor3 = Color3.fromRGB(160, 60, 60),
		BorderSizePixel = 0,
		Font = Enum.Font.GothamBold,
		TextSize = 15,
		TextColor3 = Color3.fromRGB(255, 255, 255),
		Text = "환생",
	})
	rebirthBtn.Activated:Connect(function()
		local ev = Net.get("RequestRebirth")
		if ev then
			ev:FireServer()
		end
	end)

	local closeBtn = UI.panelCloseButton(panel)
	closeBtn.Activated:Connect(function()
		open = false
		panel.Visible = false
	end)
end

function GrowthPanel.setData(payload: any)
	state = payload
	GrowthPanel.render()
end

function GrowthPanel.toggle()
	open = not open
	panel.Visible = open
	if open then
		GrowthPanel.render()
	end
end

local function rowFor(key: string): any
	local row = rows[key]
	if row then
		return row
	end
	local btn = UI.mk(scroll, "TextButton", {
		Name = key,
		Size = UDim2.new(1, -8, 0, 36),
		BackgroundColor3 = Color3.fromRGB(30, 34, 46),
		BorderSizePixel = 0,
		Font = Enum.Font.Gotham,
		TextSize = 13,
		TextColor3 = Color3.fromRGB(225, 232, 245),
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "",
	})
	btn.Activated:Connect(function()
		local ev = Net.get("RequestResearch")
		if ev then
			ev:FireServer(key)
		end
	end)
	rows[key] = btn
	return btn
end

function GrowthPanel.render()
	if not state then
		return
	end
	summary.Text = state.summary or ""
	pointLabel.Text = string.format("연구 포인트: %d", state.points or 0)

	for _, key in RESEARCH_KEYS do
		local row = rowFor(key)
		local lv = (state.research or {})[key] or 0
		local cost = (state.costs or {})[key]
		local costText = cost and string.format(" · %dpt", cost) or " · MAX"
		row.Text = string.format("  %s  Lv.%d%s", RESEARCH_NAMES[key] or key, lv, costText)
		row.BackgroundColor3 = (cost and (state.points or 0) >= cost)
			and Color3.fromRGB(40, 70, 55)
			or Color3.fromRGB(30, 34, 46)
	end
end

return GrowthPanel
