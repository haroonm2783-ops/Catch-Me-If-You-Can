-- Optional geometry export of a map builder for the software renderer (tools/render-map.py).
-- Usage: .tooling/bin/lune run tools/export-map.luau [Mall|NeonHeights] [output.json]
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local process = require("@lune/process")
local serde = require("@lune/serde")
local Loader = require("./lib/loader")
local which = process.args[1] or "Mall"
local output = process.args[2] or ".tooling/map-geometry.json"
local place = roblox.deserializePlace(fs.readFile("dist/CatchMeIfYouCan.rbxl"))
local world = place:GetService("Workspace")
for _, child in ipairs(world:GetChildren()) do
	if child.Name == "NeonHeights" or child.Name == "CatchMall" then child:Destroy() end
end
local env = Loader.environment({game = place, workspace = world})
local builder = Loader.load(which == "Mall" and "src/server/World/MallBuilder.lua" or "src/server/World/MapBuilder.lua", env)
local map = builder.Build({Static = true})
local parts = {}
for _, instance in ipairs(map.Model:GetDescendants()) do
	if instance:IsA("BasePart") and instance.Transparency < 0.99 then
		table.insert(parts, {
			name = instance.Name, cf = {instance.CFrame:GetComponents()},
			size = {instance.Size.X, instance.Size.Y, instance.Size.Z},
			color = {instance.Color.R, instance.Color.G, instance.Color.B}, alpha = instance.Transparency,
			shape = instance:IsA("WedgePart") and "Wedge" or (instance:IsA("Part") and instance.Shape.Name or "Block"),
			neon = instance.Material == roblox.Enum.Material.Neon, collide = instance.CanCollide,
			parent = instance.Parent and instance.Parent.Name or "",
		})
	end
end
fs.writeFile(output, serde.encode("json", {parts = parts, partCount = map.Model:GetAttribute("StaticPartCount")}, false))
print("Exported " .. #parts .. " visible parts to " .. output)
