--!strict
-- 지역별 맵 테마 정의. 9왕국이 각자 다른 지형/색감을 갖는다.
-- WorldSetup 이 이 데이터를 읽어 맵을 생성한다.

-- 색상은 {r,g,b} 정수 튜플, 재질은 문자열로 저장한다.
-- (Lune 에는 Color3/Enum 이 없어 순수 데이터로 유지하고, Roblox 쪽에서 변환)
export type RGB = { number }

export type MapTheme = {
	zoneId: string,
	groundColor: RGB,
	groundMaterial: string,
	pathColor: RGB,
	pathMaterial: string,
	baseColor: RGB,
	spawnColor: RGB,
	ambient: RGB,
	fogColor: RGB,
	fogEnd: number,
	decor: {
		rocks: number,
		pillars: number,
		props: number,
	},
	propColor: RGB,
}

local THEMES: { [string]: MapTheme } = {
	Midgard_Forest = {
		zoneId = "Midgard_Forest",
		groundColor = { 46, 82, 40 },
		groundMaterial = "Grass",
		pathColor = { 120, 105, 80 },
		pathMaterial = "Slate",
		baseColor = { 80, 180, 255 },
		spawnColor = { 200, 60, 60 },
		ambient = { 85, 95, 80 },
		fogColor = { 60, 78, 55 },
		fogEnd = 400,
		decor = { rocks = 14, pillars = 4, props = 10 },
		propColor = { 60, 100, 50 },
	},
	Kusodia = {
		zoneId = "Kusodia",
		groundColor = { 58, 72, 40 },
		groundMaterial = "Ground",
		pathColor = { 100, 92, 70 },
		pathMaterial = "Mud",
		baseColor = { 90, 200, 220 },
		spawnColor = { 190, 70, 60 },
		ambient = { 75, 85, 72 },
		fogColor = { 52, 64, 48 },
		fogEnd = 350,
		decor = { rocks = 10, pillars = 6, props = 16 },
		propColor = { 70, 88, 50 },
	},
	Alfheim = {
		zoneId = "Alfheim",
		groundColor = { 78, 70, 120 },
		groundMaterial = "SmoothPlastic",
		pathColor = { 150, 140, 200 },
		pathMaterial = "Marble",
		baseColor = { 200, 180, 255 },
		spawnColor = { 240, 120, 200 },
		ambient = { 110, 100, 150 },
		fogColor = { 70, 62, 110 },
		fogEnd = 450,
		decor = { rocks = 8, pillars = 10, props = 6 },
		propColor = { 180, 170, 240 },
	},
	Muspelheim = {
		zoneId = "Muspelheim",
		groundColor = { 88, 40, 28 },
		groundMaterial = "CrackedLava",
		pathColor = { 140, 70, 40 },
		pathMaterial = "Slate",
		baseColor = { 255, 160, 80 },
		spawnColor = { 255, 60, 30 },
		ambient = { 140, 80, 60 },
		fogColor = { 90, 30, 20 },
		fogEnd = 300,
		decor = { rocks = 18, pillars = 8, props = 4 },
		propColor = { 180, 70, 30 },
	},
	Niflheim = {
		zoneId = "Niflheim",
		groundColor = { 150, 175, 195 },
		groundMaterial = "Ice",
		pathColor = { 190, 215, 235 },
		pathMaterial = "SmoothPlastic",
		baseColor = { 140, 220, 255 },
		spawnColor = { 120, 160, 220 },
		ambient = { 160, 180, 200 },
		fogColor = { 180, 205, 225 },
		fogEnd = 260,
		decor = { rocks = 12, pillars = 10, props = 6 },
		propColor = { 200, 225, 245 },
	},
	Svartalfheim = {
		zoneId = "Svartalfheim",
		groundColor = { 40, 32, 56 },
		groundMaterial = "Basalt",
		pathColor = { 90, 70, 120 },
		pathMaterial = "Cobblestone",
		baseColor = { 160, 110, 255 },
		spawnColor = { 200, 60, 200 },
		ambient = { 70, 55, 100 },
		fogColor = { 35, 26, 50 },
		fogEnd = 320,
		decor = { rocks = 16, pillars = 8, props = 8 },
		propColor = { 120, 80, 190 },
	},
	Nidavellir = {
		zoneId = "Nidavellir",
		groundColor = { 62, 58, 44 },
		groundMaterial = "Ground",
		pathColor = { 110, 98, 72 },
		pathMaterial = "Cobblestone",
		baseColor = { 255, 200, 90 },
		spawnColor = { 200, 90, 50 },
		ambient = { 95, 88, 70 },
		fogColor = { 52, 48, 36 },
		fogEnd = 380,
		decor = { rocks = 20, pillars = 6, props = 10 },
		propColor = { 140, 120, 70 },
	},
	Hel = {
		zoneId = "Hel",
		groundColor = { 38, 38, 46 },
		groundMaterial = "Rock",
		pathColor = { 70, 70, 84 },
		pathMaterial = "Basalt",
		baseColor = { 140, 140, 200 },
		spawnColor = { 180, 40, 60 },
		ambient = { 60, 60, 72 },
		fogColor = { 28, 28, 36 },
		fogEnd = 300,
		decor = { rocks = 24, pillars = 12, props = 4 },
		propColor = { 80, 80, 95 },
	},
	Abyss = {
		zoneId = "Abyss",
		groundColor = { 20, 20, 32 },
		groundMaterial = "Slate",
		pathColor = { 50, 40, 70 },
		pathMaterial = "Neon",
		baseColor = { 200, 60, 255 },
		spawnColor = { 255, 40, 80 },
		ambient = { 40, 30, 60 },
		fogColor = { 12, 12, 22 },
		fogEnd = 240,
		decor = { rocks = 18, pillars = 16, props = 6 },
		propColor = { 90, 60, 140 },
	},
}

local MapThemes = {}

MapThemes.THEMES = THEMES

-- Roblox 측 변환 헬퍼 (Lune 에서는 호출하지 않는다)
function MapThemes.toColor3(rgb: RGB): Color3
	return Color3.fromRGB(rgb[1], rgb[2], rgb[3])
end

function MapThemes.toMaterial(name: string): Enum.Material
	local ok, mat = pcall(function()
		return (Enum.Material :: any)[name]
	end)
	if ok and mat then
		return mat
	end
	return Enum.Material.SmoothPlastic
end

function MapThemes.get(zoneId: string): MapTheme
	return THEMES[zoneId] or THEMES.Midgard_Forest
end

function MapThemes.all(): { MapTheme }
	local out = {}
	for _, id in { "Midgard_Forest", "Kusodia", "Alfheim", "Muspelheim", "Niflheim", "Svartalfheim", "Nidavellir", "Hel", "Abyss" } do
		local t = THEMES[id]
		if t then
			table.insert(out, t)
		end
	end
	return out
end

return MapThemes
