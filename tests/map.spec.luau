local fs=require("@lune/fs")
local roblox=require("@lune/roblox")
local luau=require("@lune/luau")
local place=roblox.deserializePlace(fs.readFile("dist/CatchMeIfYouCan.rbxl"))
local world=place:GetService("Workspace")
local map=world:FindFirstChild("NeonHeights")
local checks=0
local function expect(value,message) checks+=1; assert(value,message) end
local env={game=place,workspace=world}
for _, k in ipairs({"Instance","CFrame","Vector3","Color3","UDim2","Enum","Font"}) do env[k]=roblox[k] end
local builder=luau.load(fs.readFile("src/server/World/MapBuilder.lua"),{environment=env})()
local result=builder.Build({Static=true})
expect(result.Model==map,"Baked map reused in place")
expect(builder.Build({Static=true})==result,"Repeat Build is idempotent")
local sameName=0
for _, child in ipairs(world:GetChildren()) do if child.Name=="NeonHeights" then sameName+=1 end end
expect(sameName==1,"No duplicate map")
local colliders={}
for _, part in ipairs(map:GetDescendants()) do if part:IsA("BasePart") and part.CanCollide then table.insert(colliders,part) end end
-- Analytic OBB ray intersections validate authored geometry; this is not a physics simulation.
local function rayBox(origin,direction,part)
	local o=part.CFrame:PointToObjectSpace(origin)
	local d=part.CFrame:VectorToObjectSpace(direction)
	local half=part.Size/2
	local near,far=0,math.huge
	for _,axis in ipairs({"X","Y","Z"}) do
		if math.abs(d[axis])<0.000001 then
			if math.abs(o[axis])>half[axis] then return nil end
		else
			local a,b=(-half[axis]-o[axis])/d[axis],(half[axis]-o[axis])/d[axis]
			near=math.max(near,math.min(a,b));far=math.min(far,math.max(a,b))
			if near>far then return nil end
		end
	end
	return near
end
local function checkSpawn(cf,label)
	local nearest=math.huge
	for _,part in ipairs(colliders) do
		local distance=rayBox(cf.Position,roblox.Vector3.new(0,-1,0),part)
		if distance then nearest=math.min(nearest,distance) end
	end
	expect(nearest>=2.8 and nearest<=4.5,label.." has floor at avatar foot height; distance="..nearest)
	for _,part in ipairs(colliders) do
		local point=part.CFrame:PointToObjectSpace(cf.Position)
		local h=part.Size/2
		-- Avatar torso clearance, including a one-stud horizontal radius.
		local inside=math.abs(point.X)<h.X+0.8 and math.abs(point.Z)<h.Z+0.8 and math.abs(point.Y)<h.Y+1.8
		expect(not inside,label.." overlaps "..part.Name)
	end
end
for i,cf in ipairs(result.RunnerSpawns) do checkSpawn(cf,"Runner "..i) end
for i,cf in ipairs(result.HunterSpawns) do checkSpawn(cf,"Hunter "..i) end
checkSpawn(result.LobbySpawn,"Lobby")
local routes, gates, trusses=0,0,0
for _,part in ipairs(map:GetDescendants()) do
	if part:IsA("BasePart") and part:GetAttribute("TraversalRoute") then
		routes+=1
		local slope=math.deg(math.asin(math.abs(part.CFrame.LookVector.Y)))
		expect(slope<30,"Traversable route slope: "..part.Name)
		expect(part.Size.X>=10,"Wide mobile-friendly route: "..part.Name)
	elseif part:IsA("BasePart") and part:GetAttribute("DynamicObstacle") then
		gates+=1
		expect(typeof(part:GetAttribute("GateClosedCFrame"))=="CFrame","Gate resets on new server")
	elseif part:IsA("TrussPart") then
		trusses+=1
		local position=part.CFrame.Position
		for _,building in ipairs(map.Architecture:GetChildren()) do
			local facade=building:FindFirstChild("Facade")
			if facade then
				local p=facade.CFrame:PointToObjectSpace(position)
				expect(not (math.abs(p.X)<facade.Size.X/2-0.05 and math.abs(p.Z)<facade.Size.Z/2-0.05),"Ladder buried inside "..building.Name)
			end
		end
	end
end
expect(routes==12,"Twelve connected bridge/ramp surfaces")
expect(gates==2,"Two timing shortcuts")
expect(trusses==6,"Six climbable ladders")
expect(not map.DistantSkyline.CityBelow.CanCollide,"No unreachable hiding floor below arena")
print("PASS: "..checks.." map, spawn clearance, route and baked-place assertions")
