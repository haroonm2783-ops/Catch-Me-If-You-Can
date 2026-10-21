-- An isolated client-side stage in the real workspace for the Shop's "Trail Studio". ViewportFrames cannot draw
-- Trail or ParticleEmitter objects, so to show the REAL effect behind a running avatar the Shop borrows the world camera
-- and points it at this small colorful stage, built far above the mall where nobody can see or reach it.
--
--   scene:Enter(accent)  builds the stage, takes the camera (Scriptable) and switches player controls off
--   scene:Exit()         destroys the stage, hands the camera back and switches controls on
--
-- Everything is local to this client: nothing replicates, nothing changes server state, other players never see it.
-- If controls cannot be switched off, Enter refuses (returns false) rather than leaving the player steering blind.
local PreviewScene = {}
PreviewScene.__index = PreviewScene

PreviewScene.Origin = Vector3.new(0, 4200, 0)
local RADIUS = 11

function PreviewScene.new(opts)
	return setmetatable({
		workspace = opts.workspace, controls = opts.controls, humanoid = opts.humanoid, active = false, saved = nil, folder = nil,
	}, PreviewScene)
end

local function block(folder, name, size, cframe, color, material, shape)
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored, part.CanCollide, part.CanTouch, part.CanQuery, part.CastShadow = true, false, false, false, false
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	if shape then part.Shape = shape end
	part.TopSurface, part.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	part.Parent = folder
	return part
end

-- A cheerful little arena: a sand-colored track disc with an accent ring, and a ring of tall pennant panels for depth.
-- `floor` is where the avatar's feet are, relative to the origin; the ground sits just below so footprints stay visible.
function PreviewScene:_build(accent, floor)
	local folder = Instance.new("Folder")
	folder.Name = "CatchTrailStudio"
	folder.Parent = self.workspace
	local origin = PreviewScene.Origin
	local floorY = origin.Y + (floor or -3.0)
	local groundTop = floorY - 0.1
	local function disc(name, diameter, thickness, top, color, material)
		block(folder, name, Vector3.new(thickness, diameter, diameter), CFrame.new(origin.X, top - thickness / 2, origin.Z) * CFrame.Angles(0, 0, math.rad(90)), color, material, Enum.PartType.Cylinder)
	end
	disc("Ground", RADIUS * 4.2, 1.2, groundTop, Color3.fromRGB(240, 214, 160), Enum.Material.Slate)
	disc("TrackRing", RADIUS * 2.4, 0.05, groundTop + 0.05, accent or Color3.fromRGB(255, 140, 90), Enum.Material.SmoothPlastic)
	disc("TrackInner", RADIUS * 1.5, 0.05, groundTop + 0.08, Color3.fromRGB(252, 236, 200), Enum.Material.Slate)
	local palette = {Color3.fromRGB(255, 94, 84), Color3.fromRGB(255, 196, 30), Color3.fromRGB(0, 175, 180), Color3.fromRGB(50, 150, 255), Color3.fromRGB(255, 130, 200)}
	for index = 1, 14 do
		local angle = index * math.pi * 2 / 14
		local height = 16 + (index % 3) * 5
		local position = Vector3.new(origin.X + math.sin(angle) * (RADIUS * 2.1), groundTop + height / 2, origin.Z + math.cos(angle) * (RADIUS * 2.1))
		block(folder, "Pennant" .. index, Vector3.new(4.5, height, 1), CFrame.lookAt(position, Vector3.new(origin.X, position.Y, origin.Z)), palette[(index % #palette) + 1], Enum.Material.SmoothPlastic)
	end
	return folder
end

function PreviewScene:Enter(accent, floor)
	if self.active then return true end
	local camera = self.workspace.CurrentCamera
	if not camera or not self.controls then return false end
	-- Steering must be off before the camera is taken: a moving character under a free camera would run in odd directions.
	local ok = pcall(function() self.controls:Disable() end)
	if not ok then return false end
	self.saved = {type = camera.CameraType, subject = camera.CameraSubject, fov = camera.FieldOfView, cframe = camera.CFrame}
	camera.CameraType = Enum.CameraType.Scriptable
	self.folder = self:_build(accent, floor)
	self.active = true
	return true
end

function PreviewScene:Camera() return self.workspace.CurrentCamera end
function PreviewScene:World() return self.folder end

function PreviewScene:Exit()
	if not self.active and not self.folder then return end
	self.active = false
	if self.folder then self.folder:Destroy() self.folder = nil end
	local camera = self.workspace.CurrentCamera
	local saved = self.saved
	self.saved = nil
	if camera then
		camera.CameraType = Enum.CameraType.Custom
		local humanoid = self.humanoid and self.humanoid()
		camera.CameraSubject = humanoid or (saved and saved.subject) or camera.CameraSubject
		if saved then camera.FieldOfView = saved.fov end
	end
	if self.controls then pcall(function() self.controls:Enable() end) end
end

return PreviewScene
