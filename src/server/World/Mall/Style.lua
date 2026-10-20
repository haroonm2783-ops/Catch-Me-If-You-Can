-- Per-store art direction for "Sunburst Mall". Each theme sets bold wall and floor colors, an awning pair and a
-- big icon, so every shop has its own recognizable identity from the corridor. Themes only change appearance:
-- no collision, layout or hiding spot reads from here.
local C = Color3.fromRGB
local Style = {}

local M = Enum.Material

-- Built from the kit palette so the module has no sibling requires (MallBuilder passes `kit.P`).
function Style.new(P)
local style = {}
-- wall: interior/shopfront wall. floor: carpet/inlay color. mat: floor material. trim: door frame, cornice and
-- baseboard color. awning: two stripe colors. icon: emoji on the blade sign. light: warm point-light tint.
style.themes = {
	["FASHION HOUSE"]     = {wall = C(255, 172, 204), floor = C(214, 90, 140), mat = M.Fabric, trim = P.pink, awning = {P.pink, P.white}, icon = "👗", light = C(255, 214, 230)},
	["VOLT ELECTRONICS"]  = {wall = C(40, 62, 130), floor = C(30, 38, 84), mat = M.SmoothPlastic, trim = P.sky, awning = {P.sky, P.navy}, icon = "🎮", light = C(200, 225, 255)},
	["SNEAKER PALACE"]    = {wall = C(255, 214, 96), floor = C(222, 156, 88), mat = M.WoodPlanks, trim = P.orange, awning = {P.orange, P.white}, icon = "👟", light = C(255, 236, 190)},
	["MEGA DEPARTMENT"]   = {wall = C(40, 170, 170), floor = P.sand, mat = M.Slate, trim = P.teal, awning = {P.teal, P.white}, icon = "🛍️", light = C(220, 250, 245)},
	["QUICK MART"]        = {wall = C(110, 200, 80), floor = P.butter, mat = M.SmoothPlastic, trim = P.lime, awning = {P.lime, P.white}, icon = "🛒", light = C(245, 255, 220)},
	["TOY KINGDOM"]       = {wall = C(90, 170, 255), floor = C(255, 214, 80), mat = M.Fabric, trim = P.sun, awning = {P.red, P.sun}, icon = "🧸", light = C(255, 245, 210)},
	["SPARKLE & CO"]      = {wall = C(112, 80, 196), floor = C(84, 50, 140), mat = M.Fabric, trim = P.gold, awning = {P.violet, P.gold}, icon = "💎", light = C(255, 235, 200)},
	["SPORTS ZONE"]       = {wall = C(70, 180, 110), floor = C(44, 130, 86), mat = M.SmoothPlastic, trim = P.orange, awning = {P.lime, P.white}, icon = "⚽", light = C(235, 255, 225)},
	["GLOW BEAUTY BAR"]   = {wall = C(255, 150, 172), floor = C(255, 214, 224), mat = M.SmoothPlastic, trim = P.coral, awning = {P.coral, P.white}, icon = "💄", light = C(255, 226, 234)},
	["BOOKWORM BOOKS"]    = {wall = C(188, 120, 80), floor = C(150, 84, 64), mat = M.Fabric, trim = P.cream, awning = {P.red, P.cream}, icon = "📚", light = C(255, 226, 180)},
	["COZY NEST HOME"]    = {wall = C(150, 222, 190), floor = C(206, 150, 96), mat = M.WoodPlanks, trim = P.mint, awning = {P.mint, P.white}, icon = "🛋️", light = C(255, 240, 210)},
	["NOIR & GOLD"]       = {wall = C(70, 62, 84), floor = C(106, 48, 112), mat = M.Marble, trim = P.gold, awning = {P.black, P.gold}, icon = "👜", light = C(255, 228, 180)},
	["GAME ZONE ARCADE"]  = {wall = C(56, 40, 110), floor = C(30, 26, 60), mat = M.SmoothPlastic, trim = P.pink, awning = {P.violet, P.pink}, icon = "🕹️", light = C(235, 215, 255)},
	["STARLIGHT CINEMA"]  = {wall = C(120, 40, 62), floor = C(160, 40, 70), mat = M.Fabric, trim = P.gold, awning = {P.red, P.gold}, icon = "🎬", light = C(255, 220, 190)},
	["JUNGLE JUMP KIDS"]  = {wall = C(110, 215, 120), floor = C(255, 214, 70), mat = M.Fabric, trim = P.sun, awning = {P.lime, P.sun}, icon = "🐵", light = C(250, 255, 215)},
	["FOOD COURT"]        = {wall = C(255, 196, 120), floor = P.terracotta, mat = M.Slate, trim = P.orange, awning = {P.red, P.white}, icon = "🍔", light = C(255, 236, 200)},
	["RESTROOMS"]         = {wall = C(96, 190, 245), floor = P.white, mat = M.SmoothPlastic, trim = P.sky, awning = {P.sky, P.white}, icon = "🚻", light = C(230, 245, 255)},
	["PET PALACE"]        = {wall = C(255, 200, 150), floor = C(180, 220, 150), mat = M.Fabric, trim = P.orange, awning = {P.orange, P.cream}, icon = "🐾", light = C(255, 240, 215)},
	["SNAP STUDIO"]       = {wall = C(240, 190, 245), floor = P.lilac, mat = M.SmoothPlastic, trim = P.pink, awning = {P.pink, P.lilac}, icon = "📸", light = C(255, 230, 250)},
	["BEAT BOX MUSIC"]    = {wall = C(100, 66, 156), floor = C(54, 36, 90), mat = M.Fabric, trim = P.coral, awning = {P.coral, P.violet}, icon = "🎸", light = C(255, 220, 230)},
	["FIT ZONE GYM"]      = {wall = C(60, 110, 180), floor = C(44, 50, 70), mat = M.SmoothPlastic, trim = P.sky, awning = {P.sky, P.white}, icon = "🏋️", light = C(225, 238, 255)},
}

-- Food stalls and restrooms share a theme through the first word(s) of their name.
function style.themeFor(name)
	local exact = style.themes[name]
	if exact then return exact end
	if string.sub(name, 1, 10) == "FOOD COURT" then return style.themes["FOOD COURT"] end
	if string.sub(name, 1, 9) == "RESTROOMS" then return style.themes["RESTROOMS"] end
	return nil
end

-- Brand colors shared by the exterior and hub.
style.Brand = {primary = P.coral, secondary = P.sun, accent = P.teal, ink = P.ink, cream = P.cream}
return style
end

return Style
