--!strict
-- 클라이언트 UI. 서버가 보낸 상태만 표시하고, 모든 요청은 RemoteEvent로 전달한다.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local TowerData = require(Shared:WaitForChild("TowerData"))
local Net = require(Shared:WaitForChild("Net"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local events = {}

local function mk(parent: Instance, class: string, props: { [string]: any }): any
	local inst = Instance.new(class)
	for k, v in props do
		if k ~= "Parent" then
			(inst :: any)[k] = v
		end
	end
	inst.Parent = parent
	return inst
end

-- ============ 상태 ============
local state = { gold = 0, slots = {}, wave = 0 }
local isBoss = false
local bossHp, bossMax = 0, 0
local baseHp, baseMax = 100, 100
local selectedFuse: { [string]: boolean } = {}
local progressState: any = nil
local growthOpen = false

-- ============ GUI ============
local gui = mk(playerGui, "ScreenGui", {
	Name = "TowerGui",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
})

-- 상단 HUD
local hud = mk(gui, "Frame", {
	Name = "HUD",
	Size = UDim2.new(1, 0, 0, 56),
	Position = UDim2.new(0, 0, 0, 0),
	BackgroundColor3 = Color3.fromRGB(18, 20, 28),
	BackgroundTransparency = 0.15,
	BorderSizePixel = 0,
})

local goldLabel = mk(hud, "TextLabel", {
	Name = "Gold",
	Size = UDim2.new(0, 220, 1, 0),
	Position = UDim2.new(0, 16, 0, 0),
	BackgroundTransparency = 1,
	Font = Enum.Font.GothamBold,
	TextSize = 22,
	TextColor3 = Color3.fromRGB(255, 214, 92),
	TextXAlignment = Enum.TextXAlignment.Left,
	Text = "골드: 0",
})

local waveLabel = mk(hud, "TextLabel", {
	Name = "Wave",
	Size = UDim2.new(0, 320, 1, 0),
	Position = UDim2.new(0.5, -160, 0, 0),
	BackgroundTransparency = 1,
	Font = Enum.Font.GothamBold,
	TextSize = 20,
	TextColor3 = Color3.fromRGB(230, 235, 245),
	Text = "웨이브 0",
})

local baseLabel = mk(hud, "TextLabel", {
	Name = "Base",
	Size = UDim2.new(0, 220, 1, 0),
	Position = UDim2.new(1, -236, 0, 0),
	BackgroundTransparency = 1,
	Font = Enum.Font.Gotham,
	TextSize = 18,
	TextColor3 = Color3.fromRGB(150, 220, 255),
	TextXAlignment = Enum.TextXAlignment.Right,
	Text = "기지: 100",
})

-- 보스 바
local bossBar = mk(gui, "Frame", {
	Name = "BossBar",
	Size = UDim2.new(0.6, 0, 0, 26),
	Position = UDim2.new(0.2, 0, 0, 64),
	BackgroundColor3 = Color3.fromRGB(40, 12, 12),
	BorderSizePixel = 0,
	Visible = false,
})
local bossFill = mk(bossBar, "Frame", {
	Name = "Fill",
	Size = UDim2.new(1, 0, 1, 0),
	BackgroundColor3 = Color3.fromRGB(210, 50, 50),
	BorderSizePixel = 0,
})
local bossText = mk(bossBar, "TextLabel", {
	Name = "Label",
	Size = UDim2.new(1, 0, 1, 0),
	BackgroundTransparency = 1,
	Font = Enum.Font.GothamBold,
	TextSize = 16,
	TextColor3 = Color3.fromRGB(255, 255, 255),
	Text = "BOSS",
})

-- 하단 패널 (인벤토리 + 버튼)
local panel = mk(gui, "Frame", {
	Name = "Panel",
	Size = UDim2.new(1, 0, 0, 190),
	Position = UDim2.new(0, 0, 1, -190),
	BackgroundColor3 = Color3.fromRGB(14, 16, 22),
	BackgroundTransparency = 0.1,
	BorderSizePixel = 0,
})

mk(panel, "TextLabel", {
	Name = "Title",
	Size = UDim2.new(0, 200, 0, 26),
	Position = UDim2.new(0, 14, 0, 6),
	BackgroundTransparency = 1,
	Font = Enum.Font.GothamBold,
	TextSize = 16,
	TextColor3 = Color3.fromRGB(200, 210, 230),
	TextXAlignment = Enum.TextXAlignment.Left,
	Text = "보유 타워",
})

-- 스크롤 인벤토리
local scroll = mk(panel, "ScrollingFrame", {
	Name = "Inventory",
	Size = UDim2.new(1, -28, 0, 96),
	Position = UDim2.new(0, 14, 0, 34),
	BackgroundTransparency = 1,
	CanvasSize = UDim2.new(0, 0, 0, 0),
	ScrollBarThickness = 6,
	BorderSizePixel = 0,
	AutomaticCanvasSize = Enum.AutomaticSize.X,
	ScrollDirection = Enum.ScrollDirection.Horizontal,
})
local list = mk(scroll, "UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal,
	Padding = UDim.new(0, 8),
	SortOrder = Enum.SortOrder.LayoutOrder,
})
mk(scroll, "UIPadding", { PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 4) })

