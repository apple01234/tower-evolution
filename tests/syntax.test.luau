-- 빌드된 .rbxlx에서 스크립트 소스를 추출해 Luau 파서로 문법 검증
-- Studio 없이 컴파일 오류를 사전에 잡는다.
--
-- Rojo 는 소스에 따라 두 가지 형식으로 쓴다:
--   1) <string name="Source"><![CDATA[ ... ]]></string>   ← 대부분
--   2) <string name="Source">... escaped ...</string>     ← CDATA 불가한 내용
-- 둘 다 읽어야 스크립트를 빠뜨리지 않는다.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")

local path = process.args[1] or "TowerEvolution.rbxlx"
local xml = fs.readFile(path)

local OPENER = '<string name="Source">'

-- XML 엔티티 복원
local function unescape(s: string): string
	s = s:gsub("&lt;", "<")
	s = s:gsub("&gt;", ">")
	s = s:gsub("&quot;", '"')
	s = s:gsub("&apos;", "'")
	s = s:gsub("&#(%d+);", function(n)
		return string.char(tonumber(n) :: number)
	end)
	s = s:gsub("&amp;", "&")
	return s
end

local scripts = {}
local pos = 1

while true do
	local s = string.find(xml, OPENER, pos, true)
	if not s then
		break
	end
	local bodyStart = s + #OPENER

	if string.sub(xml, bodyStart, bodyStart + 8) == "<![CDATA[" then
		-- 형식 1: CDATA
		local cstart = bodyStart + 9
		local e = string.find(xml, "]]></string>", cstart, true)
		if not e then
			break
		end
		table.insert(scripts, string.sub(xml, cstart, e - 1))
		pos = e + #"]]></string>"
	else
		-- 형식 2: 일반 문자열 (이스케이프됨)
		local e = string.find(xml, "</string>", bodyStart, true)
		if not e then
			break
		end
		table.insert(scripts, unescape(string.sub(xml, bodyStart, e - 1)))
		pos = e + #"</string>"
	end
end

print(string.format("추출된 스크립트: %d개\n", #scripts))

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
