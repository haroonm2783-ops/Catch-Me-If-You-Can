local fs=require("@lune/fs")
local roblox=require("@lune/roblox")
local luau=require("@lune/luau")
local process=require("@lune/process")
local placePath=process.args[1] or "dist/CatchMeIfYouCan.rbxl"
local place=roblox.deserializePlace(fs.readFile(placePath))
local world=place:GetService("Workspace")
-- The delivered place bakes the configured map (Catch Mall by default). Neon Heights remains a
-- supported alternate map, so this suite builds it fresh and verifies the same safety rules.
for _, child in ipairs(world:GetChildren()) do
	if child.Name=="NeonHeights" or child.Name=="CatchMall" then child:Destroy() end
end
local checks=0
local function expect(value,message) checks+=1; assert(value,message) end
local function sameTransform(a,b)
	local ac,bc={a:GetComponents()},{b:GetComponents()}
	for i,value in ipairs(ac) do if math.abs(value-bc[i])>0.0001 then return false end end
	return true
end
local env={game=place,workspace=world}
for _, k in ipairs({"Instance","CFrame","Vector3","Color3","UDim2","Enum","Font"}) do env[k]=roblox[k] end
local builder=luau.load(fs.readFile("src/server/World/MapBuilder.lua"),{environment=env})()
local result=builder.Build({Static=true})
local map=result.Model
expect(map:GetAttribute("CatchMapVersion")==4,"Current map version (bright palette) is built")
expect(builder.Build({Static=true})==result,"Repeat Build is idempotent")
local sameName=0
for _, child in ipairs(world:GetChildren()) do if child.Name=="NeonHeights" then sameName+=1 end end
expect(sameName==1,"No duplicate map")
local colliders={}
for _, part in ipairs(map:GetDescendants()) do
	if part:IsA("BasePart") then
		for _, value in ipairs({part.CFrame:GetComponents()}) do
			expect(value==value and math.abs(value)<math.huge,"Serialized transform must be finite: "..part.Name)
		end
		if part.CanCollide then table.insert(colliders,part) end
	end
