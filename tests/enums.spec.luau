-- Run: .tooling/bin/lune run tests/enums.spec.luau
-- Roblox throws at runtime on an unknown Enum member, but Lune returns nil silently.
-- Every Enum.Type.Member literal in src/ and tools/ must exist in the engine's Enum database.
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local checks, failures, seen = 0, {}, {}

local function walk(dir)
	for _, name in ipairs(fs.readDir(dir)) do
		local path = dir .. "/" .. name
		if fs.isDir(path) then
			walk(path)
		elseif name:match("%.lua$") or name:match("%.luau$") then
			local source = fs.readFile(path)
			local lineNumber = 0
			for line in (source .. "\n"):gmatch("([^\n]*)\n") do
				lineNumber += 1
				local code = line:gsub("%-%-.*$", "")
				for enumName, member in code:gmatch("Enum%.(%w+)%.(%w+)") do
					checks += 1
					local key = enumName .. "." .. member
					if seen[key] == nil then
						local okType, enumType = pcall(function() return roblox.Enum[enumName] end)
						local ok = false
						if okType and enumType ~= nil then
							local okMember, value = pcall(function() return enumType[member] end)
							ok = okMember and value ~= nil
						end
						seen[key] = ok
					end
					if not seen[key] then
						table.insert(failures, path .. ":" .. lineNumber .. " Enum." .. key)
					end
				end
			end
		end
	end
end

walk("src")
walk("tools")
for _, failure in ipairs(failures) do print("Unknown enum: " .. failure) end
assert(#failures == 0, #failures .. " unknown Enum member(s)")
assert(checks > 200, "Enum scan must actually find the production enum usage")
print("Enum validity: " .. checks .. " references checked (" .. #failures .. " unknown)")
