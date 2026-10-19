--!strict
-- 미션 패널 (일일 / 주간)
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))

local UI = require(script.Parent:WaitForChild("UiKit"))

local MissionPanel = {}

local DAILY_ORDER = { "d_kill_30", "d_wave_5", "d_summon_3", "d_fuse_1" }
local WEEKLY_ORDER = { "w_kill_500", "w_fuse_10", "w_boss_1", "w_wave_30" }

local state: any = nil
local open = false
local panel: Frame
local resetLabel: TextLabel
local scroll: ScrollingFrame
local rows: { [string]: any } = {}

local function remainingText(targetUnix: number): string
	local d = targetUnix - os.time()
	if d <= 0 then
		return "곧 갱신"
	end
	local h = math.floor(d / 3600)
	local m = math.floor((d % 3600) / 60)
	if h >= 24 then
		return string.format("%d일 %d시간 후", math.floor(h / 24), h % 24)
	end
	return string.format("%d시간 %d분 후", h, m)
end

function MissionPanel.build(parent: Instance)
	local size, pos = UI.panelBounds(360)
	panel = UI.mk(parent, "Frame", {
		Name = "MissionPanel",
		Size = size,
		Position = pos,
		BackgroundColor3 = Color3.fromRGB(16, 18, 26),
		BorderSizePixel = 0,
		Visible = false,
	})
	UI.panelHeader(panel, "미션", Color3.fromRGB(150, 210, 255))

	resetLabel = UI.mk(panel, "TextLabel", {
		Size = UDim2.new(1, -64, 0, 18),
		Position = UDim2.new(0, 12, 0, 34),
		BackgroundTransparency = 1,
		Font = Enum.Font.Gotham,
		TextSize = 12,
		TextColor3 = Color3.fromRGB(150, 160, 180),
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "",
	})

	scroll = UI.scrollList(panel, 58, -70)

	local closeBtn = UI.panelCloseButton(panel)
	closeBtn.Activated:Connect(function()
		open = false
		panel.Visible = false
	end)
end

function MissionPanel.setData(payload: any)
	state = payload
	MissionPanel.render()
end

function MissionPanel.toggle()
	open = not open
	panel.Visible = open
	if open then
		MissionPanel.render()
	end
end

local function rowFor(key: string): any
	local row = rows[key]
	if row then
		return row
	end
	local btn = UI.mk(scroll, "TextButton", {
		Name = key,
		Size = UDim2.new(1, -8, 0, 52),
		BackgroundColor3 = Color3.fromRGB(30, 34, 46),
		BorderSizePixel = 0,
		Font = Enum.Font.Gotham,
		TextSize = 12,
		TextColor3 = Color3.fromRGB(225, 232, 245),
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "",
	})
	btn.Activated:Connect(function()
		local ev = Net.get("RequestClaimMission")
		if ev then
			ev:FireServer(key)
		end
	end)
	rows[key] = btn
	return btn
end

local function renderBucket(bucket: any, order: { string }, prefix: string)
	for i, key in order do
		local m = bucket and bucket[key]
		if not m then
			continue
		end
		local row = rowFor(key)
		row.LayoutOrder = (prefix == "d" and 0 or 100) + i

		local status = m.claimed and "[수령완료]"
			or m.claimable and "[수령가능]"
			or m.complete and "[완료]"
			or ""
		row.Text = string.format("  %s %s\n   %d/%d · %dG  %s",
			prefix == "d" and "일일" or "주간", m.title or key,
			m.progress or 0, m.target or 0, m.reward or 0, status)
		row.TextColor3 = m.claimable
			and Color3.fromRGB(180, 255, 190)
			or m.claimed
			and Color3.fromRGB(120, 125, 140)
			or Color3.fromRGB(225, 232, 245)
		row.BackgroundColor3 = m.claimable
			and Color3.fromRGB(35, 70, 50)
			or Color3.fromRGB(30, 34, 46)
	end
end

function MissionPanel.render()
	if not state then
		return
	end
	resetLabel.Text = "일일 " .. remainingText(state.dailyReset or 0)
		.. " · 주간 " .. remainingText(state.weeklyReset or 0)
	renderBucket(state.daily, DAILY_ORDER, "d")
	renderBucket(state.weekly, WEEKLY_ORDER, "w")
end

return MissionPanel
