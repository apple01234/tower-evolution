--!strict
-- 클라이언트 진입점. UI 조립과 이벤트 배선만 담당한다.
-- 실제 UI는 UiKit / Hud / InventoryPanel / GrowthPanel 모듈에 있다.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local MODULE_TIMEOUT = 10

-- 타임아웃 있는 require. 실패 시 nil + 사용 가능한 이름 로그.
local function need(name: string, parent: Instance?): any?
	local p = parent or script
	if not p then
		warn(string.format("[TowerEvolution] 부모 없음 (모듈 %s)", name))
		return nil
	end
	local child = p:FindFirstChild(name) or p:WaitForChild(name, MODULE_TIMEOUT)
	if not child then
		local available = {}
		for _, c in p:GetChildren() do
			table.insert(available, c.Name)
		end
		warn(string.format(
			"[TowerEvolution] 클라이언트 모듈 '%s' 없음 (parent=%s). 사용 가능: %s",
			name, p:GetFullName(), table.concat(available, ", ")
		))
		return nil
	end
	local ok, mod = pcall(require, child)
	if not ok then
		warn(string.format("[TowerEvolution] require('%s') 실패: %s", name, tostring(mod)))
		return nil
	end
	return mod
end

local Shared = ReplicatedStorage:WaitForChild("Shared", MODULE_TIMEOUT)

local Net, UI, Hud, InventoryPanel, GrowthPanel, BranchDialog, CoopHud, MissionPanel

if Shared then
	Net = need("Net", Shared)
	UI = need("UiKit")
	Hud = need("Hud")
	InventoryPanel = need("InventoryPanel")
	GrowthPanel = need("GrowthPanel")
	BranchDialog = need("BranchDialog")
	CoopHud = need("CoopHud")
	MissionPanel = need("MissionPanel")
end

-- 모든 모듈이 준비됐는지 확인 (없으면 UI 생성 건너뛰고 명확히 로그)
local READY = Shared ~= nil
	and Net and UI and Hud and InventoryPanel and GrowthPanel
	and BranchDialog and CoopHud and MissionPanel

if not READY then
	warn("[TowerEvolution] 클라이언트 모듈 누락 — UI를 생성하지 않습니다. 위 경고를 확인하세요.")
end

local mk = if READY then (UI :: any).mk else nil

-- READY 일 때만 UI 전체를 구성한다
if READY then
	local playerGui = UI.playerGui

	-- ============ 루트 GUI ============
	-- 공식 문서: ScreenInsets로 노치/홈바/상단바 안전영역을 자동 회피
	-- (IgnoreGuiInset=true 는 노치 아래로 UI가 깔려 잘린다)
	local gui = mk(playerGui, "ScreenGui", {
		Name = "TowerGui",
		ResetOnSpawn = false,
		IgnoreGuiInset = false,
		ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	})

	local uiScale = mk(gui, "UIScale", { Name = "ResponsiveScale", Scale = 1 })
	UI.watchViewport(uiScale)

	-- ============ 알림 ============
	local notifyLabel = mk(gui, "TextLabel", {
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
	UI.attachNotify(notifyLabel)

	-- ============ HUD ============
	Hud.build(gui)
	CoopHud.build(gui)

	-- ============ 인벤토리 ============
	InventoryPanel.build(gui, {
		onSummon = function(family)
			local ev = Net.get("RequestSummon")
			if ev then
				ev:FireServer(family)
			end
		end,
		onFuse = function(uids, chosen)
			local ev = Net.get("RequestFuse")
			if ev then
				ev:FireServer(uids, chosen)
			end
		end,
	})

	-- ============ 상단 버튼 ============
	local topButtons = mk(gui, "Frame", {
		Name = "TopButtons",
		Size = UDim2.new(0, 264, 0, 40),
		Position = UDim2.new(1, -276, 0, 96),
		BackgroundTransparency = 1,
	})
	mk(topButtons, "UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
	})

	local function topButton(text: string, color: Color3, order: number): TextButton
		return mk(topButtons, "TextButton", {
			Name = text,
			Size = UDim2.new(0, 128, 1, 0),
			LayoutOrder = order,
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			Font = Enum.Font.GothamBold,
			TextSize = 15,
			TextColor3 = Color3.fromRGB(255, 255, 255),
			Text = text,
		})
	end

	local growthBtn = topButton("성장", Color3.fromRGB(200, 140, 40), 1)
	local missionBtn = topButton("미션", Color3.fromRGB(60, 130, 170), 2)

	-- ============ 패널 ============
	GrowthPanel.build(gui)
	MissionPanel.build(gui)

	growthBtn.Activated:Connect(function()
		GrowthPanel.toggle()
	end)
	missionBtn.Activated:Connect(function()
		MissionPanel.toggle()
	end)

	-- ============ 분기 선택 팝업 ============
	BranchDialog.build(gui, function(uids, chosen)
		local ev = Net.get("RequestFuse")
		if ev then
			ev:FireServer(uids, chosen)
		end
	end)

	-- ============ 서버 이벤트 ============
	local function bindEvents()
		local stateEv = Net.get("StateSync")
		if stateEv then
			stateEv.OnClientEvent:Connect(function(payload)
				if type(payload) ~= "table" then
					return
				end
				Hud.setGold(payload.gold or 0)
				Hud.setWave(payload.wave or 0)
				InventoryPanel.setSlots(payload.slots or {})
			end)
		end

		local waveEv = Net.get("WaveSync")
		if waveEv then
			waveEv.OnClientEvent:Connect(function(wave, boss, bhp, bmax, hp, hpmax)
				Hud.setWave(wave or 0)
				Hud.setBoss(boss == true, bhp or 0, bmax or 0)
				Hud.setBase(hp or 0, hpmax or 0)
			end)
		end

		local progressEv = Net.get("ProgressSync")
		if progressEv then
			progressEv.OnClientEvent:Connect(function(payload)
				if type(payload) == "table" then
					GrowthPanel.setData(payload)
				end
			end)
		end

		local missionEv = Net.get("MissionSync")
		if missionEv then
			missionEv.OnClientEvent:Connect(function(payload)
				if type(payload) == "table" then
					MissionPanel.setData(payload)
				end
			end)
		end

		local coopEv = Net.get("CoopSync")
		if coopEv then
			coopEv.OnClientEvent:Connect(function(payload)
				CoopHud.update(payload)
			end)
		end

		local notifyEv = Net.get("Notify")
		if notifyEv then
			notifyEv.OnClientEvent:Connect(function(msg, kind)
				UI.showNotify(tostring(msg), tostring(kind or "info"))
			end)
		end
	end

	bindEvents()

	-- ============ 초기 안내 ============
	if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
		UI.showNotify("타워를 탭해 선택한 뒤 합성하세요.", "info")
	end

end