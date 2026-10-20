-- Primitive builders shared by every mall module. Everything is anchored, original geometry.
-- Collision policy: solid architecture and furniture collide; small decoration never does,
-- so props can never snag a sprinting avatar or block a tag raycast.
local Kit = {}

local C = Color3.fromRGB
-- ART DIRECTION: "Sunburst Mall". Cheerful, saturated, toy-like colors with warm neutrals. Large surfaces
-- (floors, walls) stay mid-tone so nothing blows out; whites are warm; glow is reserved for screens and bulbs.
Kit.P = {
	cream = C(247, 230, 196), white = C(250, 246, 238), ink = C(40, 44, 78), stone = C(228, 202, 160),
	coral = C(255, 94, 84), teal = C(0, 175, 180), sun = C(255, 196, 30), violet = C(128, 88, 230),
	pink = C(255, 100, 170), sky = C(50, 150, 255), mint = C(70, 210, 140), orange = C(255, 138, 30),
	navy = C(36, 62, 140), red = C(226, 48, 62), lime = C(140, 210, 50), wood = C(200, 140, 84),
	darkwood = C(120, 78, 50), steel = C(160, 172, 190), grey = C(190, 194, 206), dark = C(54, 58, 84),
	glass = C(150, 215, 245), leaf = C(70, 185, 90), soil = C(96, 70, 54), gold = C(255, 196, 60),
	black = C(32, 32, 42), blush = C(255, 205, 215), peach = C(255, 208, 170), lilac = C(206, 190, 250),
	-- Deeper tones for large store walls and floors.
	deepTeal = C(18, 120, 130), deepCoral = C(214, 70, 70), deepViolet = C(92, 62, 170), deepBlue = C(30, 70, 160),
	sand = C(236, 214, 170), terracotta = C(214, 120, 90), butter = C(255, 232, 140), seafoam = C(160, 230, 200), honey = C(222, 188, 128),
}

-- Parts allowed to keep the Neon material. Everything else that asks for Neon is built as plain colored
-- plastic, so the mall reads as cheerful and solid rather than glowing. Screens, bulbs and coins glow.
Kit.GlowNames = {
	MallCoin = true, CoinInner = true, Lamp = true, TVScreen = true, CabinetScreen = true, CabinetMarquee = true,
	ScreenWall = true, RegisterScreen = true, FridgeGlass = true, ConsoleScreen = true, MarqueeBulb = true,
	DanceTile = true, StatusBoard = true,
}

-- Parts that must never be culled: gameplay markers and light sources.
Kit.KeepVisible = {MallCoin = true, CoinInner = true, Lamp = true, PromptPart = true}

