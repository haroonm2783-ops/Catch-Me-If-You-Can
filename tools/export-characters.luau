-- Optional geometry inspection, not a Roblox renderer or a gameplay asset.
-- Run from the repository root: .tooling/bin/lune run tools/export-characters.luau
-- Then: python3 tools/render-characters.py (requires Pillow and NumPy).
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")
local process = require("@lune/process")
local Catalog = require("../src/shared/Catalog")
local environment = {}
for key, value in pairs(roblox) do environment[key] = value end
local Appearance = luau.load(fs.readFile("src/shared/Appearance.lua"), {
	environment=environment, debugName="Appearance",
})()

local function names(category)
	local result = {}
	for _, item in ipairs(Catalog.ForCategory(category)) do table.insert(result, item) end
	return result
end
local skinItems, maskItems = names("skins"), names("masks")
local sheets = {skins={}, masks={}}
-- Decals are not geometry, so the stock Roblox face is drawn as two eyes and a smile for the preview only.
local function faceParts(rig)
	local head = rig:FindFirstChild("Head")
	if not head then return {} end
	local list = {}
	local function dot(name, x, y, size, color)
		local cf = head.CFrame * roblox.CFrame.new(x, y, -0.64)
		table.insert(list, {name=name, cf={cf:GetComponents()}, size={size[1], size[2], 0.05}, color=color, alpha=0, shape="Block", neon=false})
	end
	dot("FaceEyeL", -0.26, 0.12, {0.14, 0.2}, {0.1, 0.1, 0.12})
	dot("FaceEyeR", 0.26, 0.12, {0.14, 0.2}, {0.1, 0.1, 0.12})
	dot("FaceSmile", 0, -0.22, {0.46, 0.07}, {0.1, 0.1, 0.12})
	return list
end
local function capture(sheet, title, subtitle, skin, mask, role, view, accent)
	local rig = Appearance.BuildPreview(skin, mask, {}, {userId=3})
	if role then Appearance.ApplyRole(rig, role) end
	local parts = {}
	for _, part in ipairs(rig:GetDescendants()) do
		if part:IsA("BasePart") and part.Transparency<0.99 then
			local shape = part:IsA("WedgePart") and "Wedge" or part:IsA("Part") and part.Shape.Name or "Block"
			local size = {part.Size.X,part.Size.Y,part.Size.Z}
			local specialMesh = part:FindFirstChildOfClass("SpecialMesh")
			if specialMesh and specialMesh.MeshType==roblox.Enum.MeshType.Head then
				shape = "HeadApproximation"
				size = {1.25,1.25,1.25}
			end
			table.insert(parts,{
				name=part.Name,cf={part.CFrame:GetComponents()},size=size,
				color={part.Color.R,part.Color.G,part.Color.B},alpha=part.Transparency,
				shape=shape,neon=part.Material==roblox.Enum.Material.Neon,
			})
		end
	end
	for _, extra in ipairs(faceParts(rig)) do table.insert(parts, extra) end
	table.sort(parts,function(a,b)
		if a.name~=b.name then return a.name<b.name end
		for i=1,12 do if a.cf[i]~=b.cf[i] then return a.cf[i]<b.cf[i] end end
		return false
	end)
	table.insert(sheets[sheet],{title=title,subtitle=subtitle,parts=parts,view=view,accent=accent,count=#parts})
	rig:Destroy()
end
for _, item in ipairs(skinItems) do
	capture("skins", string.upper(item.name), item.rarity .. " / " .. item.currency, item.id, "", nil, "full", item.accent)
end
capture("skins", "HUNTER ROLE", "Original You + hunter identity", "skin_courier", "", "Hunter", "full", {255,84,70})
for _, item in ipairs(maskItems) do
	capture("masks", string.upper(item.name), item.rarity .. " / " .. item.currency, "skin_courier", item.id, nil, "head", item.accent)
end
local output = process.args[1] or ".tooling/character-geometry.json"
fs.writeFile(output,serde.encode("json",{
	notice="Geometry preview, not Roblox Studio rendering. Players keep their own avatar; this mannequin stands in for it. No materials, particles, trails, auras or engine lighting.",
	source="src/shared/Appearance.lua",sheets=sheets,
},true))
print("Exported character sheets to "..output)
