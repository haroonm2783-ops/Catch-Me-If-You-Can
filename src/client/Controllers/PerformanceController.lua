-- Client-side performance tiers. The whole mall replicates (it is only 324 x 304 studs, so streaming would not
-- unload meaningful geometry and would break spectating), so weaker devices save work here instead:
--   tier 1 HIGH   everything on (default on PC)
--   tier 2 MEDIUM small decoration and point lights are hidden beyond a radius, sun rays off (default on phones)
--   tier 3 LOW    smaller radius, post effects and global shadows off, no avatar thumbnails
-- The tier only ever steps DOWN automatically, after sustained low frame rates. It never changes gameplay,
-- collision or what the server sees; every effect is local and cosmetic.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")

local PerformanceController = {}
PerformanceController.__index = PerformanceController

local MAP_NAME = "CatchMall"
local DETAIL_RADIUS = {math.huge, 110, 70}
local LIGHT_RADIUS = {math.huge, 95, 60}
local TIER_NAMES = {"HIGH", "MEDIUM", "LOW"}
local WINDOW = 6          -- seconds per frame-rate sample window
local WARMUP = 20         -- seconds of loading hitches to ignore after start
local LOW_FPS = 38        -- below this for two windows in a row steps the tier down
local SPIKE = 0.25        -- frames longer than this (tab-out, hitch) are excluded from the average

function PerformanceController.new(ctx)
	ctx.Perf = ctx.Perf or {tier = 1, name = "HIGH", auto = true}
	return setmetatable({
		ctx = ctx, player = Players.LocalPlayer, connections = {}, details = {}, lights = {}, effects = {},
		emitters = {}, clock = 0, lodClock = 0, windowTime = 0, windowFrames = 0, slowWindows = 0, started = false,
	}, PerformanceController)
end

function PerformanceController:_deviceTier()
	local touch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	local tier = touch and 2 or 1
	local ok, level = pcall(function() return settings().Rendering.QualityLevel.Value end)
	if ok and type(level) == "number" then
		-- Quality level 0 is Automatic; 1-21 are manual levels.
		if level > 0 and level <= 3 then tier = 3 elseif level > 0 and level <= 5 then tier = math.max(tier, 2) end
	end
	return tier
end

function PerformanceController:_collect(model)
	if self.model == model then return end
	self.model = model
	table.clear(self.details)
	table.clear(self.lights)
	table.clear(self.emitters)
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			if descendant:GetAttribute("CatchDetail") then
				table.insert(self.details, {part = descendant, hidden = false})
			end
		elseif descendant:IsA("ParticleEmitter") then
			table.insert(self.emitters, {emitter = descendant, rate = descendant.Rate, enabled = descendant.Enabled})
		elseif descendant:IsA("PointLight") or descendant:IsA("SpotLight") then
			table.insert(self.lights, {light = descendant, enabled = descendant.Enabled, off = false})
		end
	end
	self:_applyEmitters()
	self:_lod(true)
end

-- Ambient particles: full rate on HIGH, half on MEDIUM, off on LOW.
function PerformanceController:_applyEmitters()
	local tier = self.ctx.Perf.tier
	for _, record in ipairs(self.emitters) do
		local emitter = record.emitter
		if emitter.Parent then
			emitter.Rate = tier == 2 and math.max(1, math.floor(record.rate * 0.5)) or record.rate
			emitter.Enabled = record.enabled and tier < 3
		end
	end
end

-- Post effects are remembered so a manual tier change can restore them.
function PerformanceController:_collectEffects()
	for _, child in ipairs(Lighting:GetChildren()) do
		if child:IsA("SunRaysEffect") or child:IsA("BloomEffect") or child:IsA("ColorCorrectionEffect") or child:IsA("DepthOfFieldEffect") then
			if not self.effects[child] then self.effects[child] = {enabled = child.Enabled} end
		end
	end
end

function PerformanceController:_applyEffects()
	self:_collectEffects()
	local tier = self.ctx.Perf.tier
	for effect, saved in pairs(self.effects) do
		if effect.Parent then
			local on = saved.enabled
			if tier >= 2 and effect:IsA("SunRaysEffect") then on = false end
			if tier >= 3 and (effect:IsA("BloomEffect") or effect:IsA("ColorCorrectionEffect") or effect:IsA("DepthOfFieldEffect")) then on = false end
			effect.Enabled = on
		end
	end
	if self.shadowsDefault == nil then self.shadowsDefault = Lighting.GlobalShadows end
	Lighting.GlobalShadows = tier < 3 and self.shadowsDefault or false
