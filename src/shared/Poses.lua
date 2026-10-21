-- Procedural posing for emotes, victories and previews. No uploaded animations are used, so there are no
-- animation-asset permissions to configure: a pose is a table of small CFrame offsets keyed by joint name
-- ("RightShoulder", "Waist", "Root"...). Each offset is expressed in the PARENT part's frame and rotates (and
-- moves) the child about its joint, so the same pose reads the same on R15 and R6 rigs.
--
--   Poses.Live(rig)      drives real Motor6D.C0 values (live characters). Call :Apply(pose, weight), :Restore().
--   Poses.Preview(rig)   drives ANCHORED showroom models (ViewportFrame previews, podium winners) by forward
--                        kinematics, moving the body, its accessories and every cosmetic overlay part together.
--
-- Rotation cheat sheet for authors (character faces -Z, its right hand is +X):
--   limbs hang along -Y.  +X swings a limb FORWARD, +Z swings it toward +X (outward for the right arm, so the
--   left arm uses negative Z).  An upright part (torso, head) tilts BACKWARD with +X and forward with -X.
local Poses = {}

local ALIASES = {RootJoint = "Root"}
local function jointName(name)
	local normal = string.gsub(name, "%s", "")
	return ALIASES[normal] or normal
end
Poses.JointName = jointName

-- Rotation + optional translation, applied about the joint pivot in the parent's frame.
local function aboutPivot(pivot, delta)
	return CFrame.new(delta.Position) * CFrame.new(pivot) * (delta - delta.Position) * CFrame.new(-pivot)
end

-- Blend a pose toward neutral. weight 1 = full pose, 0 = rest.
function Poses.Blend(pose, weight)
	if weight >= 0.999 then return pose end
	local result = {}
	for name, delta in pairs(pose) do result[name] = CFrame.new():Lerp(delta, math.max(0, weight)) end
	return result
end

-- ---------------------------------------------------------------------------------------
-- Live characters
-- ---------------------------------------------------------------------------------------
local Live = {}
Live.__index = Live

function Poses.Live(rig)
	local joints = {}
	for _, descendant in ipairs(rig:GetDescendants()) do
		if descendant:IsA("Motor6D") then
			local name = jointName(descendant.Name)
			if not joints[name] then joints[name] = {motor = descendant, rest = descendant.C0} end
		end
	end
	return setmetatable({rig = rig, joints = joints}, Live)
end

function Live:Apply(pose, weight)
	if weight ~= nil and weight < 1 then pose = Poses.Blend(pose, weight) end
	for name, joint in pairs(self.joints) do
		if joint.motor.Parent then
			local delta = pose[name]
			joint.motor.C0 = delta and aboutPivot(joint.rest.Position, delta) * joint.rest or joint.rest
		end
	end
end

function Live:Restore()
	for _, joint in pairs(self.joints) do
		if joint.motor.Parent then joint.motor.C0 = joint.rest end
	end
end

-- ---------------------------------------------------------------------------------------
-- Anchored showroom models
-- ---------------------------------------------------------------------------------------
local Preview = {}
Preview.__index = Preview

local function carrierOf(part, links, root)
	for _, child in ipairs(part:GetChildren()) do
		if child:IsA("WeldConstraint") or child:IsA("Weld") or child:IsA("ManualWeld") then
			local other = child.Part0 == part and child.Part1 or child.Part0
			if other and other ~= part and other:IsA("BasePart") then return other end
		end
	end
	return nil
end

