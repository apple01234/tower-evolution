--!strict
-- 타워 카드 UI (인벤토리 1칸). 선택 상태는 호출자가 관리한다.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local TowerData = require(Shared:WaitForChild("TowerData"))

local UI = require(script.Parent:WaitForChild("UiKit"))

local TowerCard = {}

export type Opts = {
	uid: string,
	key: string,
	order: number,
	count: number,
	selected: boolean,
	onToggle: (uid: string, canFuse: boolean, card: Instance) -> (),
}

function TowerCard.create(parent: Instance, o: Opts): Instance
	local def = TowerData.get(o.key)
	local canFuse = def ~= nil and #TowerData.nextOptions(o.key) > 0

	local card = UI.mk(parent, "TextButton", {
		Name = o.uid,
		Size = UDim2.new(0, 146, 0, 80),
		LayoutOrder = o.order,
		BackgroundColor3 = o.selected and Color3.fromRGB(70, 55, 120) or Color3.fromRGB(28, 32, 44),
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
		Text = def and def.name or o.key,
	})
	UI.mk(card, "TextLabel", {
		Size = UDim2.new(1, -12, 0, 16),
		Position = UDim2.new(0, 6, 0, 24),
		BackgroundTransparency = 1,
		Font = Enum.Font.Gotham,
		TextSize = 11,
		TextColor3 = Color3.fromRGB(160, 170, 195),
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = def and string.format("%s T%d · %s", def.family, def.tier, def.attackKind) or "",
	})
	UI.mk(card, "TextLabel", {
		Size = UDim2.new(1, -12, 0, 15),
		Position = UDim2.new(0, 6, 0, 42),
		BackgroundTransparency = 1,
		Font = Enum.Font.Gotham,
		TextSize = 11,
		TextColor3 = canFuse and Color3.fromRGB(150, 220, 255) or Color3.fromRGB(110, 115, 130),
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = canFuse
			and (TowerData.requiresChoice(o.key) and "분기 선택" or "합성 가능")
			or "최종 단계",
	})
	UI.mk(card, "TextLabel", {
		Size = UDim2.new(1, -12, 0, 15),
		Position = UDim2.new(0, 6, 0, 58),
		BackgroundTransparency = 1,
		Font = Enum.Font.Gotham,
		TextSize = 11,
		TextColor3 = Color3.fromRGB(200, 180, 120),
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = string.format("보유 %d개", o.count),
	})

	card.Activated:Connect(function()
		o.onToggle(o.uid, canFuse, card)
	end)

	return card
end

return TowerCard