-- 버튼 영역
local btnRow = mk(panel, "Frame", {
	Name = "Buttons",
	Size = UDim2.new(1, -28, 0, 44),
	Position = UDim2.new(0, 14, 0, 138),
	BackgroundTransparency = 1,
})
mk(btnRow, "UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal,
	Padding = UDim.new(0, 10),
	SortOrder = Enum.SortOrder.LayoutOrder,
})

local function mkButton(text: string, color: Color3, order: number): TextButton
	return mk(btnRow, "TextButton", {
		Name = text,
		Size = UDim2.new(0, 150, 1, 0),
		LayoutOrder = order,
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		Font = Enum.Font.GothamBold,
		TextSize = 16,
		TextColor3 = Color3.fromRGB(255, 255, 255),
		Text = text,
	})
end

local summonBtn = mkButton("타워 소환", Color3.fromRGB(50, 120, 80), 1)
local fuseBtn = mkButton("선택 합성", Color3.fromRGB(120, 80, 200), 2)
local growthBtn = mkButton("성장", Color3.fromRGB(200, 140, 40), 3)

-- ============ 성장 패널 (환생 / 연구 / 도감) ============
local growthPanel = mk(gui, "Frame", {
	Name = "GrowthPanel",
	Size = UDim2.new(0, 460, 0, 340),
	Position = UDim2.new(0.5, -230, 0.5, -170),
	BackgroundColor3 = Color3.fromRGB(16, 18, 26),
	BorderSizePixel = 0,
	Visible = false,
})

mk(growthPanel, "TextLabel", {
	Size = UDim2.new(1, -20, 0, 28),
	Position = UDim2.new(0, 12, 0, 8),
	BackgroundTransparency = 1,
	Font = Enum.Font.GothamBold,
	TextSize = 18,
	TextColor3 = Color3.fromRGB(240, 220, 150),
	TextXAlignment = Enum.TextXAlignment.Left,
	Text = "성장",
})

local growthSummary = mk(growthPanel, "TextLabel", {
	Size = UDim2.new(1, -20, 0, 20),
	Position = UDim2.new(0, 12, 0, 36),
	BackgroundTransparency = 1,
	Font = Enum.Font.Gotham,
	TextSize = 13,
	TextColor3 = Color3.fromRGB(170, 180, 200),
	TextXAlignment = Enum.TextXAlignment.Left,
	Text = "환생 0회 · 최고 웨이브 0 · 도감 0",
})

local pointLabel = mk(growthPanel, "TextLabel", {
	Size = UDim2.new(1, -20, 0, 20),
	Position = UDim2.new(0, 12, 0, 56),
	BackgroundTransparency = 1,
	Font = Enum.Font.GothamBold,
	TextSize = 14,
	TextColor3 = Color3.fromRGB(140, 220, 255),
	TextXAlignment = Enum.TextXAlignment.Left,
	Text = "연구 포인트: 0",
})

-- 연구 목록
local researchScroll = mk(growthPanel, "ScrollingFrame", {
	Size = UDim2.new(1, -24, 0, 180),
	Position = UDim2.new(0, 12, 0, 80),
	BackgroundTransparency = 1,
	CanvasSize = UDim2.new(0, 0, 0, 0),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	ScrollBarThickness = 6,
	BorderSizePixel = 0,
})
mk(researchScroll, "UIListLayout", {
	Padding = UDim.new(0, 6),
	SortOrder = Enum.SortOrder.LayoutOrder,
})

local rebirthBtn = mk(growthPanel, "TextButton", {
	Size = UDim2.new(1, -24, 0, 38),
	Position = UDim2.new(0, 12, 1, -52),
	BackgroundColor3 = Color3.fromRGB(160, 60, 60),
	BorderSizePixel = 0,
	Font = Enum.Font.GothamBold,
	TextSize = 15,
	TextColor3 = Color3.fromRGB(255, 255, 255),
	Text = "환생",
})

local closeBtn = mk(growthPanel, "TextButton", {
	Size = UDim2.new(0, 28, 0, 28),
	Position = UDim2.new(1, -36, 0, 8),
	BackgroundColor3 = Color3.fromRGB(60, 64, 78),
	BorderSizePixel = 0,
	Font = Enum.Font.GothamBold,
	TextSize = 16,
	TextColor3 = Color3.fromRGB(230, 235, 245),
	Text = "X",
})

local researchRows: { [string]: any } = {}

