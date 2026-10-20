-- Bake the authored map using actual Roblox instance serialization, not a mock XML writer.
-- Lune models data, not Roblox physics/rendering; runtime validation still needs Studio.
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local luau = require("@lune/luau")
local process = require("@lune/process")
local serde = require("@lune/serde")
local input = process.args[1] or "dist/CatchMeIfYouCan.sources.rbxlx"
local place = roblox.deserializePlace(fs.readFile(input))
local world = place:GetService("Workspace")
local env = {game=place,workspace=world}
for key, value in pairs(roblox) do env[key]=value end
-- Check exact embedded script contents, including every module behind bootstraps.
local function verifySources(folder, directory)
	for _, child in ipairs(folder:GetChildren()) do
		if child:IsA("LuaSourceContainer") then
			local suffix = child:IsA("LocalScript") and ".client.lua" or child:IsA("Script") and ".server.lua" or ".lua"
			local path = directory.."/"..child.Name..suffix
			assert(child.Source == fs.readFile(path), "Embedded source differs from "..path)
		elseif child:IsA("Folder") then verifySources(child,directory.."/"..child.Name) end
	end
end
verifySources(place:GetService("ReplicatedStorage").CatchShared,"src/shared")
verifySources(place:GetService("ServerScriptService").CatchServer,"src/server")
verifySources(place:GetService("StarterPlayer").StarterPlayerScripts.CatchClient,"src/client")
local builder=luau.load(fs.readFile("src/server/World/MapBuilder.lua"),{environment=env,debugName="MapBuilder"})()
local config=luau.load(fs.readFile("src/shared/Config.lua"),{environment=env,debugName="Config"})()
-- DataModel attributes are not retained by place serialization; Workspace is.
world:SetAttribute("CatchGameVersion",config.Version)
local Appearance=luau.load(fs.readFile("src/shared/Appearance.lua"),{environment=env,debugName="Appearance"})()
local map=builder.Build({Static=true,Appearance=Appearance})
assert(map.Model.Parent==world,"Map must be in Workspace")
local count, lights, neon, signs, routes = 0,0,0,0,0
local parts={}
for _, instance in ipairs(map.Model:GetDescendants()) do
	if instance:IsA("BasePart") then
		count+=1
		assert(instance.Anchored,"Every map part is anchored: "..instance.Name)
		assert(instance.Size.X>0 and instance.Size.Y>0 and instance.Size.Z>0,"Positive geometry")
		for _, value in ipairs({instance.CFrame:GetComponents()}) do
			assert(value==value and math.abs(value)<math.huge,"Finite geometry transform: "..instance.Name)
		end
		if instance.Material==roblox.Enum.Material.Neon then neon+=1 end
		if instance:GetAttribute("TraversalRoute") then routes+=1 end
		if instance.Transparency<0.99 then
			table.insert(parts,{name=instance.Name,cf={instance.CFrame:GetComponents()},size={instance.Size.X,instance.Size.Y,instance.Size.Z},
				color={instance.Color.R,instance.Color.G,instance.Color.B},alpha=instance.Transparency,
				shape=instance:IsA("WedgePart") and "Wedge" or (instance:IsA("Part") and instance.Shape.Name or "Block"),neon=instance.Material==roblox.Enum.Material.Neon})
		end
	elseif instance:IsA("PointLight") then lights+=1
	elseif instance:IsA("SurfaceGui") then signs+=1 end
end
assert(count==map.Model:GetAttribute("StaticPartCount"),"Part budget metadata matches geometry")
assert(count<6500,"Mobile map budget")
assert(#map.RunnerSpawns>=10 and #map.HunterSpawns==2 and #map.Podiums==3,"Complete spawn roster")
assert(routes>=2 and neon>=300 and signs>=40,"Map landmarks and connected routes present")
assert(world:FindFirstChild("CatchMall")~=nil,"Baked map is attached")
-- Starting viewport: direct Studio open shows the city instead of an empty baseplate.
local camera=world:FindFirstChildOfClass("Camera") or roblox.Instance.new("Camera")
camera.Name="Camera"
camera.CFrame=roblox.CFrame.lookAt(roblox.Vector3.new(230,150,230),roblox.Vector3.new(0,10,0))
camera.Focus=roblox.CFrame.new(0,10,0)
camera.CameraType=roblox.Enum.CameraType.Custom
camera.Parent=world
world.CurrentCamera=camera
-- The Roblox player camera controller takes over in Play mode.
place:GetService("StarterPlayer").GameSettingsAvatar=roblox.Enum.GameAvatarType.R15
local xml, binary = roblox.serializePlace(place,true), roblox.serializePlace(place,false)
-- Generate the requested delivery names from this build, retaining the existing
-- canonical paths for current Rojo workflows and links. They are byte-identical.
local deliverables = {
	["dist/Catch-Me-If-You-Can-Final.rbxlx"] = xml,
	["dist/Catch-Me-If-You-Can-Final.rbxl"] = binary,
	["dist/CatchMeIfYouCan.rbxlx"] = xml,
	["dist/CatchMeIfYouCan.rbxl"] = binary,
}
for path, contents in pairs(deliverables) do fs.writeFile(path,contents) end
fs.writeFile("dist/map-geometry.json",serde.encode("json",{parts=parts,partCount=count,routes=routes,version=config.Version},true))
local scripts=0
for _, object in ipairs(place:GetDescendants()) do if object:IsA("LuaSourceContainer") then scripts+=1; assert(#object.Source>0,"No empty script") end end
print(string.format("Baked Neon Mall: %d parts, %d neon accents, %d signs, %d lights, %d traversal routes, %d scripts.",count,neon,signs,lights,routes,scripts))
-- Deserialize both formats under both filenames; assert content, not extension.
for path in pairs(deliverables) do
	local reopened=roblox.deserializePlace(fs.readFile(path))
	assert(reopened:GetService("Workspace"):GetAttribute("CatchGameVersion")==config.Version,"Game version identifies the updated artifact")
	assert(reopened:GetService("Workspace"):FindFirstChild("CatchMall"),"Missing baked mall")
	assert(reopened:GetService("Workspace").StreamingEnabled == false,"Whole arena remains available to spectators")
	verifySources(reopened:GetService("ServerScriptService").CatchServer,"src/server")
	verifySources(reopened:GetService("ReplicatedStorage").CatchShared,"src/shared")
	verifySources(reopened:GetService("StarterPlayer").StarterPlayerScripts.CatchClient,"src/client")
	assert(reopened:GetService("ReplicatedStorage"):FindFirstChild("CatchShared"):FindFirstChild("Appearance"),"Missing cosmetics")
	assert(reopened:GetService("ServerScriptService"):FindFirstChild("CatchServer"):FindFirstChild("Main"),"Missing server bootstrap")
	assert(reopened:GetService("StarterPlayer").GameSettingsAvatar==roblox.Enum.GameAvatarType.R15,"R15 avatar setting")
	print("Verified serialized place: "..path)
end
