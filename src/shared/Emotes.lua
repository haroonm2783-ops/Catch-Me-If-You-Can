-- Emote and victory definitions. Every one is a procedural pose (see Poses.lua), so playing an emote needs no
-- uploaded animation and no asset permissions, and the Shop preview, the live character and the winners' podium
-- all run the SAME function. Cosmetic only: emotes never change speed, hitboxes, tagging or hiding.
local Emotes = {}

local A = function(x, y, z) return CFrame.Angles(math.rad(x or 0), math.rad(y or 0), math.rad(z or 0)) end
local function T(x, y, z, rx, ry, rz) return CFrame.new(x, y, z) * A(rx, ry, rz) end
local function clamp01(x) return math.clamp(x, 0, 1) end
local function smooth(x) x = clamp01(x) return x * x * (3 - 2 * x) end
-- 0 before a, 1 after b, eased in between.
local function seg(t, a, b) return smooth((t - a) / (b - a)) end
local TAU = math.pi * 2

Emotes.Gap = 0.6 -- pause between looping replays of a one-shot emote in previews

local defs = {}

-- Short one-shot burst when the emote lands its big moment. Colors are plain RGB triples.
-- fx = {at = seconds into the emote, count = particles, a = color, b = color}

defs.emote_wave = {
	name = "Hey, Shopper", duration = 3.2, loop = false, icon = "👋",
	pose = function(t)
		local w = math.sin(t * 9)
		return {
			RightShoulder = A(-8, 0, 148), RightElbow = A(0, 0, w * 30),
			LeftShoulder = A(0, 0, -7), Waist = A(0, 0, w * 1.5), Neck = A(0, 10, 5 + w * 2),
		}
	end,
}

defs.emote_dance = {
	name = "Food Court Shuffle", duration = 1.6, loop = true, icon = "💃",
	pose = function(t)
		local b = t * TAU / 0.8
		local s, c = math.sin(b), math.cos(b)
		return {
			Root = T(0, math.abs(s) * 0.3, 0, 0, s * 12, 0),
			Waist = A(0, -s * 14, c * 3), Neck = A(0, s * 10, -c * 4),
			LeftHip = A(math.max(0, s) * 38, 0, -4), RightHip = A(math.max(0, -s) * 38, 0, 4),
			LeftKnee = A(-math.max(0, s) * 58, 0, 0), RightKnee = A(-math.max(0, -s) * 58, 0, 0),
			RightShoulder = A(58 + c * 26, 0, 16), RightElbow = A(100, 0, 0),
			LeftShoulder = A(58 - c * 26, 0, -16), LeftElbow = A(100, 0, 0),
		}
	end,
	fx = {at = 0.1, count = 10, a = {255, 170, 255}, b = {255, 235, 120}},
}

defs.emote_tiptoe = {
	name = "Sneaky Tiptoe", duration = 2.4, loop = true, icon = "🤫",
	pose = function(t)
		local s = math.sin(t * TAU / 1.2)
		local right, left = math.max(0, s), math.max(0, -s)
		return {
			Root = T(0, -0.8 + (right + left) * 0.05, 0.1),
			Waist = A(-18, math.sin(t * TAU / 2.4) * 8, 0),
			Neck = A(10, math.sin(t * TAU / 2.4 + 1) * 38, 0),
			LeftHip = A(55 + left * 22, 0, -2), RightHip = A(55 + right * 22, 0, 2),
			LeftKnee = A(-100 - left * 26, 0, 0), RightKnee = A(-100 - right * 26, 0, 0),
			-- A finger to the lips: "shhh".
			RightShoulder = A(105, 0, -42), RightElbow = A(60, 0, 0),
			LeftShoulder = A(-22, 0, -12), LeftElbow = A(20, 0, 0),
		}
	end,
}

