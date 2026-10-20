-- Outside the arena: the sunburst mall entrance and the compact spawn hub in front of it. The hub is a
-- self-contained 100 x 78 stud plaza (outside the arena, so spectators can never body-block a chase) packed
-- with things to do and read: a chevron path to the entrance, the winners' podium, two leaderboards, a Shop
-- and a Locker kiosk, palms, benches and bunting. HubService fills in the live boards at runtime.
local Exterior = {}

-- Hub footprint (world space). The mall facade is at z = -154.
local HUB = {x0 = -50, x1 = 50, z0 = -232, z1 = -154}

local function surfaceLabel(parent, name, text, size, position, color, font, align)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Size = size
	label.Position = position
	label.Text = text
	label.TextScaled = true
	label.TextColor3 = color
	label.FontFace = Font.fromEnum(font or Enum.Font.FredokaOne)
	label.TextXAlignment = align or Enum.TextXAlignment.Center
	label.TextStrokeColor3 = Color3.fromRGB(40, 44, 78)
	label.TextStrokeTransparency = 0.4
	label.Parent = parent
	return label
end

local function surfaceGui(part, pixels)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Board"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = pixels or 30
	gui.LightInfluence = 0
	gui.MaxDistance = 260
	gui.Parent = part
	return gui
end

function Exterior.build(kit, Layout, Decor)
	local P = kit.P
	local lot = kit.group("Facade")
	local hub = kit.group("Hub")
	local sky = kit.group("Skyline")
	local SZ = Layout.Service.z
	local zFace = -SZ - 1.6

	-- ---------------------------------------------------------------------------------------------
	-- The sunburst entrance: two striped towers, a big sign, a status board and a canopy over glass doors.
	-- ---------------------------------------------------------------------------------------------
	-- Base dado and colored bands along the whole facade.
	kit.box(lot, "FacadeDado", 0, 4, zFace, 324, 8, 0.6, P.deepTeal, Enum.Material.SmoothPlastic, false)
	kit.box(lot, "FacadeBandCoral", 0, 30, zFace, 324, 4.5, 0.6, P.coral, Enum.Material.SmoothPlastic, false)
	kit.box(lot, "FacadeBandSun", 0, 33.4, zFace, 324, 1.4, 0.6, P.sun, Enum.Material.SmoothPlastic, false)
	for x = -150, 150, 30 do
		if math.abs(x) > 34 then
			kit.box(lot, "FacadeWindow", x, 14, zFace - 0.2, 20, 9, 0.3, P.glass, Enum.Material.Glass, false, {transparency = 0.35})
			kit.box(lot, "FacadeWindowFrame", x, 14, zFace - 0.35, 21.6, 10.6, 0.2, P.cream, Enum.Material.SmoothPlastic, false)
			kit.box(lot, "FacadeWindowSill", x, 8.4, zFace - 1, 22, 0.6, 1.8, P.deepCoral, Enum.Material.SmoothPlastic, false)
		end
	end
	for _, x in ipairs({-110, -70, 70, 110}) do
		kit.box(lot, "BannerPole", x, 20, zFace - 1, 0.6, 40, 0.6, P.steel, Enum.Material.Metal, false)
		kit.box(lot, "FacadeBanner", x, 22, zFace - 2, 8, 24, 0.3, ({P.pink, P.sky, P.sun, P.mint})[(x // 40 % 4) + 1], Enum.Material.Fabric, false)
	end
	-- Glass entrance doors with a warm interior glow panel behind them.
	kit.box(lot, "EntranceBacking", 0, 11, zFace + 0.25, 40, 22, 0.3, P.deepTeal, Enum.Material.SmoothPlastic, false)
	kit.box(lot, "EntranceGlow", 0, 11, zFace - 0.05, 36, 18, 0.2, P.butter, Enum.Material.SmoothPlastic, false, {shadow = false})
	kit.box(lot, "EntranceGlass", 0, 11, zFace - 0.4, 40, 22, 0.3, P.glass, Enum.Material.Glass, false, {transparency = 0.5, shadow = false})
	for i = -2, 2 do kit.box(lot, "EntranceMullion", i * 10, 11, zFace - 0.6, 0.8, 22, 0.5, P.steel, Enum.Material.Metal, false) end
	kit.box(lot, "EntranceMullion", 0, 22, zFace - 0.6, 40, 0.8, 0.5, P.steel, Enum.Material.Metal, false)
	for _, x in ipairs({-3.4, 3.4}) do kit.box(lot, "DoorHandle", x, 10, zFace - 0.9, 0.4, 4, 0.5, P.gold, Enum.Material.Metal, false) end
	kit.box(lot, "EntranceMat", 0, 0.08, zFace - 4, 30, 0.12, 6, P.coral, Enum.Material.Fabric, false, {shadow = false})
	-- Towers.
	for _, side in ipairs({-1, 1}) do
		local x = side * 26
		kit.box(lot, "GateTower", x, 26, zFace - 3, 8, 52, 6, P.coral, Enum.Material.SmoothPlastic, true)
		for _, y in ipairs({10, 24, 38}) do
			kit.box(lot, "GateStripe", x, y, zFace - 3, 8.4, 2.4, 6.4, P.sun, Enum.Material.SmoothPlastic, false)
		end
		kit.ball(lot, "GateCap", x, 54, zFace - 3, 8, 6, 6.4, P.teal, Enum.Material.SmoothPlastic, false)
	end
	kit.box(lot, "GateHeader", 0, 48, zFace - 3, 44, 8, 6, P.teal, Enum.Material.SmoothPlastic, true)
	kit.box(lot, "GateHeaderTrim", 0, 52.4, zFace - 3, 46, 0.9, 6.6, P.sun, Enum.Material.SmoothPlastic, false)
	kit.sign(lot, "CATCH MALL", CFrame.new(0, 48, zFace - 6.2), 40, 6.4, P.white, P.coral, {pixels = 34, distance = 700, material = Enum.Material.SmoothPlastic})
	kit.sign(lot, "CATCH ME IF YOU CAN", CFrame.new(0, 43.2, zFace - 6.2), 30, 2.6, P.sun, P.ink, {pixels = 34, distance = 500})
	-- Live status board above the doors (HubService writes the text).
	local board = kit.box(lot, "StatusBoard", 0, 35.6, zFace - 6.2, 30, 7, 0.5, P.ink, Enum.Material.SmoothPlastic, false, {shadow = false})
	local gui = surfaceGui(board, 30)
	surfaceLabel(gui, "Phase", "WELCOME TO THE MALL", UDim2.fromScale(0.94, 0.3), UDim2.fromScale(0.03, 0.04), P.sun)
	surfaceLabel(gui, "Timer", "--:--", UDim2.fromScale(0.5, 0.5), UDim2.fromScale(0.25, 0.32), P.white)
	surfaceLabel(gui, "Players", "0 PLAYERS", UDim2.fromScale(0.94, 0.2), UDim2.fromScale(0.03, 0.78), P.mint)
	kit.box(lot, "StatusFrame", 0, 35.6, zFace - 6.0, 31.2, 8.2, 0.3, P.sun, Enum.Material.SmoothPlastic, false)
	-- Striped canopy over the doors.
	Decor.awning(kit, lot, 0, 24.6, zFace - 8, 52, 9, P.coral, P.cream, 4)
	-- The sunburst brand mark: a big yellow sun with rays above the gate.
	local sun = kit.part(lot, "SunburstDisc", Vector3.new(1, 26, 26), CFrame.new(0, 66, zFace - 3.6) * CFrame.Angles(0, math.pi / 2, 0), P.sun, Enum.Material.SmoothPlastic, false, {shape = "Cylinder", shadow = false})
	kit.part(lot, "SunburstCore", Vector3.new(1, 17, 17), CFrame.new(0, 66, zFace - 4.1) * CFrame.Angles(0, math.pi / 2, 0), P.butter, Enum.Material.SmoothPlastic, false, {shape = "Cylinder", shadow = false})
	for i = 0, 10 do
		local a = math.rad(-8 + i * 19.6)
		local r = 24
		local pos = Vector3.new(math.cos(a) * r, 66 + math.sin(a) * r, zFace - 3.3)
		kit.part(lot, "SunburstRay", Vector3.new(11, 2.6, 0.8), CFrame.new(pos) * CFrame.Angles(0, 0, a), i % 2 == 0 and P.sun or P.orange, Enum.Material.SmoothPlastic, false, {shadow = false})
	end
	kit.sign(lot, "WELCOME", CFrame.new(0, 66, zFace - 4.8), 15, 3.6, P.ink, P.butter, {pixels = 34, distance = 700, noStroke = true, material = Enum.Material.SmoothPlastic})
	sun.Name = "SunburstDisc"

	-- ---------------------------------------------------------------------------------------------
	-- Lawn, skyline and trees around the hub.
	-- ---------------------------------------------------------------------------------------------
	for i = 1, 26 do
		local a = i / 26 * math.pi * 2
		local r = 520 + (i % 3) * 60
		local h = 70 + (i * 37) % 140
		local w = 40 + (i * 13) % 40
		local x, z = math.cos(a) * r, math.sin(a) * r
		kit.box(sky, "Tower", x, h / 2 - 4, z, w, h, w, ({P.sky, P.lilac, P.mint, P.peach, P.seafoam})[(i % 5) + 1], Enum.Material.SmoothPlastic, false, {shadow = false})
		for k = 1, 4, 2 do kit.box(sky, "TowerWindows", x, 10 + k * (h / 5), z - w / 2 - 0.1, w * 0.8, 3, 0.2, P.white, Enum.Material.SmoothPlastic, false, {shadow = false}) end
	end
	for _, spec in ipairs({{-64, -172}, {64, -172}, {-66, -196}, {66, -196}, {-64, -222}, {64, -222}, {-30, -246}, {30, -246}, {0, -252}}) do
		Decor.tree(kit, hub, spec[1], -1.2, spec[2], 1.1, {P.leaf, P.lime, P.mint})
	end

	-- ---------------------------------------------------------------------------------------------
	-- The hub plaza.
	-- ---------------------------------------------------------------------------------------------
	local cx, cz = (HUB.x0 + HUB.x1) / 2, (HUB.z0 + HUB.z1) / 2
	local width, depth = HUB.x1 - HUB.x0, HUB.z1 - HUB.z0
	kit.box(hub, "HubDeck", cx, -1, cz, width, 2, depth, P.stone, Enum.Material.Slate, true)
	for ix = 0, 4 do
		for iz = 0, 3 do
			if (ix + iz) % 2 == 0 then
				kit.box(hub, "HubTile", HUB.x0 + ix * 20 + 10, 0.03, HUB.z0 + iz * 20 + 10, 19.6, 0.06, 19.6, P.terracotta, Enum.Material.Slate, false, {shadow = false})
			end
		end
	end
	-- Chevron path from the spawn pad toward the podium and the entrance.
	kit.box(hub, "HubPath", 0, 0.08, -208, 12, 0.06, 46, P.butter, Enum.Material.SmoothPlastic, false, {shadow = false})
	for k = 0, 5 do
		local zc = -226 + k * 8
		for _, side in ipairs({-1, 1}) do
			kit.part(hub, "PathChevron", Vector3.new(4.4, 0.06, 1.1), CFrame.new(side * 1.7, 0.13, zc) * CFrame.Angles(0, side * math.rad(40), 0), P.coral, Enum.Material.SmoothPlastic, false, {shadow = false})
		end
	end
	-- Spawn emblem and balloon arch.
	kit.can(hub, "SpawnRing", 0, 0.1, -226, 16, 0.06, P.teal, Enum.Material.SmoothPlastic, false, {shadow = false})
	kit.can(hub, "SpawnRingInner", 0, 0.12, -226, 12, 0.06, P.sun, Enum.Material.SmoothPlastic, false, {shadow = false})
	kit.can(hub, "SpawnRingCore", 0, 0.14, -226, 8, 0.06, P.cream, Enum.Material.SmoothPlastic, false, {shadow = false})
	Decor.balloonArch(kit, hub, 0, 0, -230.5, 9, {P.coral, P.sun, P.teal, P.pink, P.sky})
	kit.sign(hub, "WELCOME!", CFrame.new(0, 14, -231) * CFrame.Angles(0, math.pi, 0), 14, 3, P.white, P.coral, {pixels = 36, distance = 120})
	-- Winners' podium: a stage, a colorful backdrop and a bold sign.
	local py = 0
	kit.box(hub, "PodiumStage", 0, py + 0.6, -176, 44, 1.2, 12, P.deepViolet, Enum.Material.SmoothPlastic, true)
	kit.box(hub, "PodiumStageTrim", 0, py + 1.25, -170.1, 44, 0.2, 0.3, P.sun, Enum.Material.SmoothPlastic, false)
	local podiums = {}
	for i, spec in ipairs({{0, 2.6, "1", P.gold}, {-13, 1.6, "2", P.sky}, {13, 1.0, "3", P.coral}}) do
		local x, h, numeral, accent = spec[1], spec[2], spec[3], spec[4]
		kit.can(hub, "WinnerPodium_" .. numeral, x, py + 1.2 + h / 2, -176, 10, h, P.cream, Enum.Material.SmoothPlastic, true)
		kit.can(hub, "PodiumTop", x, py + 1.2 + h + 0.1, -176, 10.2, 0.25, accent, Enum.Material.SmoothPlastic, false)
		kit.sign(hub, numeral, CFrame.new(x, py + 1.2 + h / 2, -180.8), 3.2, 2.6, P.white, accent, {pixels = 40, distance = 100})
		podiums[i] = CFrame.lookAt(Vector3.new(x, py + 1.2 + h + 3.1, -176), Vector3.new(x, py + 1.2 + h + 3.1, -230))
	end
	kit.box(hub, "PodiumBackdrop", 0, 8, -166.4, 46, 14, 1, P.coral, Enum.Material.SmoothPlastic, false)
	for i = 0, 8 do kit.box(hub, "BackdropStripe", -20 + i * 5, 8, -167.1, 2.4, 14, 0.3, i % 2 == 0 and P.sun or P.pink, Enum.Material.SmoothPlastic, false) end
	kit.sign(hub, "WINNERS", CFrame.new(0, 12.6, -167.6), 26, 5, P.sun, P.ink, {pixels = 34, distance = 260})
	for _, side in ipairs({-1, 1}) do
		kit.box(hub, "StagePylon", side * 22, 8, -166.6, 1.4, 16, 1.4, P.teal, Enum.Material.Metal, false)
		kit.ball(hub, "StagePylonCap", side * 22, 16.6, -166.6, 3, 3, 3, P.sun, Enum.Material.SmoothPlastic, false)
	end

	-- Leaderboards: wins on the west wall, tags on the east wall. HubService writes the rows.
	local function leaderboard(x, yaw, stat, title)
		local f = kit.frame(hub, Vector3.new(x, 0, -200), yaw, 0)
		f.b("BoardLeg", -7, 0, 0, 1, 5, 1, P.dark, Enum.Material.Metal, false)
		f.b("BoardLeg", 7, 0, 0, 1, 5, 1, P.dark, Enum.Material.Metal, false)
		f.b("BoardFrame", 0, 4.4, 0.2, 21.6, 16.6, 0.8, P.sun, Enum.Material.SmoothPlastic, true, {cover = "Full"})
		local face = f.b("HubLeaderboard", 0, 4.8, -0.35, 20, 15.8, 0.5, P.ink, Enum.Material.SmoothPlastic, false, {shadow = false})
		face:SetAttribute("Stat", stat)
		face:SetAttribute("Title", title)
		local g = surfaceGui(face, 30)
		surfaceLabel(g, "Title", title, UDim2.fromScale(0.92, 0.15), UDim2.fromScale(0.04, 0.03), P.sun)
		for row = 1, 5 do
			surfaceLabel(g, "Row" .. row, row .. ".  ---", UDim2.fromScale(0.9, 0.12), UDim2.fromScale(0.05, 0.19 + (row - 1) * 0.15), row == 1 and P.sun or P.white, Enum.Font.GothamBold, Enum.TextXAlignment.Left)
		end
	end
	leaderboard(-46, -math.pi / 2, "Wins", "TOP RUNNERS / WINS")
	leaderboard(46, math.pi / 2, "Tags", "TOP HUNTERS / TAGS")

	-- Shop and Locker kiosks beside the path: stand close and press the prompt to open the menu.
	local function kiosk(x, label, icon, color, menu)
		local f = kit.frame(hub, Vector3.new(x, 0, -214), 0, 0)
		f.b("KioskBase", 0, 0, 0, 9, 4, 5, color, Enum.Material.SmoothPlastic, true, {cover = "Low", vault = true})
		f.b("KioskTop", 0, 4, 0, 9.6, 0.4, 5.6, P.cream, Enum.Material.SmoothPlastic, false)
		for _, sx in ipairs({-4, 4}) do f.b("KioskPole", sx, 4.4, 0, 0.4, 5.6, 0.4, P.steel, Enum.Material.Metal, false) end
		Decor.awning(kit, hub, x, 11, -214 - 1.4, 11, 6.4, color, P.cream, 2.75)
		f.sign(icon .. " " .. label, 0, 6.4, -2.9, 8, 2.4, P.white, color, false, {pixels = 40, distance = 140})
		local promptPart = f.b("PromptPart", 0, 2, -3.2, 5, 4, 0.4, P.white, Enum.Material.SmoothPlastic, false)
		promptPart.Transparency = 1
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "MenuPrompt"
		prompt.ActionText = "Open " .. label
		prompt.ObjectText = icon
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 12
		prompt.RequiresLineOfSight = false
		prompt.Parent = promptPart
		promptPart:SetAttribute("Menu", menu)
	end
	kiosk(-18, "SHOP", "🛒", P.pink, "Shop")
	kiosk(18, "LOCKER", "👕", P.sky, "Inventory")

	-- A signpost with arrows, and the plaza dressing.
	local sf = kit.frame(hub, Vector3.new(9, 0, -204), 0, 0)
	sf.can("PostPole", 0, 0, 0, 0.9, 12, P.darkwood, Enum.Material.Wood, true)
	for i, spec in ipairs({{"MALL ENTRANCE  ↑", P.coral, 0}, {"← SHOP", P.pink, 4}, {"LOCKER →", P.sky, 8}}) do
		sf.sign(spec[1], 0, 3 + (i - 1) * 2.8, -0.6, 8, 2.2, P.white, spec[2], false, {pixels = 40, distance = 110})
	end
	for _, spec in ipairs({{-44, -160}, {44, -160}, {-44, -226}, {44, -226}}) do
		Decor.planterBox(kit, hub, spec[1], 0, spec[2], 9, 9, P.pink)
		Decor.palm(kit, hub, spec[1], 2.4, spec[2], 1.15)
	end
	for _, spec in ipairs({{-32, -190, math.pi / 2}, {32, -190, -math.pi / 2}, {-32, -164, math.pi}, {32, -164, math.pi}}) do
		Decor.bench(kit, hub, spec[1], 0, spec[2], spec[3], P.sun)
	end
	for _, spec in ipairs({{-11, -222}, {11, -222}, {-11, -196}, {11, -196}}) do Decor.lampPost(kit, hub, spec[1], 0, spec[2], P.butter, math.abs(spec[2]) < 205) end
	Decor.bunting(kit, hub, Vector3.new(-50, 13, -222), Vector3.new(50, 13, -222), 22, {P.coral, P.sun, P.teal, P.pink, P.sky, P.lime})
	for _, x in ipairs({-50, 50}) do kit.box(hub, "BuntingPole", x, 7, -222, 0.6, 14, 0.6, P.steel, Enum.Material.Metal, false) end
	-- Hedges frame the plaza; invisible walls keep it self-contained.
	for _, side in ipairs({-1, 1}) do
		kit.box(hub, "Hedge", side * 51.6, 2.5, cz, 3, 5, depth, P.leaf, Enum.Material.SmoothPlastic, true, {shadow = false})
		kit.box(hub, "HedgeSouth", side * 31, 2.5, HUB.z0 - 1.5, 38, 5, 3, P.leaf, Enum.Material.SmoothPlastic, true, {shadow = false})
	end
	for _, e in ipairs({{-52, cz, 2, depth + 6}, {52, cz, 2, depth + 6}, {0, HUB.z0 - 2, 108, 2}}) do
		local wall = kit.box(hub, "HubBoundary", e[1], 25, e[2], e[3], 50, e[4], P.ink, Enum.Material.SmoothPlastic, true, {shadow = false})
		wall.Transparency = 1
	end
	-- The spawn pad.
	local lobbySpawn = CFrame.lookAt(Vector3.new(0, 3.2, -226), Vector3.new(0, 3.2, -176))
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "LobbySpawn"
	spawn.Size = Vector3.new(8, 0.2, 8)
	spawn.CFrame = CFrame.new(0, 0.1, -226)
	spawn.Transparency = 1
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.CanTouch = false
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = hub
	kit.count += 1
	return {LobbySpawn = lobbySpawn, Podiums = podiums}
end

return Exterior
