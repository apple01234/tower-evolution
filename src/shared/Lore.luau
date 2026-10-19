--!strict
-- 이그드라실 세계관 접근자. 실제 데이터는 LoreData.luau.
-- Roblox: script.Parent, Lune: 파일 경로. 양쪽에서 동작하도록 분기.
local LoreData
if script then
	LoreData = require(script.Parent:WaitForChild("LoreData"))
else
	LoreData = require("./LoreData")
end

export type ZoneDef = {
	id: string,
	kingdom: string,
	num: number,
	name: string,
	subtitle: string,
	bossKey: string,
	unlockWave: number,
	hpMult: number,
	enemyPool: { string },
	tint: string,
}

export type BossDef = {
	key: string,
	name: string,
	kingdomNum: number,
	hp: number,
	atk: number,
	speed: number,
	exp: number,
	gold: number,
	signature: string,
	lore: string,
}

-- 9왕국. num은 원본 챕터 번호를 유지해 스토리 순서를 보존한다.
local Lore = {}

Lore.ZONES = LoreData.ZONES
Lore.BOSSES = LoreData.BOSSES

Lore.BOSS_ORDER = { "guardian", "behemoth", "nidhog", "surt", "fenrir", "abysslord", "skoll", "gram", "abudditos" }

function Lore.zoneForWave(wave: number): ZoneDef
	local best = Lore.ZONES[1]
	for _, z in Lore.ZONES do
		if wave >= z.unlockWave then
			best = z
		end
	end
	return best
end

function Lore.getBoss(key: string): BossDef?
	return (Lore.BOSSES :: any)[key]
end

-- 최종 보스 체력은 원본 스케일(종언 존재)을 반영해 별도 배율
Lore.FINAL_BOSS_KEY = "abudditos"

return Lore
