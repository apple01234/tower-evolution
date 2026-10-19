-- 에셋에서 실행 코드(Script/LocalScript/ModuleScript) 및 위험 요소 제거
-- 서드파티 마켓플레이스 모델에는 임의 코드가 들어 있을 수 있다.
-- 우리 게임 서버에서 그 코드가 실행되면 안 되므로 로드 전에 제거한다.
--
-- 사용: lune run tools/sanitize-assets.luau <inDir> <outDir>
local roblox = require("@lune/roblox")
local fs = require("@lune/fs")
local process = require("@lune/process")

local inDir = process.args[1] or "assets"
local outDir = process.args[2] or "assets_clean"

if fs.isDir(outDir) then
	fs.removeDir(outDir)
end
fs.writeDir(outDir)

local SCRIPT_CLASSES = {
	Script = true,
	LocalScript = true,
	ModuleScript = true,
}

-- 원격 통신/위험 클래스도 제거
local DANGEROUS = {
	RemoteEvent = true,
	RemoteFunction = true,
	BindableEvent = true,
	BindableFunction = true,
	HttpService = true,
	Sound = false, -- 사운드는 허용
}

local function purge(inst, removed): number
	local count = 0

	local children = inst:GetChildren()

	for _, c in children do
		if SCRIPT_CLASSES[c.ClassName] or DANGEROUS[c.ClassName] then
			c:Destroy()
			table.insert(removed, c.ClassName)
			count += 1
		else
			count += purge(c, removed)
		end
	end
	return count
end

local files = fs.readDir(inDir)
table.sort(files)

local totalRemoved = 0
local report = {}

for _, name in files do
	local ext = string.match(name, "%.(%w+)$")
	if ext ~= "rbxm" then
		continue
	end

	local key = string.match(name, "^(.+)%.") or name
	local data = fs.readFile(inDir .. "/" .. name)

	local ok, list = pcall(function()
		return roblox.deserializeModel(data)
	end)
	if not ok or not list then
		table.insert(report, string.format("  FAIL  %-22s %s", key, tostring(list)))
		continue
	end

	local removed = {}
	local removedCount = 0
	for _, top in list do
		removedCount += purge(top, removed)
	end

	-- 다시 직렬화
	local outPath = outDir .. "/" .. key .. ".rbxm"
	local okSer, err = pcall(function()
		fs.writeFile(outPath, roblox.serializeModel(list))
	end)

	if not okSer then
		table.insert(report, string.format("  FAIL  %-22s 직렬화: %s", key, tostring(err)))
		continue
	end

	if removedCount > 0 then
		totalRemoved += removedCount
		local uniq = {}
		for _, c in removed do
			uniq[c] = (uniq[c] or 0) + 1
		end
		local parts = {}
		for c, n in uniq do
			table.insert(parts, string.format("%s×%d", c, n))
		end
		table.sort(parts)
		table.insert(report, string.format("  CLEAN %-22s 제거: %s", key, table.concat(parts, ", ")))
	else
		table.insert(report, string.format("  OK    %-22s", key))
	end
end

for _, line in report do
	print(line)
end
print(string.format("\n제거된 실행 코드/위험 객체: %d개", totalRemoved))
