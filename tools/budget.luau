-- Part/light/shadow budget of the baked map, by folder. Run: lune run tools/budget.luau
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local place = roblox.deserializePlace(fs.readFile("dist/CatchMeIfYouCan.rbxl"))
local map = place:GetService("Workspace").CatchMall
local rows, total = {}, {parts = 0, collide = 0, shadow = 0, transparent = 0, neon = 0, lights = 0, guis = 0}
for _, folder in ipairs(map:GetChildren()) do
	local row = {name = folder.Name, parts = 0, collide = 0, shadow = 0, transparent = 0, neon = 0, lights = 0}
	for _, d in ipairs(folder:GetDescendants()) do
		if d:IsA("BasePart") then
			row.parts += 1
			if d.CanCollide then row.collide += 1 end
			if d.CastShadow then row.shadow += 1 end
			if d.Transparency > 0.05 then row.transparent += 1 end
			if d.Material == roblox.Enum.Material.Neon then row.neon += 1 end
		elseif d:IsA("PointLight") then row.lights += 1
		elseif d:IsA("SurfaceGui") then total.guis += 1 end
	end
	table.insert(rows, row)
	for k in pairs(row) do if type(row[k]) == "number" then total[k] += row[k] end end
end
print(string.format("%-14s %6s %8s %7s %12s %5s %6s", "folder", "parts", "collide", "shadow", "transparent", "neon", "lights"))
for _, r in ipairs(rows) do print(string.format("%-14s %6d %8d %7d %12d %5d %6d", r.name, r.parts, r.collide, r.shadow, r.transparent, r.neon, r.lights)) end
print(string.format("%-14s %6d %8d %7d %12d %5d %6d   (+%d SurfaceGuis)", "TOTAL", total.parts, total.collide, total.shadow, total.transparent, total.neon, total.lights, total.guis))
