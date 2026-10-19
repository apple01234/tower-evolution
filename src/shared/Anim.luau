--!strict
-- 절차적 애니메이션. Roblox 애니메이션 에셋 업로드 없이 코드로 움직인다.
-- (Animation 에셋은 Studio 업로드가 필요하므로, 여기서는 CFrame 기반 절차 애니메이션 사용)
--
-- 공식 API 근거:
--   TweenService:Create(instance, TweenInfo, goal) -> Tween
--   TweenInfo.new(time, style, direction, repeatCount, reverses, delayTime)
--   Model:PivotTo(CFrame), PVInstance:GetPivot()

local TweenService = game:GetService("TweenService")

local Anim = {}

-- ============ 이징 프리셋 ============
Anim.EASE = {
	bounce = TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
	smooth = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
	punch = TweenInfo.new(0.18, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
	float = TweenInfo.new(0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
}

-- ============ 적 피격 반동 ============
-- 맞은 적이 짧게 뒤로 밀렸다 돌아온다.
function Anim.hitRecoil(model: Instance, baseCFrame: CFrame, direction: Vector3)
	if not model or not model:IsA("Model") then
		return
	end
	local pushed = baseCFrame + direction.Unit * 0.6

	-- Model 은 CFrame 속성이 없어 Tween 대상이 될 수 없다 → 즉시 이동 후 복귀
	model:PivotTo(pushed)
	task.delay(0.08, function()
		if model.Parent then
			model:PivotTo(baseCFrame)
		end
	end)
end

-- ============ 타워 발사 반동 ============
-- 포신이 살짝 앞으로 튀었다 돌아온다 (파트 기반 폴백 모델용)
function Anim.towerFire(model: Instance)
	if not model then
		return
	end
	if model:IsA("Model") then
		local pivot = model:GetPivot()
		local scaleUp = pivot * CFrame.new(0, 0.15, 0)
		model:PivotTo(scaleUp)
		task.delay(0.06, function()
			if model.Parent then
				model:PivotTo(pivot)
			end
		end)
	elseif model:IsA("BasePart") then
		local orig = model.Size
		model.Size = orig * 1.08
		task.delay(0.06, function()
			if model.Parent then
				model.Size = orig
			end
		end)
	end
end

-- ============ 적 사망 ============
-- 죽을 때 작아지며 사라진다. 즉시 Destroy 하지 않고 짧게 연출.
function Anim.enemyDeath(model: Instance, onDone: (() -> ())?)
	if not model then
		if onDone then
			onDone()
		end
		return
	end

	local parts = {}
	if model:IsA("Model") then
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") then
				table.insert(parts, d)
			end
		end
	elseif model:IsA("BasePart") then
		table.insert(parts, model)
	end

	if #parts == 0 then
		model:Destroy()
		if onDone then
			onDone()
		end
		return
	end

	for _, p in parts do
		TweenService:Create(p, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Transparency = 1,
			Size = p.Size * 0.35,
		}):Play()
	end

	task.delay(0.2, function()
		if model.Parent then
			model:Destroy()
		end
		if onDone then
			onDone()
		end
	end)
end

-- ============ 스폰 등장 ============
function Anim.enemySpawn(model: Instance)
	if not model then
		return
	end
	local parts = {}
	if model:IsA("Model") then
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") then
				parts[#parts + 1] = d
			end
		end
	elseif model:IsA("BasePart") then
		parts[1] = model
	end

	for _, p in parts do
		local target = p.Transparency
		p.Transparency = 1
		TweenService:Create(p, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Transparency = target,
		}):Play()
	end
end

-- ============ 부유 (보스 상시) ============
-- 무한 루프 대신 짧은 상하 반복을 반복 횟수 제한하여 건다.
function Anim.floatLoop(part: BasePart, amplitude: number)
	local up = part.Position + Vector3.new(0, amplitude, 0)
	-- repeatCount=5, reverses=true → 5회 왕복 후 정지 (무한 루프 회피)
	TweenService:Create(
		part,
		TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, 5, true, 0),
		{ Position = up }
	):Play()
end

-- ============ 기지 피격 ============
function Anim.baseHit(core: Instance)
	if not core or not core:IsA("BasePart") then
		return
	end
	local orig = core.Color
	core.Color = Color3.fromRGB(255, 90, 90)
	task.delay(0.15, function()
		if core.Parent then
			core.Color = orig
		end
	end)
end

-- ============ UI 알림 펄스 ============
function Anim.uiPulse(label: TextLabel)
	if not label then
		return
	end
	local base = label.TextSize
	label.TextSize = base + 4
	task.delay(0.12, function()
		if label.Parent then
			label.TextSize = base
		end
	end)
end

return Anim