function Poses.Preview(rig)
	local root = rig:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then return nil end
	local links = {}
	for _, descendant in ipairs(rig:GetDescendants()) do
		if descendant:IsA("Motor6D") and descendant.Part0 and descendant.Part1 and descendant.Part0:IsA("BasePart") and descendant.Part1:IsA("BasePart") then
			links[descendant.Part1] = {
				parent = descendant.Part0, name = jointName(descendant.Name), pivot = descendant.C0.Position,
				rel = descendant.Part0.CFrame:ToObjectSpace(descendant.Part1.CFrame),
			}
		end
	end
	-- Topological order from the root so a parent always moves before its children.
	local order, placed = {}, {[root] = true}
	local pending = {}
	for part in pairs(links) do table.insert(pending, part) end
	table.sort(pending, function(a, b) return a.Name < b.Name end)
	local progress = true
	while #pending > 0 and progress do
		progress = false
		for index = #pending, 1, -1 do
			local part = pending[index]
			if placed[links[part].parent] then
				table.insert(order, part)
				placed[part] = true
				table.remove(pending, index)
				progress = true
			end
		end
	end
	-- Everything else (accessory handles, welded cosmetic overlays) rides on the part it is welded to.
	local followers = {}
	for _, descendant in ipairs(rig:GetDescendants()) do
		if descendant:IsA("BasePart") and descendant ~= root and not links[descendant] then
			local carrier = carrierOf(descendant, links, root)
			local depth = 0
			while carrier and not placed[carrier] and depth < 4 do
				carrier = carrierOf(carrier, links, root)
				depth += 1
			end
			if not carrier or not placed[carrier] then
				-- No weld to follow: ride the closest body part.
				local best, distance = root, math.huge
				for part in pairs(placed) do
					local gap = (part.CFrame.Position - descendant.CFrame.Position).Magnitude
					if gap < distance then best, distance = part, gap end
				end
				carrier = best
			end
			table.insert(followers, {part = descendant, carrier = carrier, rel = carrier.CFrame:ToObjectSpace(descendant.CFrame)})
		end
	end
	-- Followers of followers (a weld to another overlay) resolve through the carrier chain above, so the
	-- final carrier is always a joint-driven body part.
	return setmetatable({rig = rig, root = root, links = links, order = order, followers = followers, restRoot = root.CFrame}, Preview)
end

-- Place the whole model with its root at `rootCFrame` wearing `pose`. Returns the world CFrame of each body part.
function Preview:Set(pose, rootCFrame)
	pose = pose or {}
	rootCFrame = rootCFrame or self.restRoot
	local world = {[self.root] = rootCFrame}
	self.root.CFrame = rootCFrame
	for _, part in ipairs(self.order) do
		local link = self.links[part]
		local delta = pose[link.name]
		local moved = delta and aboutPivot(link.pivot, delta) or CFrame.new()
		local cframe = world[link.parent] * moved * link.rel
		world[part] = cframe
		part.CFrame = cframe
	end
	for _, follower in ipairs(self.followers) do
		follower.part.CFrame = world[follower.carrier] * follower.rel
	end
	return world
end

function Preview:Reset() return self:Set({}, self.restRoot) end

-- ---------------------------------------------------------------------------------------
-- Shared pose pieces
-- ---------------------------------------------------------------------------------------
local function A(x, y, z) return CFrame.Angles(math.rad(x or 0), math.rad(y or 0), math.rad(z or 0)) end
Poses.Angles = A

-- A simple run cycle for previews (cycle length 0.62 s). `lean` tilts the torso into the run.
function Poses.Run(t)
	local s = math.sin(t * math.pi * 2 / 0.62)
	local c = math.cos(t * math.pi * 2 / 0.62)
	local lift = math.abs(s)
	return {
		Root = CFrame.new(0, lift * 0.22 - 0.05, 0) * A(-8, 0, 0),
		Waist = A(-6, -s * 7, 0),
		Neck = A(6, s * 4, 0),
		LeftHip = A(s * 55, 0, -3), RightHip = A(-s * 55, 0, 3),
		LeftKnee = A(-math.max(0, -s) * 70 - 8, 0, 0), RightKnee = A(-math.max(0, s) * 70 - 8, 0, 0),
		LeftShoulder = A(-s * 50, 0, -6), RightShoulder = A(s * 50, 0, 6),
		LeftElbow = A(55 + c * 12, 0, 0), RightElbow = A(55 - c * 12, 0, 0),
	}
end

return Poses