local function renderGrowth()
	if not progressState then
		return
	end
	growthSummary.Text = progressState.summary or ""
	pointLabel.Text = string.format("연구 포인트: %d", progressState.points or 0)

	-- 연구 행 생성/갱신
	for _, key in { "goldGain", "towerDamage", "summonCost", "evolveMaterial" } do
		local row = researchRows[key]
		local lv = (progressState.research or {})[key] or 0
		local cost = (progressState.costs or {})[key]
		if not row then
			local btn = mk(researchScroll, "TextButton", {
				Name = key,
				Size = UDim2.new(1, -8, 0, 38),
				BackgroundColor3 = Color3.fromRGB(30, 34, 46),
				BorderSizePixel = 0,
				Font = Enum.Font.Gotham,
				TextSize = 13,
				TextColor3 = Color3.fromRGB(225, 232, 245),
				TextXAlignment = Enum.TextXAlignment.Left,
				Text = "",
			})
			row = btn
			researchRows[key] = btn
			btn.Activated:Connect(function()
				local ev = Net.get("RequestResearch")
				if ev then
					ev:FireServer(key)
				end
			end)
		end
		local names = {
			goldGain = "골드 획득량",
			towerDamage = "타워 공격력",
			summonCost = "소환 비용 절감",
			evolveMaterial = "진화 재료 획득",
		}
		local costText = cost and string.format(" · %dpt", cost) or " · MAX"
		row.Text = string.format("  %s  Lv.%d%s", names[key] or key, lv, costText)
		row.BackgroundColor3 = (cost and (progressState.points or 0) >= cost)
			and Color3.fromRGB(40, 70, 55)
			or Color3.fromRGB(30, 34, 46)
	end
end

-- 알림
local notify = mk(gui, "TextLabel", {
	Name = "Notify",
	Size = UDim2.new(0.8, 0, 0, 34),
	Position = UDim2.new(0.1, 0, 0.42, 0),
	BackgroundTransparency = 1,
	Font = Enum.Font.GothamBold,
	TextSize = 20,
	TextColor3 = Color3.fromRGB(255, 255, 255),
	TextTransparency = 1,
	Text = "",
})

local notifyToken = 0
local function showNotify(msg: string, kind: string)
	notifyToken += 1
	local mine = notifyToken
	notify.Text = msg
	notify.TextColor3 = kind == "bad" and Color3.fromRGB(255, 120, 120)
		or kind == "good" and Color3.fromRGB(140, 255, 160)
		or kind == "boss" and Color3.fromRGB(255, 180, 80)
		or Color3.fromRGB(235, 235, 245)
	notify.TextTransparency = 0
	task.delay(2.2, function()
		if notifyToken == mine then
			notify.TextTransparency = 1
		end
	end)
end

-- ============ 인벤토리 렌더 ============
local cardByUid: { [string]: any } = {}

local function renderInventory()
	for _, child in scroll:GetChildren() do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end
	cardByUid = {}

	local counts: { [string]: number } = {}
	for _, s in state.slots do
		counts[s.key] = (counts[s.key] or 0) + 1
	end

	for i, s in state.slots do
		local def = TowerData.get(s.key)
		local card = mk(scroll, "TextButton", {
			Name = s.uid,
			Size = UDim2.new(0, 150, 0, 88),
			LayoutOrder = i,
			BackgroundColor3 = Color3.fromRGB(28, 32, 44),
			BorderSizePixel = 0,
			AutoButtonColor = true,
			Text = "",
		})
		mk(card, "TextLabel", {
			Size = UDim2.new(1, -12, 0, 22),
			Position = UDim2.new(0, 6, 0, 4),
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBold,
			TextSize = 15,
			TextColor3 = Color3.fromRGB(240, 245, 255),
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = def and def.name or s.key,
		})
		mk(card, "TextLabel", {
			Size = UDim2.new(1, -12, 0, 18),
			Position = UDim2.new(0, 6, 0, 26),
			BackgroundTransparency = 1,
			Font = Enum.Font.Gotham,
			TextSize = 12,
			TextColor3 = Color3.fromRGB(160, 170, 195),
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = def and string.format("T%d · %s", def.tier, def.attackKind) or "",
		})
		local canFuse = def ~= nil and def.nextKey ~= nil
		mk(card, "TextLabel", {
			Size = UDim2.new(1, -12, 0, 16),
			Position = UDim2.new(0, 6, 0, 46),
			BackgroundTransparency = 1,
			Font = Enum.Font.Gotham,
			TextSize = 11,
			TextColor3 = canFuse and Color3.fromRGB(150, 220, 255) or Color3.fromRGB(110, 115, 130),
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = canFuse and "합성 가능" or "최종 단계",
		})
		mk(card, "TextLabel", {
			Size = UDim2.new(1, -12, 0, 16),
			Position = UDim2.new(0, 6, 0, 64),
			BackgroundTransparency = 1,
			Font = Enum.Font.Gotham,
			TextSize = 11,
			TextColor3 = Color3.fromRGB(200, 180, 120),
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = string.format("보유 %d개", counts[s.key] or 0),
		})

		card.Activated:Connect(function()
			if not canFuse then
				return
			end
			if selectedFuse[s.uid] then
				selectedFuse[s.uid] = nil
				card.BackgroundColor3 = Color3.fromRGB(28, 32, 44)
			else
				local n = 0
				for _ in selectedFuse do
					n += 1
				end
				if n >= 3 then
					showNotify("최대 3개까지 선택할 수 있습니다.", "bad")
					return
				end
				selectedFuse[s.uid] = true
				card.BackgroundColor3 = Color3.fromRGB(70, 55, 120)
			end
		end)
		cardByUid[s.uid] = card
	end
