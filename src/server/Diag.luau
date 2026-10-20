--! strict
-- 서버 진단: Battle.init() 의 어느 단계에서 죽는지 화면에 직접 표시한다.
-- Studio 로그를 볼 수 없는 환경에서도 원인을 특정하기 위한 임시 계측.
--
-- 사용: 서버 시작 시 자동 실행. 결과는 Workspace 의 ServerDiag 파트 SurfaceGui 에 뜬다.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Diag = {}

local lines: { string } = {}
local label: TextLabel? = nil
local part: Part? = nil

local function ensureGui()
	if part and part.Parent then
		return
	end
	local p = Instance.new("Part")
	p.Name = "ServerDiag"
	p.Size = Vector3.new(14, 8, 1)
	p.Anchored = true
	p.CanCollide = false
	p.CFrame = CFrame.new(0, 8, -22) * CFrame.Angles(0, math.rad(180), 0)
	p.Color = Color3.fromRGB(10, 12, 18)
	p.Material = Enum.Material.SmoothPlastic
	p.Parent = workspace

	local sg = Instance.new("SurfaceGui")
	sg.Face = Enum.NormalId.Front
	sg.CanvasSize = Vector2.new(700, 400)
	sg.AlwaysOnTop = true
	sg.Parent = p

	local l = Instance.new("TextLabel")
	l.Size = UDim2.new(1, -16, 1, -16)
	l.Position = UDim2.new(0, 8, 0, 8)
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.Code
	l.TextSize = 16
	l.TextColor3 = Color3.fromRGB(120, 255, 160)
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextYAlignment = Enum.TextYAlignment.Top
	l.TextWrapped = true
	l.Text = ""
	l.Parent = sg

	part = p
	label = l
end

local function flush()
	ensureGui()
	if label then
		label.Text = table.concat(lines, "\n")
	end
end

-- 한 줄 추가. 화면에도 즉시 반영.
function Diag.log(msg: string)
	table.insert(lines, msg)
	if #lines > 22 then
		table.remove(lines, 1)
	end
	flush()
end

-- 초기화 단계 계측용 래퍼. 성공/실패를 화면에 남긴다.
function Diag.step(name: string, fn: () -> any): boolean
	local ok, err = pcall(fn)
	if ok then
		Diag.log("OK   " .. name)
	else
		Diag.log("FAIL " .. name .. ": " .. tostring(err))
	end
	return ok
end

function Diag.clear()
	table.clear(lines)
	flush()
end

return Diag