defs.emote_chicken = {
	name = "Mall Chicken", duration = 1.0, loop = true, icon = "🐔",
	pose = function(t)
		local f = math.sin(t * TAU / 0.5)
		local s = math.sin(t * TAU / 1.0)
		local peck = math.max(0, math.sin(t * TAU / 0.5 + 1.2))
		return {
			Root = T(0, -0.35 + math.abs(f) * 0.16, 0),
			Waist = A(-12, 0, s * 4), Neck = A(-peck * 30, s * 10, 0),
			LeftHip = A(46 + math.max(0, s) * 24, 0, -2), RightHip = A(46 + math.max(0, -s) * 24, 0, 2),
			LeftKnee = A(-78 - math.max(0, s) * 20, 0, 0), RightKnee = A(-78 - math.max(0, -s) * 20, 0, 0),
			-- Wings: upper arms out, forearms folded down, flapping.
			RightShoulder = A(0, 0, 66 + f * 30), RightElbow = A(0, 0, -58 - f * 18),
			LeftShoulder = A(0, 0, -(66 + f * 30)), LeftElbow = A(0, 0, 58 + f * 18),
		}
	end,
}

defs.emote_drama = {
	name = "Dramatic Faint", duration = 4.8, loop = false, icon = "🎭",
	pose = function(t)
		local look = seg(t, 0, 0.6) * (1 - seg(t, 1.2, 1.5))   -- back of the hand to the forehead
		local fall = seg(t, 1.2, 2.1) * (1 - seg(t, 3.5, 4.5)) -- swoon onto the floor, then recover
		local flop = math.sin(t * 5) * 6 * fall
		return {
			Root = T(0, -1.7 * fall, 0.35 * fall, 78 * fall, 0, 0),
			Waist = A(14 * look - 6 * fall, math.sin(t * 2.2) * 6 * look, 0),
			Neck = A(18 * look, 0, 12 * look),
			RightShoulder = A(150 * look + 10 * fall, 0, -40 * look + 70 * fall),
			RightElbow = A(15 * look, 0, -24 * fall + flop),
			LeftShoulder = A(-8 * look, 0, -(8 * look + 78 * fall)),
			LeftElbow = A(0, 0, flop),
			LeftHip = A(-6 * fall, 0, -2), RightHip = A(10 * fall, 0, 2),
			LeftKnee = A(-14 * fall, 0, 0), RightKnee = A(-8 * fall, 0, 0),
		}
	end,
}

defs.emote_flip = {
	name = "Showoff Flip", duration = 2.1, loop = false, icon = "🤸",
	pose = function(t)
		local air = math.sin(math.pi * clamp01((t - 0.12) / 1.1))             -- jump arc 0.12 -> 1.22
		local spin = seg(t, 0.14, 1.18) * 360
		local tuck = math.sin(math.pi * clamp01((t - 0.18) / 0.95))
		local crouch = math.sin(math.pi * clamp01(t / 0.16)) * 0.6 + math.sin(math.pi * clamp01((t - 1.2) / 0.2)) * 0.8
		local finish = seg(t, 1.26, 1.42)                                      -- arms up in a V and hold
		return {
			Root = T(0, air * 3.4 - crouch * 0.7, 0, spin, 0, 0),
			LeftHip = A(82 * tuck + 60 * crouch, 0, -4), RightHip = A(82 * tuck + 60 * crouch, 0, 4),
			LeftKnee = A(-125 * tuck - 100 * crouch, 0, 0), RightKnee = A(-125 * tuck - 100 * crouch, 0, 0),
			RightShoulder = A(70 * tuck * (1 - finish), 0, 10 * tuck + 158 * finish),
			LeftShoulder = A(70 * tuck * (1 - finish), 0, -(10 * tuck + 158 * finish)),
			RightElbow = A(50 * tuck, 0, 0), LeftElbow = A(50 * tuck, 0, 0),
			Waist = A(-18 * tuck, 0, 0),
		}
	end,
	fx = {at = 1.3, count = 18, a = {255, 215, 90}, b = {255, 255, 255}},
}

