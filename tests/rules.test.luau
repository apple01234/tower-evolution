-- 코드 규칙 검사 (지시서 적용)
-- 사용: lune run tests/rules.test.luau
-- 목적: SRP(250줄), any 남용, _G 사용, pcall 누락 등을 기계적으로 잡는다.

local fs = require("@lune/fs")
local process = require("@lune/process")

local MAX_LINES = 250
local ROOTS = { "src/shared", "src/server", "src/client" }

local files: { string } = {}
for _, root in ROOTS do
	if fs.isDir(root) then
		for _, name in fs.readDir(root) do
			if string.match(name, "%.luau$") then
				table.insert(files, root .. "/" .. name)
			end
		end
	end
end
table.sort(files)

local failures: { string } = {}
local warnings: { string } = {}
local pass, fail = 0, 0

local function ok(name: string)
	pass += 1
end

local function bad(name: string, detail: string)
	fail += 1
	table.insert(failures, string.format("%s — %s", name, detail))
end

local function warn2(name: string, detail: string)
	table.insert(warnings, string.format("%s — %s", name, detail))
end

print(string.format("검사 대상 파일: %d개\n", #files))

-- ============ 1) 파일 크기 (SRP) ============
print("[1] SRP: 단일 파일 " .. MAX_LINES .. "줄 제한")
for _, path in files do
	local src = fs.readFile(path)
	local n = 0
	for _ in string.gmatch(src, "\n") do
		n += 1
	end
	n += 1
	if n > MAX_LINES then
		bad(path, string.format("%d줄 (초과 %d)", n, n - MAX_LINES))
	else
		ok(path)
	end
end

-- ============ 2) _G 전역 오염 ============
print("[2] _G 전역 사용 금지")
for _, path in files do
	local src = fs.readFile(path)
	local line = 0
	for l in string.gmatch(src .. "\n", "([^\n]*)\n") do
		line += 1
		if string.find(l, "_G%.", 1) or string.find(l, "_G%[") then
			bad(path, string.format("line %d: _G 사용", line))
			break
		end
	end
end

-- ============ 3) any 타입 (사유 주석 필수) ============
print("[3] any 사용 시 사유 주석 필요")
for _, path in files do
	local src = fs.readFile(path)
	local line = 0
	for l in string.gmatch(src .. "\n", "([^\n]*)\n") do
		line += 1
		if string.find(l, ":%s*any") or string.find(l, "::%s*any") or string.find(l, "<any>") then
			-- 같은 줄에 주석이 있으면 허용
			if not string.find(l, "%-%-") then
				warn2(path, string.format("line %d: any (사유 주석 없음)", line))
			end
		end
	end
end

-- ============ 4) DataStore/InsertService 호출은 pcall 필수 ============
print("[4] 위험 API 호출은 pcall 필수")
local risky = { "GetAsync", "SetAsync", "UpdateAsync", "LoadAsset", "RemoveAsync" }
for _, path in files do
	local src = fs.readFile(path)
	local line = 0
	local lines = {}
	for l in string.gmatch(src .. "\n", "([^\n]*)\n") do
		table.insert(lines, l)
	end
	for i, l in ipairs(lines) do
		for _, api in risky do
			if string.find(l, api, 1, true) and not string.find(l, "pcall") then
				-- 호출부인지 확인 (: 또는 . 뒤)
				if string.find(l, ":" .. api) or string.find(l, "%." .. api) then
					-- 앞 3줄 안에 pcall 이 있으면 허용
					local hasGuard = false
					for k = math.max(1, i - 3), i do
						if string.find(lines[k] or "", "pcall") then
							hasGuard = true
							break
						end
					end
					-- 함수 정의 줄은 제외
					local isDef = string.find(l, "function%s") ~= nil
					if not hasGuard and not isDef then
						warn2(path, string.format("line %d: %s without nearby pcall", i, api))
					end
				end
			end
		end
	end
end

-- ============ 5) 카멜케이스 규칙 ============
print("[5] 네이밍: 상수는 UPPER_SNAKE")
for _, path in files do
	local src = fs.readFile(path)
	-- local const = 숫자/문자열 리터럴인데 소문자로 시작하면 경고
	local line = 0
	for l in string.gmatch(src .. "\n", "([^\n]*)\n") do
		line += 1
		local name = string.match(l, "^%s*local%s+([%a_][%w_]*)%s*=%s*[%d\"]")
		if name and string.match(name, "^[a-z]") and not string.match(name, "^[a-z][a-zA-Z0-9]*$") then
			-- snake 또는 대문자 혼용
			warn2(path, string.format("line %d: 상수명 '%s' 확인", line, name))
		end
	end
end

-- ============ 결과 ============
print("\n[경고]")
if #warnings == 0 then
	print("  없음")
else
	for i, w in ipairs(warnings) do
		if i > 12 then
			print(string.format("  ... 외 %d건", #warnings - 12))
			break
		end
		print("  " .. w)
	end
end

print(string.format("\n규칙 통과 %d / 위반 %d", pass, fail))
if fail > 0 then
	print("\n[위반 목록]")
	for _, f in ipairs(failures) do
		print("  FAIL  " .. f)
	end
	error("rule violations")
end
print("===== 규칙 검사 통과 =====")
