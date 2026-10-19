--!strict
-- HUD: 골드/웨이브/기지/보스 체력 표시
local UI = require(script.Parent:WaitForChild("UiKit"))

local HUD = {}

local state = {
	gold = 0,
	wave = 0,
	baseHp = 100,
	baseMaxHp = 100,
}

local goldLabel: TextLabel
local waveLabel: TextLabel
local baseLabel: TextLabel
local bossBar: Frame
local bossFill: Frame
local bossText: TextLabel

function HUD.build(parent: Instance)
	local mk = UI.mk

	local hud = mk(parent, "Frame", {
		Name = "HUD",
		Size = UDim2.new(1, 0, 0, 56),
		Position = UDim2.new(0, 0, 0, 0),
		BackgroundColor3 = Color3.fromRGB(18, 20, 28),
		BackgroundTransparency = 0.15,
		BorderSizePixel = 0,
	})

	goldLabel = mk(hud, "TextLabel", {
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

	waveLabel = mk(hud, "TextLabel", {
		Name = "Wave",
		Size = UDim2.new(0, 320, 1, 0),
		Position = UDim2.new(0.5, -160, 0, 0),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextSize = 20,
		TextColor3 = Color3.fromRGB(230, 235, 245),
		Text = "웨이브 0",
	})

	baseLabel = mk(hud, "TextLabel", {
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

	bossBar = mk(parent, "Frame", {
		Name = "BossBar",
		Size = UDim2.new(0.6, 0, 0, 26),
		Position = UDim2.new(0.2, 0, 0, 64),
		BackgroundColor3 = Color3.fromRGB(40, 12, 12),
		BorderSizePixel = 0,
		Visible = false,
	})
	bossFill = mk(bossBar, "Frame", {
		Name = "Fill",
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundColor3 = Color3.fromRGB(210, 50, 50),
		BorderSizePixel = 0,
	})
	bossText = mk(bossBar, "TextLabel", {
		Name = "Label",
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextSize = 16,
		TextColor3 = Color3.fromRGB(255, 255, 255),
		Text = "BOSS",
	})
end

function HUD.setGold(gold: number)
	state.gold = gold
	goldLabel.Text = string.format("골드: %d", gold)
end

function HUD.setWave(wave: number)
	state.wave = wave
	waveLabel.Text = string.format("웨이브 %d", wave)
end

function HUD.setBoss(isBoss: boolean, hp: number, maxHp: number)
	if isBoss and maxHp > 0 then
		bossBar.Visible = true
		bossFill.Size = UDim2.new(math.clamp(hp / maxHp, 0, 1), 0, 1, 0)
		bossText.Text = string.format("BOSS  %d / %d", math.max(0, hp), maxHp)
	else
		bossBar.Visible = false
	end
end

function HUD.setBase(hp: number, maxHp: number)
	state.baseHp = hp
	state.baseMaxHp = maxHp
	baseLabel.Text = string.format("기지: %d / %d", math.max(0, hp), maxHp)
end

return HUD
