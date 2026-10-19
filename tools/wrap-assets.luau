-- rbxm/rbxmx → Rojo 호환 Model 래퍼 변환
-- Rojo 7.7 은 최상위 인스턴스 1개만 허용하므로, 여러 개면 Model 로 감싼다.
--
-- 사용: lune run tools/wrap-assets.luau <srcDir> <outDir>
local roblox = require("@lune/roblox")
local fs = require("@lune/fs")
local process = require("@lune/process")

local srcDir = process.args[1] or "assets"
local outDir = process.args[2] or "assets_wrapped"

if fs.isDir(outDir) then
	fs.removeDir(outDir)
end
fs.writeDir(outDir)

local files = fs.readDir(srcDir)
table.sort(files)

local wrapped, passthrough, failed = 0, 0, 0
local report = {}

for _, name in files do
	local ext = string.match(name, "%.(%w+)$")
	if ext ~= "rbxm" and ext ~= "rbxmx" then
		continue
	end

	local key = string.match(name, "^(.+)%.") or name
	local srcPath = srcDir .. "/" .. name
	local data = fs.readFile(srcPath)

	local ok, listOrModel = pcall(function()
		if ext == "rbxm" then
			return roblox.deserializeModel(data)
		end
		-- rbxmx 는 바이트로 읽고 같은 API 사용 (Lune 이 형식 자동 판별)
		return roblox.deserializeModel(data)
	end)

	if not ok or not listOrModel then
		table.insert(report, string.format("  FAIL  %-22s %s", key, tostring(listOrModel)))
		failed += 1
		continue
	end

	-- 최상위 개수 세기
	local count = 0
	for _ in listOrModel do
		count += 1
	end

	local outPath = outDir .. "/" .. key .. ".rbxm"

	if count == 1 then
		-- 그대로 저장 (단일 최상위)
		local single = listOrModel[1]
		local okSer, serErr = pcall(function()
			fs.writeFile(outPath, roblox.serializeModel({ single }))
		end)
		if okSer then
			table.insert(report, string.format("  SINGLE %-21s 1개", key))
			passthrough += 1
		else
			table.insert(report, string.format("  FAIL   %-21s 직렬화: %s", key, tostring(serErr)))
			failed += 1
		end
	else
		-- 여러 개 → Model 로 감싼다
		local wrapper = roblox.Instance.new("Model")
		wrapper.Name = key
		for i, child in listOrModel do
			child.Name = child.Name .. "_" .. tostring(i)
			child.Parent = wrapper
		end

		local okSer, serErr = pcall(function()
			fs.writeFile(outPath, roblox.serializeModel({ wrapper }))
		end)
		if okSer then
			table.insert(report, string.format("  WRAP   %-21s %d개 → Model", key, count))
			wrapped += 1
		else
			table.insert(report, string.format("  FAIL   %-21s 감싸기: %s", key, tostring(serErr)))
			failed += 1
		end
	end
end

for _, line in report do
	print(line)
end
print(string.format("\n단일 %d / 감쌈 %d / 실패 %d", passthrough, wrapped, failed))

if failed > 0 then
	process.exit(1)
end