end

local function renderHud()
	goldLabel.Text = string.format("골드: %d", state.gold)
	waveLabel.Text = string.format("웨이브 %d", state.wave)
	baseLabel.Text = string.format("기지: %d / %d", math.max(0, baseHp), baseMax)
	if isBoss and bossMax > 0 then
		bossBar.Visible = true
		bossFill.Size = UDim2.new(math.clamp(bossHp / bossMax, 0, 1), 0, 1, 0)
		bossText.Text = string.format("BOSS  %d / %d", math.max(0, bossHp), bossMax)
	else
		bossBar.Visible = false
	end
end

-- ============ 이벤트 연결 ============
local function bindEvents()
	events.StateSync = Net.get("StateSync")
	events.WaveSync = Net.get("WaveSync")
	events.Notify = Net.get("Notify")

	if events.StateSync then
		events.StateSync.OnClientEvent:Connect(function(payload)
			if type(payload) ~= "table" then
				return
			end
			state.gold = payload.gold or state.gold
			state.slots = payload.slots or state.slots
			state.wave = payload.wave or state.wave
			-- 서버에 없는 uid는 선택 해제
			local valid = {}
			for _, s in state.slots do
				valid[s.uid] = true
			end
			for uid in selectedFuse do
				if not valid[uid] then
					selectedFuse[uid] = nil
				end
			end
			renderInventory()
			renderHud()
		end)
	end

	if events.WaveSync then
		events.WaveSync.OnClientEvent:Connect(function(wave, boss, bhp, bmax, hp, hpmax)
			state.wave = wave or state.wave
			isBoss = boss == true
			bossHp = bhp or 0
			bossMax = bmax or 0
			baseHp = hp or baseHp
			baseMax = hpmax or baseMax
			renderHud()
		end)
	end

	if events.Notify then
		events.Notify.OnClientEvent:Connect(function(msg, kind)
			showNotify(tostring(msg), tostring(kind or "info"))
		end)
	end

	local progressEv = Net.get("ProgressSync")
	if progressEv then
		progressEv.OnClientEvent:Connect(function(payload)
			if type(payload) ~= "table" then
				return
			end
			progressState = payload
			renderGrowth()
		end)
	end

	growthBtn.Activated:Connect(function()
		growthOpen = not growthOpen
		growthPanel.Visible = growthOpen
		if growthOpen then
			renderGrowth()
		end
	end)

	closeBtn.Activated:Connect(function()
		growthOpen = false
		growthPanel.Visible = false
	end)

	rebirthBtn.Activated:Connect(function()
		local ev = Net.get("RequestRebirth")
		if ev then
			ev:FireServer()
		end
	end)

	local summonEv = Net.get("RequestSummon")
	local fuseEv = Net.get("RequestFuse")

	summonBtn.Activated:Connect(function()
		if summonEv then
			summonEv:FireServer()
		end
	end)

	fuseBtn.Activated:Connect(function()
		local uids = {}
		for uid in selectedFuse do
			table.insert(uids, uid)
		end
		if #uids ~= 3 then
			showNotify("같은 타워 3개를 선택하세요.", "bad")
			return
		end
		-- 클라이언트 사전 확인 (서버가 최종 검증)
		local keys = {}
		for _, uid in uids do
			for _, s in state.slots do
				if s.uid == uid then
					keys[s.key] = (keys[s.key] or 0) + 1
				end
			end
		end
		local distinct = 0
		for _ in keys do
			distinct += 1
		end
		if distinct ~= 1 then
			showNotify("서로 다른 타워는 합성할 수 없습니다.", "bad")
			return
		end
		if fuseEv then
			fuseEv:FireServer(uids)
		end
		selectedFuse = {}
		renderInventory()
	end)
end

bindEvents()
renderHud()
renderInventory()

-- 모바일/PC 공통 안내
if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
	showNotify("타워를 탭해 선택한 뒤 합성하세요.", "info")
end
