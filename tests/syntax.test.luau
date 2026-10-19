-- 빌드된 .rbxlx에서 스크립트 소스를 추출해 Luau 파서로 문법 검증
-- Studio 없이 컴파일 오류를 사전에 잡는다.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")

local path = process.args[1] or "TowerEvolution.rbxlx"
local xml = fs.readFile(path)

-- <string name="Source"><![CDATA[ ... ]]></string> 추출
local scripts = {}
local pos = 1
while true do
	local s = string.find(xml, '<string name="Source"><![CDATA[', pos, true)
	if not s then
		break
	end
	local bodyStart = s + #'<string name="Source"><![CDATA['
	local e = string.find(xml, "]]></string>", bodyStart, true)
	if not e then
		break
	end
	local src = string.sub(xml, bodyStart, e - 1)
	table.insert(scripts, src)
	pos = e + #"]]></string>"
end

print(string.format("추출된 스크립트: %d개\n", #scripts))

-- 이름 추출 (앞부분 주석에서 유추하기 어려우므로 순번 + 첫 주석 사용)
local okCount, failCount = 0, 0
local failures = {}

for i, src in scripts do
	local firstLine = (string.match(src, "^[^\n]*") or ""):gsub("\r", "")
	local label = string.match(src, "^%-%-!strict%s*\n%-%-%s*([^\n]*)") or firstLine
	label = string.sub(label, 1, 40)

	local ok, err = pcall(function()
		luau.compile(src, {})
	end)

	if ok then
		okCount += 1
		print(string.format("  OK    #%d %s", i, label))
	else
		failCount += 1
		table.insert(failures, { i = i, label = label, err = tostring(err) })
		print(string.format("  FAIL  #%d %s", i, label))
		print("        " .. string.sub(tostring(err), 1, 300):gsub("\n", "\n        "))
	end
end

print(string.format("\n===== 문법 검증: %d OK, %d FAIL =====", okCount, failCount))
if failCount > 0 then
	for _, f in failures do
		print(string.format("\n#%d %s\n%s", f.i, f.label, f.err))
	end
	error("syntax check failed")
end
