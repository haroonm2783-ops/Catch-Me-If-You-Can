-- Optional geometry inspection, not a Roblox renderer or a gameplay asset.
-- Run from the repository root: .tooling/bin/lune run tools/export-characters.luau
-- Then: python3 tools/render-characters.py (requires Pillow and NumPy).
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")
local process = require("@lune/process")
local environment = {}
for key, value in pairs(roblox) do environment[key] = value end
local Appearance = luau.load(fs.readFile("src/shared/Appearance.lua"), {
	environment=environment, debugName="Appearance",
})()

local specimens = {
	{title="DEFAULT RUNNER", subtitle="Courier / Runner identity", skin="skin_courier", mask="", role="Runner"},
	{title="DEFAULT HUNTER", subtitle="Courier / Hunter identity", skin="skin_courier", mask="", role="Hunter"},
	{title="ROOFTOP ACE", subtitle="Climber scarf / raised goggles", skin="skin_rooftop", mask=""},
	{title="SKYGARDEN KEEPER", subtitle="Canvas apron + Street Signal mask", skin="skin_gardener", mask="mask_street"},
	{title="SHADOW RUNNER", subtitle="Shadow skin + Phantom mask", skin="skin_shadow", mask="mask_phantom"},
	{title="GOLDEN PHANTOM", subtitle="Golden skin + Gold Skull mask", skin="skin_golden", mask="mask_skull"},
	{title="NEON OUTLAW", subtitle="Neon skin + Prism Visor mask", skin="skin_neon", mask="mask_visor"},
	{title="CRIMSON HUNTER", subtitle="Crimson skin + Kitsune mask", skin="skin_crimson", mask="mask_kitsune"},
}

for _, specimen in ipairs(specimens) do
	local rig = Appearance.BuildPreview(specimen.skin,specimen.mask,{})
	if specimen.role then
		assert(type(Appearance.ApplyRole)=="function", "Role appearance is required for the default Runner / Hunter comparison")
		Appearance.ApplyRole(rig,specimen.role)
	end
	local parts = {}
	for _, part in ipairs(rig:GetDescendants()) do
		if part:IsA("BasePart") and part.Transparency<0.99 then
			local shape = part:IsA("WedgePart") and "Wedge" or part:IsA("Part") and part.Shape.Name or "Block"
			local size = {part.Size.X,part.Size.Y,part.Size.Z}
			local specialMesh = part:FindFirstChildOfClass("SpecialMesh")
			if specialMesh and specialMesh.MeshType==roblox.Enum.MeshType.Head then
				shape = "HeadApproximation"
				size = {size[1]*specialMesh.Scale.X,size[2]*specialMesh.Scale.Y,size[3]*specialMesh.Scale.Z}
			end
			table.insert(parts,{
				name=part.Name,cf={part.CFrame:GetComponents()},size=size,
				color={part.Color.R,part.Color.G,part.Color.B},alpha=part.Transparency,
				shape=shape,neon=part.Material==roblox.Enum.Material.Neon,
			})
		end
	end
	assert(#parts>20,"A specimen must contain actual outfit geometry")
	-- Traversal order can vary across runtimes; names and positions make the export reproducible.
	table.sort(parts,function(a,b)
		if a.name~=b.name then return a.name<b.name end
		for i=1,12 do if a.cf[i]~=b.cf[i] then return a.cf[i]<b.cf[i] end end
		return false
	end)
	specimen.parts = parts
	rig:Destroy()
end
local output = process.args[1] or ".tooling/character-geometry.json"
fs.writeFile(output,serde.encode("json",{
	notice="Geometry preview—not Roblox Studio rendering. Head mesh approximated; no materials, highlights, particles, trails, or engine lighting.",
	source="src/shared/Appearance.lua",specimens=specimens,
},true))
print("Exported "..tostring(#specimens).." actual Appearance.BuildPreview specimens to "..output)