end
expect(#colliders==310,"Art pass preserves the 310 original gameplay colliders")
-- Analytic OBB ray intersections validate authored geometry; this is not a physics simulation.
local function rayBox(origin,direction,part,edgeTolerance)
	local o=part.CFrame:PointToObjectSpace(origin)
	local d=part.CFrame:VectorToObjectSpace(direction)
	local tolerance=edgeTolerance or 0
	local half=part.Size/2+roblox.Vector3.new(tolerance,tolerance,tolerance)
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

-- The Studio report showed dark triangles flickering across roofs. Each roof cap
-- previously finished at exactly the same height as its walking panel. Check all
-- broad, visible, horizontal block faces, including rotated level bridges and the
-- street/lobby; narrow neon strips, mullions and trim are not walking surfaces.
local function topHeight(part) return part.CFrame.Position.Y+part.Size.Y/2 end
local function horizontalOverlap(a,b)
	-- Separating-axis test in the horizontal plane, rather than axis-aligned bounds
	-- that would incorrectly report collisions for diagonal rectangular decks.
	local delta=b.CFrame.Position-a.CFrame.Position
	for _,axis in ipairs({a.CFrame.RightVector,a.CFrame.LookVector,b.CFrame.RightVector,b.CFrame.LookVector}) do
		local ar=math.abs(a.CFrame.RightVector:Dot(axis))*a.Size.X/2+math.abs(a.CFrame.LookVector:Dot(axis))*a.Size.Z/2
		local br=math.abs(b.CFrame.RightVector:Dot(axis))*b.Size.X/2+math.abs(b.CFrame.LookVector:Dot(axis))*b.Size.Z/2
		if ar+br-math.abs(delta:Dot(axis))<0.01 then return false end
	end
	return true
end
local topFaces,walkingRoofs={},{}
for _,part in ipairs(map:GetDescendants()) do
	if part:IsA("Part") and part.Shape==roblox.Enum.PartType.Block and part.Transparency<0.95
		and part.Size.X>=2 and part.Size.Z>=2 and part.CFrame.UpVector.Y>0.99999 then
		table.insert(topFaces,part)
	end
	if part.Name=="WalkingRoof" then table.insert(walkingRoofs,part) end
end
expect(#topFaces>=150,"Coplanar regression covers the whole arena, lobby and large props")
expect(#walkingRoofs==6,"All six chase roofs are included")
for i,a in ipairs(topFaces) do
	for j=i+1,#topFaces do
		local b=topFaces[j]
		if math.abs(topHeight(a)-topHeight(b))<0.005 then
			expect(not horizontalOverlap(a,b),"Coplanar top faces z-fight: "..a:GetFullName().." / "..b:GetFullName())
		end
	end
end

-- Trimming a bridge fixes flicker only if it still meets the roof. Sample both
-- sides of every flat deck-to-roof seam across its usable width so a gap, step,
-- or over-trim fails independently of the coplanar-face check above.
local roofSeams=0
for _,deck in ipairs(map.ParkourRoutes:GetChildren()) do
	if deck:IsA("BasePart") and deck:GetAttribute("TraversalRoute") and deck.CFrame.UpVector.Y>0.99999 then
		for _,side in ipairs({-1,1}) do
			local beyond=deck.CFrame*roblox.Vector3.new(0,deck.Size.Y/2+0.5,side*(deck.Size.Z/2+0.2))
			local meetsRoof=false
			for _,roof in ipairs(walkingRoofs) do
				local distance=rayBox(beyond,roblox.Vector3.new(0,-1,0),roof)
				if distance and math.abs(distance-0.5)<0.01 then meetsRoof=true end
			end
			if meetsRoof then
				roofSeams+=1
				for _,x in ipairs({-deck.Size.X/2+0.6,0,deck.Size.X/2-0.6}) do
					for _,offset in ipairs({-0.2,0,0.2}) do
						local origin=deck.CFrame*roblox.Vector3.new(x,deck.Size.Y/2+0.5,side*(deck.Size.Z/2+offset))
						local nearest=math.huge
						local floors=table.clone(walkingRoofs)
						table.insert(floors,deck)
						for _,part in ipairs(floors) do
							-- Binary CFrames round butt-joined edges by a few millionths of
							-- a stud. Ignore only that serialization error, never a real gap.
							local distance=rayBox(origin,roblox.Vector3.new(0,-1,0),part,0.0001)
							if distance then nearest=math.min(nearest,distance) end
						end
						expect(math.abs(nearest-0.5)<0.01,"Continuous, flush roof seam: "..deck.Name.." side "..side.." x "..x.." offset "..offset.." distance "..nearest)
					end
				end
			end
		end
	end
end
expect(roofSeams==7,"Two level bridges and three ramp landings meet seven roof edges")

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
	for _,part in ipairs(map:GetDescendants()) do
		if part:IsA("BasePart") and part:GetAttribute("VisualPolish") then
			local point=part.CFrame:PointToObjectSpace(cf.Position)
			local h=part.Size/2
			local inside=math.abs(point.X)<h.X+0.8 and math.abs(point.Z)<h.Z+0.8 and math.abs(point.Y)<h.Y+1.8
			expect(not inside,label.." visually hidden by "..part.Name)
		end
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

local partCount,lightCount,polishCount=0,0,0
local landmarks={}
local canopies={MoonSweptRoof=20,MarketButterflyRoof=14,GardenSunshade=24,ArrivalCanopyWing=6.3}
for _,object in ipairs(map:GetDescendants()) do
	if object:IsA("BasePart") then
		partCount+=1
		if object:GetAttribute("DistrictLandmark") then landmarks[object:GetAttribute("DistrictLandmark")]=true end
		if object:GetAttribute("VisualPolish") then
			polishCount+=1
			expect(object.Anchored and not object.CanCollide and not object.CanTouch and not object.CanQuery,
				"Art adds neither moving collision nor false vault/tag targets: "..object.Name)
		end
		if object:IsDescendantOf(map.DistantSkyline) then
			expect(not object.CanCollide and not object.CanQuery and not object.CastShadow,
				"Distant skyline stays outside collision and shadow budgets: "..object.Name)
		end
		local roof=canopies[object.Name]
		if roof then
			local lowest=math.huge
			for _,x in ipairs({-0.5,0.5}) do for _,y in ipairs({-0.5,0.5}) do for _,z in ipairs({-0.5,0.5}) do
				lowest=math.min(lowest,(object.CFrame*roblox.Vector3.new(x*object.Size.X,y*object.Size.Y,z*object.Size.Z)).Y)
			end end end
			expect(lowest>roof+7.5,"Roof art clears avatars and route sightlines: "..object.Name)
		end
	elseif object:IsA("PointLight") then
		lightCount+=1
		expect(not object.Shadows,"Local decorative lights use no expensive shadow maps")
	elseif object:IsA("ParticleEmitter") then
		expect(false,"Static map must not acquire continuous particle emitters")
	end
end
expect(partCount==map:GetAttribute("StaticPartCount") and partCount<1800,"Updated art stays within static mobile part budget")
expect(lightCount==10,"Art pass adds no local lights")
expect(polishCount>=150,"District art is present in the delivered place")
for _,name in ipairs({"Citrus","Moon","Garden","Polar","Ember","Meridian","Social"}) do
	expect(landmarks[name],name.." has a distinctive landmark silhouette")
end
local citrus=map.Architecture["01_CitrusArcade"]
local polar=map.Architecture["04_PolarLaundry"]
expect(citrus.CitrusMarqueeFruit.CFrame.Position.Z>citrus.CitrusMarqueeHalo.CFrame.Position.Z,"Citrus graphic faces the city approach")
expect(polar.PolarWasherGlass.CFrame.Position.Z>polar.PolarWasherHalo.CFrame.Position.Z,"Washer graphic faces the southern approach")
expect(polar.PolarWasherHalo.CFrame.Position.Y-polar.PolarWasherHalo.Size.Y/2>23,"Washer halo does not obscure SPIN / CITY lettering")
expect(map.SocialDeck.ChampionHaloInset.CFrame.Position.Z>map.SocialDeck.ChampionHalo.CFrame.Position.Z,"Podium emblem faces the lobby")

-- Reloading an old baked model must replace it once and then reuse the new version.
-- This models opening a stale source place with the newer MapBuilder module.
local stalePlace=roblox.deserializePlace(fs.readFile(placePath))
local staleWorld=stalePlace:GetService("Workspace")
for _, child in ipairs(staleWorld:GetChildren()) do
	if child.Name=="NeonHeights" or child.Name=="CatchMall" then child:Destroy() end
end
local oldEnv=table.clone(env)
oldEnv.game=stalePlace; oldEnv.workspace=staleWorld
local staleMap=luau.load(fs.readFile("src/server/World/MapBuilder.lua"),{environment=oldEnv})().Build({Static=true}).Model
staleMap:SetAttribute("CatchMapVersion",2)
local freshEnv=table.clone(env)
freshEnv.game=stalePlace; freshEnv.workspace=staleWorld
local reloaded=luau.load(fs.readFile("src/server/World/MapBuilder.lua"),{environment=freshEnv})()
local rebuilt=reloaded.Build({Static=true})
expect(staleMap.Parent==nil and rebuilt.Model~=staleMap,"Previous baked map is replaced without duplicate geometry")
expect(rebuilt.Model:GetAttribute("CatchMapVersion")==4,"Replacement uses current map version")
expect(reloaded.Build({Static=true})==rebuilt,"Replacement is reused on repeated builds")
expect(sameTransform(rebuilt.LobbySpawn,result.LobbySpawn),"Version migration preserves lobby spawn")
for _,kind in ipairs({"RunnerSpawns","HunterSpawns","Podiums"}) do
	expect(#rebuilt[kind]==#result[kind],"Migration preserves "..kind.." count")
	for i,cf in ipairs(result[kind]) do expect(sameTransform(rebuilt[kind][i],cf),"Migration preserves "..kind.." "..i) end
end
print("PASS: "..checks.." map, spawn clearance, art safety, route and baked-place assertions ("..partCount.." parts)")