function Kit.new(model)
	local kit = {
		model = model, count = 0, lights = 0, signs = 0, detail = 0, emitters = 0, P = Kit.P,
		hideSpots = {}, coins = {}, landmarks = {}, covers = {}, doors = {},
	}

	function kit.group(name, parent)
		local folder = Instance.new("Folder")
		folder.Name = name
		folder.Parent = parent or model
		return folder
	end

	-- Core part factory. `opts`: shape (Ball|Cylinder|Can|Wedge), transparency, shadow, cover, attrs.
	function kit.part(parent, name, size, cf, color, material, collide, opts)
		opts = opts or {}
		if material == Enum.Material.Neon and not (opts.glow or Kit.GlowNames[name]) then material = Enum.Material.SmoothPlastic end
		local shape = opts.shape
		if typeof(cf) == "Vector3" then cf = CFrame.new(cf) end
		local part = Instance.new(shape == "Wedge" and "WedgePart" or "Part")
		part.Name = name
		if shape == "Can" then
			part.Size = Vector3.new(size.Y, size.X, size.Z)
			cf = cf * CFrame.Angles(0, 0, math.pi / 2)
			part.Shape = Enum.PartType.Cylinder
		else
			part.Size = size
			if shape == "Ball" then part.Shape = Enum.PartType.Ball end
			if shape == "Cylinder" then part.Shape = Enum.PartType.Cylinder end
		end
		part.CFrame = cf
		part.Color = color or Kit.P.cream
		part.Material = material or Enum.Material.SmoothPlastic
		part.Anchored = true
		part.CanCollide = collide == true
		part.CanTouch = false
		part.CanQuery = part.CanCollide
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		local biggest = math.max(size.X, size.Y, size.Z)
		if opts.shadow ~= nil then part.CastShadow = opts.shadow
		else part.CastShadow = part.CanCollide and biggest >= 8 and material ~= Enum.Material.Neon end
		if opts.transparency then part.Transparency = opts.transparency end
		if opts.cover then
			part:SetAttribute("Cover", opts.cover)
			table.insert(kit.covers, part)
		end
		if opts.vault then part:SetAttribute("Vaultable", true) end
		-- Small non-colliding decoration: the client may hide it by distance on weaker devices (see PerformanceController).
		if not part.CanCollide and biggest < 3 and not Kit.KeepVisible[name] and string.sub(name, 1, 5) ~= "Sign_" then
			part:SetAttribute("CatchDetail", true)
			kit.detail += 1
		end
		if opts.attrs then for key, value in pairs(opts.attrs) do part:SetAttribute(key, value) end end
		part.Parent = parent
		kit.count += 1
		return part
	end

	-- World-space centre-based box.
	function kit.box(parent, name, cx, cy, cz, sx, sy, sz, color, material, collide, opts)
		return kit.part(parent, name, Vector3.new(sx, sy, sz), Vector3.new(cx, cy, cz), color, material, collide, opts)
	end
	-- Box spanning [x0,x1] x [y0,y1] x [z0,z1].
	function kit.span(parent, name, x0, x1, y0, y1, z0, z1, color, material, collide, opts)
		return kit.box(parent, name, (x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2, x1 - x0, y1 - y0, z1 - z0, color, material, collide, opts)
	end
	function kit.can(parent, name, cx, cy, cz, diameter, height, color, material, collide, opts)
		opts = opts or {}
		opts.shape = "Can"
		return kit.part(parent, name, Vector3.new(diameter, height, diameter), Vector3.new(cx, cy, cz), color, material, collide, opts)
	end
	function kit.ball(parent, name, cx, cy, cz, sx, sy, sz, color, material, collide, opts)
		opts = opts or {}
		opts.shape = "Ball"
		return kit.part(parent, name, Vector3.new(sx, sy, sz), Vector3.new(cx, cy, cz), color, material, collide, opts)
	end

	-- A beam between two points (visual by default).
	function kit.beam(parent, name, a, b, width, color, material, collide)
		local direction = b - a
		local up = math.abs(direction.Unit.Y) > 0.99 and Vector3.xAxis or Vector3.yAxis
		return kit.part(parent, name, Vector3.new(width, width, direction.Magnitude), CFrame.lookAt((a + b) / 2, b, up), color, material, collide)
	end

	-- A text sign. `cf` places the backing plate; the readable face looks along the plate's -Z.
	function kit.sign(parent, text, cf, width, height, textColor, backColor, opts)
		opts = opts or {}
		local backing = kit.part(parent, "Sign_" .. text, Vector3.new(width, height, 0.4), cf, backColor or Kit.P.ink, opts.material, false, {shadow = false})
		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Front
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = opts.pixels or 30
		gui.LightInfluence = 0
		gui.MaxDistance = opts.distance or 130
		gui.Parent = backing
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(0.94, 0.8)
		label.Position = UDim2.fromScale(0.03, 0.1)
		label.BackgroundTransparency = 1
		label.Text = text
		label.TextColor3 = textColor or Kit.P.white
		label.TextScaled = true
		label.FontFace = Font.fromEnum(opts.font or Enum.Font.FredokaOne)
		label.TextStrokeColor3 = opts.stroke or Kit.P.ink
		label.TextStrokeTransparency = opts.noStroke and 1 or 0.35
		label.Parent = gui
		kit.signs += 1
		return backing
	end

	-- Small emissive bulb with a shadowless point light. Lights are budgeted: use sparingly.
	function kit.lamp(parent, pos, color, brightness, range)
		local bulb = kit.box(parent, "Lamp", pos.X, pos.Y, pos.Z, 1.2, 0.3, 1.2, color, Enum.Material.Neon, false)
		local light = Instance.new("PointLight")
		light.Color = color
		light.Brightness = brightness or 0.8
		light.Range = range or 24
		light.Shadows = false
		light.Parent = bulb
		kit.lights += 1
		return bulb
	end

	-- Ambient particles. Budgeted (see tests) and switched off or halved by the client's performance tier.
	-- kinds: "spray" (fountain water), "sparkle" (glitter), "steam" (kitchen vapour).
	function kit.emitter(part, kind)
		local e = Instance.new("ParticleEmitter")
		e.Name = "Ambient_" .. kind
		e.LockedToPart = false
		e.Shape = Enum.ParticleEmitterShape.Box
		if kind == "spray" then
			e.Rate, e.Lifetime, e.Speed, e.SpreadAngle = 22, NumberRange.new(1.1, 1.7), NumberRange.new(9, 13), Vector2.new(22, 22)
			e.Acceleration = Vector3.new(0, -28, 0)
			e.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.7), NumberSequenceKeypoint.new(1, 0.15)})
			e.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 1)})
			e.Color = ColorSequence.new(Color3.fromRGB(190, 230, 255), Color3.fromRGB(255, 255, 255))
			e.LightEmission = 0.35
		elseif kind == "sparkle" then
			e.Rate, e.Lifetime, e.Speed, e.SpreadAngle = 6, NumberRange.new(1.2, 2.2), NumberRange.new(1, 3), Vector2.new(180, 180)
			e.Acceleration = Vector3.new(0, 1.5, 0)
			e.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(0.5, 0.35), NumberSequenceKeypoint.new(1, 0)})
			e.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1)})
			e.Color = ColorSequence.new(Color3.fromRGB(255, 226, 120), Color3.fromRGB(255, 160, 220))
			e.LightEmission = 0.8
		else
			e.Rate, e.Lifetime, e.Speed, e.SpreadAngle = 3, NumberRange.new(1.8, 2.8), NumberRange.new(1.5, 2.5), Vector2.new(15, 15)
			e.Acceleration = Vector3.new(0, 1, 0)
			e.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 2.2)})
			e.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.7), NumberSequenceKeypoint.new(1, 1)})
			e.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255))
		end
		e.Parent = part
		kit.emitters += 1
		return e
	end

	-- Local frame: origin on the floor, yaw about Y; boxes are bottom-based (`y0` is the base height).
	function kit.frame(parent, origin, yaw, baseY)
		local f = {parent = parent, yaw = yaw}
		local base = CFrame.new(origin.X, baseY or origin.Y, origin.Z) * CFrame.Angles(0, yaw, 0)
		f.base = base
		function f.pos(lx, y, lz) return base:PointToWorldSpace(Vector3.new(lx, y, lz)) end
		function f.cf(lx, y, lz, rx, ry, rz)
			return base * CFrame.new(lx, y, lz) * CFrame.Angles(math.rad(rx or 0), math.rad(ry or 0), math.rad(rz or 0))
		end
		-- Box whose bottom is at y0, centred on (lx, lz).
		function f.b(name, lx, y0, lz, sx, sy, sz, color, material, collide, opts)
			return kit.part(parent, name, Vector3.new(sx, sy, sz), base * CFrame.new(lx, y0 + sy / 2, lz), color, material, collide, opts)
		end
		-- Tilted box: rotation in degrees about the box centre.
		function f.t(name, lx, y0, lz, sx, sy, sz, rx, ry, rz, color, material, collide, opts)
			return kit.part(parent, name, Vector3.new(sx, sy, sz), f.cf(lx, y0 + sy / 2, lz, rx, ry, rz), color, material, collide, opts)
		end
		function f.can(name, lx, y0, lz, d, h, color, material, collide, opts)
			opts = opts or {}
			opts.shape = "Can"
			return kit.part(parent, name, Vector3.new(d, h, d), base * CFrame.new(lx, y0 + h / 2, lz), color, material, collide, opts)
		end
		function f.ball(name, lx, y0, lz, sx, sy, sz, color, material, collide, opts)
			opts = opts or {}
			opts.shape = "Ball"
			return kit.part(parent, name, Vector3.new(sx, sy, sz), base * CFrame.new(lx, y0 + sy / 2, lz), color, material, collide, opts)
		end
		function f.wedge(name, lx, y0, lz, sx, sy, sz, ry, color, material, collide, opts)
			opts = opts or {}
			opts.shape = "Wedge"
			return kit.part(parent, name, Vector3.new(sx, sy, sz), f.cf(lx, y0 + sy / 2, lz, 0, ry or 0, 0), color, material, collide, opts)
		end
		-- Sign plate whose readable side faces local -Z (outward from a store); `inward` turns it +Z.
		function f.sign(text, lx, y0, lz, w, h, textColor, backColor, inward, opts)
			local cf = base * CFrame.new(lx, y0 + h / 2, lz) * CFrame.Angles(0, inward and math.pi or 0, 0)
			return kit.sign(parent, text, cf, w, h, textColor, backColor, opts)
		end
		function f.lamp(lx, y0, lz, color, brightness, range) return kit.lamp(parent, f.pos(lx, y0, lz), color, brightness, range) end
		return f
	end

	return kit
end

return Kit
