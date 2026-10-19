-- 월드 필수 요소 검증
--
-- 배경 (Studio 스크린샷/로그로 발견):
--   1) SpawnLocation 이 하나도 없어서 플레이어가 허공에 스폰됐다.
--   2) part() 헬퍼가 모든 Part 에 CanCollide=false 를 줘서
--      바닥(Ground)까지 충돌이 꺼져 있었다. 밟을 수 없는 바닥 = 낙하.
--
-- 이 테스트는 소스 수준에서 두 가지를 강제한다:
--   - SpawnLocation 을 실제로 생성하는 코드가 있을 것
--   - 바닥/경로 Part 에 충돌을 켜는 경로가 있을 것
local fs = require("@lune/fs")
local process = require("@lune/process")

local root = process.args[1] or "."
local path = root .. "/src/server/WorldSetup.luau"

local ok, src = pcall(fs.readFile, path)
if not ok then
	error("WorldSetup.luau 를 읽을 수 없음: " .. path)
end

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

-- 1) SpawnLocation 생성
check(
	string.find(src, 'Instance.new("SpawnLocation")', 1, true) ~= nil,
	"SpawnLocation 을 생성하지 않음 — 플레이어가 허공에 스폰된다"
)

-- 2) SpawnLocation 을 arena/workspace 에 부착
check(
	string.find(src, "spawn.Parent", 1, true) ~= nil,
	"SpawnLocation 을 트리에 넣지 않음 (Parent 미설정)"
)

-- 3) 바닥이 충돌을 갖는가: part() 가 collide 인자를 받아야 한다
check(
	string.find(src, "collide: boolean?", 1, true) ~= nil,
	"part() 가 collide 인자를 받지 않음 — 바닥 충돌을 켤 수단이 없다"
)

-- 3-1) 사전 배치된 TowerArena 를 파괴하지 않아야 한다
check(
	string.find(src, "existing:Destroy()", 1, true) == nil,
	"WorldSetup.build 가 기존 TowerArena 를 Destroy 함 — 사전 배치 맵이 사라진다"
)

-- 4) part() 본문이 CanCollide 를 하드코딩 false 로 두지 않아야 한다
local badHardcode = string.find(src, "p.CanCollide = false", 1, true) ~= nil
check(not badHardcode, "part() 가 CanCollide=false 를 하드코딩 — 바닥도 충돌 없음이 된다")

-- 5) Ground 생성 시 collide=true 전달
local groundIdx = string.find(src, '"Ground"', 1, true)
check(groundIdx ~= nil, "Ground 파트 생성 코드가 없음")

if groundIdx then
	-- Ground 호출부 근처(앞 400자 ~ 뒤 600자)에서 true 전달 확인
	local from = math.max(1, groundIdx - 200)
	local to = math.min(#src, groundIdx + 600)
	local window = string.sub(src, from, to)
	check(
		string.find(window, "true", 1, true) ~= nil,
		"Ground 호출에 collide=true 가 전달되지 않음"
	)
end

print(string.format("\n===== 월드 검증: %d passed, %d failed =====", pass, fail))
if fail > 0 then
	for _, f in failures do
		print("  FAIL " .. f)
	end
	error("world check failed")
end
