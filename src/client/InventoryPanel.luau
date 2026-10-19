--!strict
-- 인벤토리 패널: 보유 타워 카드, 선택, 소환/합성 버튼
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local TowerData = require(Shared:WaitForChild("TowerData"))

local UI = require(script.Parent:WaitForChild("UiKit"))

local InventoryPanel = {}

local selected: { [string]: boolean } = {}
local slots: { any } = {}
local cards: { [string]: any } = {}

local scroll: ScrollingFrame
local summonBtn: TextButton
local fuseBtn: TextButton

local onSummon: () -> () = function() end
local onFuse: (uids: { string }) -> () = function() end

function InventoryPanel.build(parent: Instance, handlers: { onSummon: any, onFuse: any })
	onSummon = handlers.onSummon
	onFuse = handlers.onFuse
	local mk = UI.mk

	local panel = mk(parent, "Frame", {
		Name = "Panel",
		Size = UDim2.new(1, 0, 0.26, 0),
		Position = UDim2.new(0, 0, 0.74, 0),
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

	scroll = mk(panel, "ScrollingFrame", {
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
	mk(scroll, "UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
	})
	mk(scroll, "UIPadding", { PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 4) })

	local btnRow = mk(panel, "Frame", {
		Name = "Buttons",
		Size = UDim2.new(1, -28, 0, 44),
		Position = UDim2.new(0, 14, 1, -54),
		BackgroundTransparency = 1,
	})
	mk(btnRow, "UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
	})

	local function mkButton(text: string, color: Color3, order: number): TextButton
		return mk(btnRow, "TextButton", {
			Name = text,
			Size = UDim2.new(0, 118, 1, 0),
			LayoutOrder = order,
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			Font = Enum.Font.GothamBold,
			TextSize = 15,
			TextColor3 = Color3.fromRGB(255, 255, 255),
			Text = text,
		})
	end

	summonBtn = mkButton("타워 소환", Color3.fromRGB(50, 120, 80), 1)
	fuseBtn = mkButton("선택 합성", Color3.fromRGB(120, 80, 200), 2)

	summonBtn.Activated:Connect(function()
		onSummon()
	end)

	fuseBtn.Activated:Connect(function()
		local uids = {}
		for uid in selected do
			table.insert(uids, uid)
		end
		if #uids ~= 3 then
			UI.showNotify("같은 타워 3개를 선택하세요.", "bad")
			return
		end
		local keys = {}
		for _, uid in uids do
			for _, s in slots do
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
			UI.showNotify("서로 다른 타워는 합성할 수 없습니다.", "bad")
			return
		end
		onFuse(uids)
		selected = {}
		InventoryPanel.render()
	end)
end

local function cardFor(uid: string, key: string, order: number, count: number): any
	local def = TowerData.get(key)
	local canFuse = def ~= nil and def.nextKey ~= nil

	local card = UI.mk(scroll, "TextButton", {
		Name = uid,
		Size = UDim2.new(0, 146, 0, 80),
		LayoutOrder = order,
		BackgroundColor3 = selected[uid] and Color3.fromRGB(70, 55, 120) or Color3.fromRGB(28, 32, 44),
		BorderSizePixel = 0,
		AutoButtonColor = true,
		Text = "",
	})

	UI.mk(card, "TextLabel", {
		Size = UDim2.new(1, -12, 0, 20),
		Position = UDim2.new(0, 6, 0, 4),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextSize = 14,
		TextColor3 = Color3.fromRGB(240, 245, 255),
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = def and def.name or key,
	})
	UI.mk(card, "TextLabel", {
		Size = UDim2.new(1, -12, 0, 16),
		Position = UDim2.new(0, 6, 0, 24),
		BackgroundTransparency = 1,
		Font = Enum.Font.Gotham,
		TextSize = 11,
		TextColor3 = Color3.fromRGB(160, 170, 195),
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = def and string.format("T%d · %s", def.tier, def.attackKind) or "",
	})
	UI.mk(card, "TextLabel", {
		Size = UDim2.new(1, -12, 0, 15),
		Position = UDim2.new(0, 6, 0, 42),
		BackgroundTransparency = 1,
		Font = Enum.Font.Gotham,
		TextSize = 11,
		TextColor3 = canFuse and Color3.fromRGB(150, 220, 255) or Color3.fromRGB(110, 115, 130),
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = canFuse and "합성 가능" or "최종 단계",
	})
	UI.mk(card, "TextLabel", {
		Size = UDim2.new(1, -12, 0, 15),
		Position = UDim2.new(0, 6, 0, 58),
		BackgroundTransparency = 1,
		Font = Enum.Font.Gotham,
		TextSize = 11,
		TextColor3 = Color3.fromRGB(200, 180, 120),
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = string.format("보유 %d개", count),
	})

	card.Activated:Connect(function()
		if not canFuse then
			return
		end
		if selected[uid] then
			selected[uid] = nil
			card.BackgroundColor3 = Color3.fromRGB(28, 32, 44)
		else
			local n = 0
			for _ in selected do
				n += 1
			end
			if n >= 3 then
				UI.showNotify("최대 3개까지 선택할 수 있습니다.", "bad")
				return
			end
			selected[uid] = true
			card.BackgroundColor3 = Color3.fromRGB(70, 55, 120)
		end
	end)

	return card
end

function InventoryPanel.setSlots(newSlots: { any })
	slots = newSlots or {}
	-- 서버에 없는 uid 선택 해제
	local valid = {}
	for _, s in slots do
		valid[s.uid] = true
	end
	for uid in selected do
		if not valid[uid] then
			selected[uid] = nil
		end
	end
	InventoryPanel.render()
end

function InventoryPanel.render()
	for _, child in scroll:GetChildren() do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end
	cards = {}

	local counts: { [string]: number } = {}
	for _, s in slots do
		counts[s.key] = (counts[s.key] or 0) + 1
	end
	for i, s in slots do
		cards[s.uid] = cardFor(s.uid, s.key, i, counts[s.key] or 0)
	end
end

return InventoryPanel
