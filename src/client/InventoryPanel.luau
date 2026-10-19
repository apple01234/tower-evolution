--!strict
-- 인벤토리 패널: 보유 타워 카드, 선택, 소환/합성 버튼
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local TowerData = require(Shared:WaitForChild("TowerData"))

local UI = require(script.Parent:WaitForChild("UiKit"))
local TowerCard = require(script.Parent:WaitForChild("TowerCard"))

local InventoryPanel = {}

local selected: { [string]: boolean } = {}
local slots: { any } = {}
local cards: { [string]: any } = {}

local scroll: ScrollingFrame
local fuseBtn: TextButton

local onSummon: (family: string) -> () = function() end
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

	-- 계열 선택 소환 (3계열)
	local FAMILY_BTNS = {
		{ key = "Arcane", label = "아케인", color = Color3.fromRGB(90, 110, 220) },
		{ key = "Frost", label = "서리", color = Color3.fromRGB(80, 170, 210) },
		{ key = "Inferno", label = "화염", color = Color3.fromRGB(200, 90, 60) },
	}

	local familyRow = mk(panel, "Frame", {
		Name = "FamilyRow",
		Size = UDim2.new(1, -28, 0, 34),
		Position = UDim2.new(0, 14, 1, -96),
		BackgroundTransparency = 1,
	})
	mk(familyRow, "UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
	})

	for i, fb in FAMILY_BTNS do
		local b = mk(familyRow, "TextButton", {
			Name = fb.key,
			Size = UDim2.new(0, 100, 1, 0),
			LayoutOrder = i,
			BackgroundColor3 = fb.color,
			BorderSizePixel = 0,
			Font = Enum.Font.GothamBold,
			TextSize = 14,
			TextColor3 = Color3.fromRGB(255, 255, 255),
			Text = "소환·" .. fb.label,
		})
		b.Activated:Connect(function()
			onSummon(fb.key)
		end)
	end

	fuseBtn = mkButton("선택 합성", Color3.fromRGB(120, 80, 200), 2)

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
		cards[s.uid] = TowerCard.create(scroll, {
			uid = s.uid,
			key = s.key,
			order = i,
			count = counts[s.key] or 0,
			selected = selected[s.uid] == true,
			onToggle = function(uid, canFuse, card)
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
			end,
		})
	end
end

return InventoryPanel
