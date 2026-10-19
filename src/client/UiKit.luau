--!strict
-- 클라이언트 공용 UI 유틸 및 알림. 여러 UI 모듈이 공유한다.
local Players = game:GetService("Players")

local UI = {}

local player = Players.LocalPlayer
UI.player = player
UI.playerGui = player:WaitForChild("PlayerGui")

-- 인스턴스 생성 헬퍼 (props 테이블 일괄 적용)
function UI.mk(parent: Instance, class: string, props: { [string]: any }): any
	local inst = Instance.new(class)
	for k, v in props do
		if k ~= "Parent" then
			(inst :: any)[k] = v
		end
	end
	inst.Parent = parent
	return inst
end

-- ============ 알림 ============
local notifyLabel: TextLabel? = nil
local notifyToken = 0

function UI.attachNotify(label: TextLabel)
	notifyLabel = label
end

function UI.showNotify(msg: string, kind: string)
	local label = notifyLabel
	if not label then
		return
	end
	notifyToken += 1
	local mine = notifyToken
	label.Text = msg
	label.TextColor3 = kind == "bad" and Color3.fromRGB(255, 120, 120)
		or kind == "good" and Color3.fromRGB(140, 255, 160)
		or kind == "boss" and Color3.fromRGB(255, 180, 80)
		or Color3.fromRGB(235, 235, 245)
	label.TextTransparency = 0
	task.delay(2.2, function()
		if notifyToken == mine and label then
			label.TextTransparency = 1
		end
	end)
end

-- ============ 화면 크기 대응 ============
-- 공식 문서: UIScale는 부모 GuiBase2d의 AbsoluteSize를 배율한다.
function UI.applyResponsiveScale(scaleObj: UIScale)
	local cam = workspace.CurrentCamera
	local vp = cam and cam.ViewportSize or Vector2.new(1280, 720)
	local s = math.clamp(math.min(vp.X / 1280, vp.Y / 720), 0.72, 1.35)
	scaleObj.Scale = s
end

function UI.watchViewport(scaleObj: UIScale)
	UI.applyResponsiveScale(scaleObj)
	local cam = workspace.CurrentCamera
	if cam then
		cam:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			UI.applyResponsiveScale(scaleObj)
		end)
	end
end

-- ============ 공용 패널 위젯 ============

-- 화면 대비 패널 크기/위치 (모바일 세로 화면 대응)
function UI.panelBounds(height: number): (UDim2, UDim2)
	return UDim2.new(0.92, 0, 0, height), UDim2.new(0.04, 0, 0.5, -height / 2)
end

function UI.panelHeader(parent: Instance, text: string, color: Color3)
	UI.mk(parent, "TextLabel", {
		Size = UDim2.new(1, -64, 0, 28),
		Position = UDim2.new(0, 12, 0, 8),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextSize = 18,
		TextColor3 = color,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = text,
	})
end

function UI.panelCloseButton(parent: Instance): TextButton
	return UI.mk(parent, "TextButton", {
		Size = UDim2.new(0, 30, 0, 30),
		Position = UDim2.new(1, -42, 0, 8),
		BackgroundColor3 = Color3.fromRGB(60, 64, 78),
		BorderSizePixel = 0,
		Font = Enum.Font.GothamBold,
		TextSize = 16,
		TextColor3 = Color3.fromRGB(230, 235, 245),
		Text = "X",
	})
end

function UI.scrollList(parent: Instance, y: number, heightOffset: number): ScrollingFrame
	local s = UI.mk(parent, "ScrollingFrame", {
		Size = UDim2.new(1, -24, 1, heightOffset),
		Position = UDim2.new(0, 12, 0, y),
		BackgroundTransparency = 1,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 6,
		BorderSizePixel = 0,
	})
	UI.mk(s, "UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder })
	return s
end

return UI