defs.emote_royal = {
	name = "Royal Twirl", duration = 4.2, loop = false, icon = "👑",
	pose = function(t)
		local spin = seg(t, 0.1, 1.7) * 360
		local arms = seg(t, 0, 0.35) * (1 - seg(t, 1.9, 2.3))
		local bow = seg(t, 2.1, 2.7) * (1 - seg(t, 3.2, 3.7))
		local flourish = seg(t, 3.4, 3.9) * (1 - seg(t, 3.95, 4.2))
		return {
			Root = T(0, math.sin(math.pi * clamp01((t - 0.1) / 1.6)) * 0.45 - 0.2 * bow, 0, 0, spin, 0),
			RightShoulder = A(24 * bow, 0, 88 * arms + 150 * flourish - 34 * bow),
			LeftShoulder = A(-30 * bow, 0, -(88 * arms + 14 * bow + 140 * flourish)),
			RightElbow = A(88 * bow, 0, 0), LeftElbow = A(30 * bow, 0, 0),
			Waist = A(-48 * bow, 0, 0), Neck = A(-14 * bow + 10 * flourish, 0, 0),
			LeftHip = A(-18 * bow, 0, -3 * bow), RightHip = A(26 * bow, 0, 3 * bow),
			RightKnee = A(-34 * bow, 0, 0),
		}
	end,
	fx = {at = 1.7, count = 22, a = {255, 210, 90}, b = {255, 160, 230}},
}

-- Podium poses used by the Victories category. They run on the winners' showroom models.
defs.victory_wave = {
	name = "Mall Salute", duration = 3.0, loop = true, victory = true, icon = "👋",
	pose = function(t)
		local w = math.sin(t * TAU / 0.75)
		return {
			RightShoulder = A(-6, 0, 150), RightElbow = A(0, 0, w * 30),
			LeftShoulder = A(0, 0, -8), Waist = A(0, 0, w * 1.5), Neck = A(0, 8, 4),
		}
	end,
}
defs.victory_spin = {
	name = "Victory Lap", duration = 3.0, loop = true, victory = true, icon = "🏆",
	pose = function(t)
		local turn = (t / 3.0) * 360
		return {
			Root = T(0, 0.05 + math.abs(math.sin(t * TAU / 1.0)) * 0.12, 0, 0, turn, 0),
			RightShoulder = A(0, 0, 150 + math.sin(t * TAU / 0.5) * 8), LeftShoulder = A(0, 0, -(150 + math.sin(t * TAU / 0.5 + 1) * 8)),
		}
	end,
}
defs.victory_flex = {
	name = "Champion Flex", duration = 2.4, loop = true, victory = true, icon = "💪",
	pose = function(t)
		local pump = math.sin(t * TAU / 1.2)
		return {
			Root = T(0, 0.06 + pump * 0.06, 0),
			RightShoulder = A(8, 0, 86), RightElbow = A(0, 0, 96 + pump * 6),
			LeftShoulder = A(8, 0, -86), LeftElbow = A(0, 0, -(96 + pump * 6)),
			Waist = A(-4, 0, 0), Neck = A(-6, 0, 0),
			LeftKnee = A(-6, 0, 0), RightKnee = A(-6, 0, 0),
		}
	end,
}

Emotes.Defs = defs
Emotes.Order = {"emote_wave", "emote_dance", "emote_tiptoe", "emote_chicken", "emote_drama", "emote_flip", "emote_royal"}
Emotes.VictoryOrder = {"victory_wave", "victory_spin", "victory_flex"}

function Emotes.Has(id) return defs[id] ~= nil end
function Emotes.Duration(id) return defs[id] and defs[id].duration or 0 end
function Emotes.IsLoop(id) return defs[id] ~= nil and defs[id].loop == true end

local function blend(pose, weight)
	if weight >= 0.999 then return pose end
	local result = {}
	for name, delta in pairs(pose) do result[name] = CFrame.new():Lerp(delta, math.max(0, weight)) end
	return result
end

-- Pose at `time` seconds after the emote started. Returns nil once a one-shot emote has finished.
-- `replay` = loop forever for previews (one-shots rest for Emotes.Gap between plays).
function Emotes.Sample(id, time, replay)
	local def = defs[id]
	if not def or type(time) ~= "number" or time ~= time or time < 0 then return nil end
	local t = time
	local fadeIn, fadeOut = 0.22, 0.28
	if def.loop then
		t = time % def.duration
		return blend(def.pose(t), math.min(1, time / fadeIn))
	end
	if replay then t = time % (def.duration + Emotes.Gap) end
	if t > def.duration then return replay and {} or nil end
	local weight = smooth(math.min(1, t / fadeIn, (def.duration - t) / fadeOut))
	return blend(def.pose(t), weight)
end

return Emotes