end

-- Distance LOD for decoration and lights, with hysteresis so nothing flickers at the boundary.
function PerformanceController:_lod(force)
	local tier = self.ctx.Perf.tier
	local camera = workspace.CurrentCamera
	if not camera then return end
	local origin = camera.CFrame.Position
	local detailRadius, lightRadius = DETAIL_RADIUS[tier], LIGHT_RADIUS[tier]
	for _, record in ipairs(self.details) do
		local part = record.part
		if part.Parent then
			local distance = (part.Position - origin).Magnitude
			local hide = if record.hidden then distance > detailRadius * 0.9 else distance > detailRadius
			if hide ~= record.hidden or force then
				record.hidden = hide
				part.LocalTransparencyModifier = hide and 1 or 0
			end
		end
	end
	for _, record in ipairs(self.lights) do
		local light = record.light
		local parent = light.Parent
		if parent then
			local distance = (parent.Position - origin).Magnitude
			local off = if record.off then distance > lightRadius * 0.9 else distance > lightRadius
			if off ~= record.off or force then
				record.off = off
				light.Enabled = record.enabled and not off
			end
		end
	end
end

function PerformanceController:SetTier(tier, manual)
	tier = math.clamp(math.floor(tonumber(tier) or 1), 1, 3)
	local perf = self.ctx.Perf
	if manual then perf.auto = false end
	perf.tier, perf.name = tier, TIER_NAMES[tier]
	self.player:SetAttribute("CatchGraphicsTier", tier)
	self:_applyEffects()
	self:_applyEmitters()
	self:_lod(true)
end

-- nil restores automatic selection (device default, then adaptive step-downs).
function PerformanceController:SetPreference(tier)
	if tier == nil then
		self.ctx.Perf.auto = true
		self.slowWindows = 0
		self:SetTier(self:_deviceTier(), false)
	else
		self:SetTier(tier, true)
	end
end

function PerformanceController:_sample(dt)
	self.clock += dt
	if self.clock < WARMUP or not self.ctx.Perf.auto or self.ctx.Perf.tier >= 3 then return end
	if dt > SPIKE then return end
	self.windowTime += dt
	self.windowFrames += 1
	if self.windowTime < WINDOW then return end
	local fps = self.windowFrames / self.windowTime
	self.windowTime, self.windowFrames = 0, 0
	self.lastFps = fps
	if fps < LOW_FPS then
		self.slowWindows += 1
		if self.slowWindows >= 2 then
			self.slowWindows = 0
			self:SetTier(self.ctx.Perf.tier + 1, false)
		end
	else
		self.slowWindows = 0
	end
end

function PerformanceController:Start()
	if self.started then return end
	self.started = true
	self:SetTier(self:_deviceTier(), false)
	local model = workspace:FindFirstChild(MAP_NAME)
	if model then self:_collect(model) end
	if workspace.ChildAdded then
		table.insert(self.connections, workspace.ChildAdded:Connect(function(child)
			if child.Name == MAP_NAME then
				task.delay(1, function() if child.Parent then self:_collect(child) end end)
			end
		end))
	end
	table.insert(self.connections, RunService.Heartbeat:Connect(function(dt)
		self:_sample(dt)
		self.lodClock += dt
		if self.lodClock >= 0.5 then
			self.lodClock = 0
			if self.ctx.Perf.tier > 1 then self:_lod(false) end
		end
	end))
end

function PerformanceController:Destroy()
	for _, connection in ipairs(self.connections) do connection:Disconnect() end
	table.clear(self.connections)
	-- Leave the world exactly as the server built it.
	for _, record in ipairs(self.details) do if record.part.Parent then record.part.LocalTransparencyModifier = 0 end end
	for _, record in ipairs(self.lights) do if record.light.Parent then record.light.Enabled = record.enabled end end
	for effect, saved in pairs(self.effects) do if effect.Parent then effect.Enabled = saved.enabled end end
	for _, record in ipairs(self.emitters) do
		if record.emitter.Parent then record.emitter.Rate, record.emitter.Enabled = record.rate, record.enabled end
	end
	if self.shadowsDefault ~= nil then Lighting.GlobalShadows = self.shadowsDefault end
end

return PerformanceController
