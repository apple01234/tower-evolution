-- 구조 회귀 테스트: Rojo init 스크립트 규칙
--
-- 배경 (실제 Studio 로그로 발견한 버그):
--   src/server/init.server.luau 는 "Server" 라는 Script 가 되고,
--   같은 폴더의 나머지 .luau 는 그 Script 의 *자식* ModuleScript 가 된다.
--
--   그래서 진입점에서 모듈을 찾을 때:
--     잘못: local parent = script.Parent  → ServerScriptService 를 뒤져 Save 를 못 찾고 무한 yield
--     올바름: local parent = script        → Script 자식에서 Save 를 찾음
--
--   반대로 모듈(자식)에서는 script.Parent 가 그 Script 이므로 script.Parent:WaitForChild 가 맞다.
--
-- Studio 로그 증거:
--   Infinite yield possible on 'ServerScriptService:WaitForChild("Save")'
--   Script 'ServerScriptService.Server', Line 5
local fs = require("@lune/fs")
local process = require("@lune/process")

local root = process.args[1] or "."

local pass, fail = 0, 0
local failures = {}

local function check(cond: boolean, msg: string)
	if cond then
		pass += 1
	else
		fail += 1
		table.insert(failures, msg)
	end
end

-- 주석 제거 (라인 단위)
local function stripComment(line: string): string
	return (string.gsub(line, "%-%-.*$", ""))
end

-- 진입점 파일들
local entries = {
	{ path = root .. "/src/server/init.server.luau", label = "init.server" },
	{ path = root .. "/src/client/init.client.luau", label = "init.client" },
}

for _, e in entries do
	local okRead, src = pcall(fs.readFile, e.path)
	if not okRead then
		check(false, "진입점 없음: " .. e.path)
		continue
	end

	-- 진입점 안에서 script.Parent 를 "모듈 탐색 기준"으로 쓰면 버그.
	-- 허용: 주석, 그리고 script.Parent 가 정말 부모를 가리켜야 하는 특수 용도.
	-- 여기서는 "local parent = script.Parent" / "= script.Parent" 할당 패턴을 잡는다.
	local bad = 0
	local badLines = {}
	for line in string.gmatch(src, "[^\n]+") do
		local code = stripComment(line)
		-- 변수에 script.Parent 를 대입하는 패턴
		if string.find(code, "=%s*script%.Parent%s*$") then
			bad += 1
			table.insert(badLines, (string.gsub(line, "^%s+", "")))
		end
		-- script.Parent 에서 직접 WaitForChild/FindFirstChild 하는 패턴
		if string.find(code, "script%.Parent%s*[:.]%s*WaitForChild") or
			string.find(code, "script%.Parent%s*[:.]%s*FindFirstChild") then
			bad += 1
			table.insert(badLines, (string.gsub(line, "^%s+", "")))
		end
	end

	check(bad == 0, string.format(
		"%s: script.Parent 로 모듈을 찾는 코드 %d곳 (script 여야 함): %s",
		e.label, bad, table.concat(badLines, " | ")
	))
end

-- 진입점이 핵심 모듈 이름을 실제로 참조하는지 (오타/누락 방지)
local okEntry, esrc = pcall(fs.readFile, root .. "/src/server/init.server.luau")
if okEntry then
	for _, need in { "Save", "Battle" } do
		check(
			string.find(esrc, '"' .. need .. '"', 1, true) ~= nil,
			string.format("init.server 가 %s 를 참조하지 않음", need)
		)
	end
end

-- 모듈 계층이 유효한지: server/client 폴더에 모듈이 존재
local moduleCount = 0
for _, dir in { root .. "/src/server", root .. "/src/client" } do
	local okDir, files = pcall(fs.readDir, dir)
	if okDir then
		for _, f in files do
			if string.match(f, "%.luau$") and not string.match(f, "^init%.") then
				moduleCount += 1
			end
		end
	end
end
check(moduleCount > 10, string.format("모듈이 %d개뿐 — 구조 이상", moduleCount))

print(string.format("\n===== 구조 검증: %d passed, %d failed =====", pass, fail))
if fail > 0 then
	for _, f in failures do
		print("  FAIL " .. f)
	end
	error("structure check failed")
end
