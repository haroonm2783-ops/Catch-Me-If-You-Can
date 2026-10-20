-- Loads production Luau modules into the Lune environment. Production code calls
-- `require("./Name")` when `script` is nil (outside Roblox); this resolves those requests.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")

local Loader = {}

function Loader.environment(extra)
	local env = {}
	for _, name in ipairs({"Instance","Vector3","Vector2","Color3","CFrame","Enum","UDim2","UDim","BrickColor","NumberSequence","NumberSequenceKeypoint","ColorSequence","ColorSequenceKeypoint","NumberRange","Rect","Font","Random","TweenInfo"}) do
		env[name] = roblox[name]
	end
	for key, value in pairs(extra or {}) do env[key] = value end
	return env
end

-- `root` is the directory of the module being loaded; relative requires resolve from it.
function Loader.load(path, env, cache)
	cache = cache or {}
	if cache[path] then return cache[path] end
	local directory = path:match("^(.*)/[^/]+$") or "."
	local localEnv = {}
	for key, value in pairs(env) do localEnv[key] = value end
	localEnv.require = function(request)
		local target = directory .. "/" .. request:gsub("^%./", "") .. ".lua"
		return Loader.load(target, env, cache)
	end
	local chunk = luau.load(fs.readFile(path), {environment = localEnv, debugName = path})
	local module = chunk()
	cache[path] = module
	return module
end

return Loader
