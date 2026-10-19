--!strict
-- 협동 보스 HUD: 화면 상단에 보스 HP 바와 참가자 수를 표시
local UI = require(script.Parent:WaitForChild("UiKit"))

local CoopHud = {}

local panel: Frame
local fill: Frame
local nameLabel: TextLabel
local hpLabel: TextLabel
local participantsLabel: TextLabel

function CoopHud.build(parent: Instance)
	panel = UI.mk(parent, "Frame", {
		Name = "CoopBossBar",
		Size = UDim2.new(0.72, 0, 0, 52),
		Position = UDim2.new(0.14, 0, 0, 100),
		BackgroundColor3 = Color3.fromRGB(26, 10, 18),
		BackgroundTransparency = 0.1,
		BorderSizePixel = 0,
		Visible = false,
	})

	-- 배경 트랙
	UI.mk(panel, "Frame", {
		Name = "Track",
		Size = UDim2.new(1, 0, 0, 22),
		Position = UDim2.new(0, 0, 0, 24),
		BackgroundColor3 = Color3.fromRGB(50, 20, 30),
		BorderSizePixel = 0,
	})

	fill = UI.mk(panel, "Frame", {
		Name = "Fill",
		Size = UDim2.new(1, 0, 0, 22),
		Position = UDim2.new(0, 0, 0, 24),
		BackgroundColor3 = Color3.fromRGB(230, 50, 70),
		BorderSizePixel = 0,
	})

	nameLabel = UI.mk(panel, "TextLabel", {
		Size = UDim2.new(0.6, 0, 0, 20),
		Position = UDim2.new(0, 8, 0, 2),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextSize = 15,
		TextColor3 = Color3.fromRGB(255, 200, 210),
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "협동 보스",
	})

	participantsLabel = UI.mk(panel, "TextLabel", {
		Size = UDim2.new(0.4, -8, 0, 20),
		Position = UDim2.new(0.6, 0, 0, 2),
		BackgroundTransparency = 1,
		Font = Enum.Font.Gotham,
		TextSize = 12,
		TextColor3 = Color3.fromRGB(210, 170, 180),
		TextXAlignment = Enum.TextXAlignment.Right,
		Text = "",
	})

	hpLabel = UI.mk(panel, "TextLabel", {
		Size = UDim2.new(1, 0, 0, 22),
		Position = UDim2.new(0, 0, 0, 24),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextSize = 13,
		TextColor3 = Color3.fromRGB(255, 255, 255),
		Text = "",
	})
end

-- payload: nil 이면 숨김
function CoopHud.update(payload: any)
	if not panel then
		return
	end
	if not payload or type(payload) ~= "table" then
		panel.Visible = false
		return
	end

	panel.Visible = true
	nameLabel.Text = tostring(payload.name or "협동 보스")
	participantsLabel.Text = string.format("참가 %d명", payload.participants or 0)

	local hp = tonumber(payload.hp) or 0
	local maxHp = tonumber(payload.maxHp) or 1
	local ratio = maxHp > 0 and math.clamp(hp / maxHp, 0, 1) or 0

	fill.Size = UDim2.new(ratio, 0, 0, 22)
	-- HP가 낮을수록 더 밝게 (위기감)
	fill.BackgroundColor3 = ratio > 0.5
		and Color3.fromRGB(230, 50, 70)
		or ratio > 0.2
		and Color3.fromRGB(255, 130, 40)
		or Color3.fromRGB(255, 220, 60)
	hpLabel.Text = string.format("%d / %d", math.max(0, hp), maxHp)
end

return CoopHud
