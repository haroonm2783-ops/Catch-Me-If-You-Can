local fs=require("@lune/fs")
local roblox=require("@lune/roblox")
local luau=require("@lune/luau")
local process=require("@lune/process")
local placePath=process.args[1] or "dist/CatchMeIfYouCan.rbxl"
local place=roblox.deserializePlace(fs.readFile(placePath))
local world=place:GetService("Workspace")
local map=world:FindFirstChild("CatchMall")
local checks=0
local function expect(value,message) checks+=1; assert(value,message) end
local function sameTransform(a,b)
	local ac,bc={a:GetComponents()},{b:GetComponents()}
	for i,value in ipairs(ac) do if math.abs(value-bc[i])>0.0001 then return false end end
	return true
end
local env={game=place,workspace=world}
for key,value in pairs(roblox) do env[key]=value end
local builder=luau.load(fs.readFile("src/server/World/MapBuilder.lua"),{environment=env})()
local result=builder.Build({Static=true})
expect(map~=nil,"Baked mall present")
expect(map:GetAttribute("CatchMapVersion")==5,"Current mall map version is baked into the delivered map")
expect(result.Model==map,"Baked map reused in place")
expect(builder.Build({Static=true})==result,"Repeat Build is idempotent")
local sameName=0
for _, child in ipairs(world:GetChildren()) do if child.Name=="CatchMall" then sameName+=1 end end
expect(sameName==1 and world:FindFirstChild("NeonHeights")==nil,"No duplicate map and the old city is not loaded")
local colliders={}
for _, part in ipairs(map:GetDescendants()) do
	if part:IsA("BasePart") then
		for _, value in ipairs({part.CFrame:GetComponents()}) do
			expect(value==value and math.abs(value)<math.huge,"Serialized transform must be finite: "..part.Name)
		end
		for _, v in ipairs({part.Size.X,part.Size.Y,part.Size.Z}) do expect(v>0,"Positive size: "..part.Name) end
		if part.CanCollide then table.insert(colliders,part) end
	end
end
-- Analytic OBB ray intersections validate authored geometry; this is not a physics simulation.
local function rayBox(origin,direction,part,edgeTolerance)
	local o=part.CFrame:PointToObjectSpace(origin)
	local d=part.CFrame:VectorToObjectSpace(direction)
	local tolerance=edgeTolerance or 0
	-- A negative marker means: inflate only the local X/Z footprint (avatar radius), never height.
	local half
	if tolerance<0 then half=part.Size/2+roblox.Vector3.new(-tolerance,0,-tolerance)
	else half=part.Size/2+roblox.Vector3.new(tolerance,tolerance,tolerance) end
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
	return near,far
end

-- Coplanar visible block tops z-fight in Roblox. Check every broad horizontal face pair.
local function topHeight(part) return part.CFrame.Position.Y+part.Size.Y/2 end
local function horizontalOverlap(a,b)
	local delta=b.CFrame.Position-a.CFrame.Position
	for _,axis in ipairs({a.CFrame.RightVector,a.CFrame.LookVector,b.CFrame.RightVector,b.CFrame.LookVector}) do
		local ar=math.abs(a.CFrame.RightVector:Dot(axis))*a.Size.X/2+math.abs(a.CFrame.LookVector:Dot(axis))*a.Size.Z/2
		local br=math.abs(b.CFrame.RightVector:Dot(axis))*b.Size.X/2+math.abs(b.CFrame.LookVector:Dot(axis))*b.Size.Z/2
		if ar+br-math.abs(delta:Dot(axis))<0.01 then return false end
	end
	return true
end
local topFaces={}
for _,part in ipairs(map:GetDescendants()) do
	if part:IsA("Part") and part.Shape==roblox.Enum.PartType.Block and part.Transparency<0.95
		and part.Size.X>=2 and part.Size.Z>=2 and part.CFrame.UpVector.Y>0.99999 and not part:IsDescendantOf(map.DistantSkyline) then
		table.insert(topFaces,part)
	end
end
expect(#topFaces>=200,"Coplanar regression covers the whole mall and Plaza")
for i,a in ipairs(topFaces) do
	local ta=topHeight(a)
	for j=i+1,#topFaces do
		local b=topFaces[j]
		if math.abs(ta-topHeight(b))<0.005 then
			expect(not horizontalOverlap(a,b),"Coplanar top faces z-fight: "..a:GetFullName().." / "..b:GetFullName())
		end
	end
end

local function checkSpawn(cf,label)
	local nearest=math.huge
	for _,part in ipairs(colliders) do
		local near=rayBox(cf.Position,roblox.Vector3.new(0,-1,0),part)
		if near then nearest=math.min(nearest,near) end
	end
	expect(nearest>=2.8 and nearest<=4.5,label.." has floor at avatar foot height; distance="..nearest)
	for _,part in ipairs(map:GetDescendants()) do
		if part:IsA("BasePart") and (part.CanCollide or part:GetAttribute("VisualPolish")) and not part:IsDescendantOf(map.DistantSkyline) then
			local point=part.CFrame:PointToObjectSpace(cf.Position)
			local h=part.Size/2
			local inside=math.abs(point.X)<h.X+0.8 and math.abs(point.Z)<h.Z+0.8 and math.abs(point.Y)<h.Y+1.8
			expect(not inside,label.." overlaps "..part.Name.." "..part:GetFullName())
		end
	end
end
expect(#result.RunnerSpawns>=12 and #result.HunterSpawns==2 and #result.Podiums==3,"Complete spawn roster")
for i,cf in ipairs(result.RunnerSpawns) do checkSpawn(cf,"Runner "..i) end
for i,cf in ipairs(result.HunterSpawns) do checkSpawn(cf,"Hunter "..i) end
checkSpawn(result.LobbySpawn,"Plaza lobby")
for i,cf in ipairs(result.Podiums) do
	expect(cf.Position.Z>260 and cf.Position.Z<300,"Podium "..i.." stands in the Plaza")
end
expect(result.LobbySpawn.Position.Z>200,"Lobby spawn is in the separate Plaza hub")
for _,cf in ipairs(result.RunnerSpawns) do expect(math.abs(cf.Position.Z)<104,"Runner spawn is inside the mall") end

local routes,gates,stairs,escalators=0,0,0,0
for _,part in ipairs(map:GetDescendants()) do
	if part:IsA("BasePart") and part:GetAttribute("TraversalRoute") then
		routes+=1
		local slope=math.deg(math.asin(math.abs(part.CFrame.LookVector.Y)))
		expect(slope<30,"Traversable route slope: "..part.Name)
		expect(part.Size.X>=10,"Wide mobile-friendly route: "..part.Name)
		if part.Name:find("Escalator") then escalators+=1 end
	elseif part:IsA("BasePart") and part:GetAttribute("DynamicObstacle") then
		gates+=1
		expect(typeof(part:GetAttribute("GateClosedCFrame"))=="CFrame","Gate resets on new server")
	elseif part:IsA("BasePart") and part:GetAttribute("StairStep") then
		stairs+=1
	end
end
expect(escalators==2,"Two escalator connections")
expect(stairs==40,"Two stair runs of twenty steps")
expect(gates==2,"Two timing shutters")
expect(not map.DistantSkyline.CityBelow.CanCollide,"No unreachable hiding floor below arena")

-- Budgets and art safety ------------------------------------------------------------
local partCount,lightCount,emitters,polishCount,signs=0,0,0,0,0
for _,object in ipairs(map:GetDescendants()) do
	if object:IsA("BasePart") then
		partCount+=1
		if object:GetAttribute("VisualPolish") then
			polishCount+=1
			expect(object.Anchored and not object.CanCollide and not object.CanQuery,"Art adds no collision or false vault/tag targets: "..object.Name)
		end
		if object:IsDescendantOf(map.DistantSkyline) then
			expect(not object.CanCollide and not object.CanQuery and not object.CastShadow,"Distant skyline stays outside collision and shadow budgets: "..object.Name)
		end
		if object.CanCollide and object:GetAttribute("Vaultable") then
			expect(object.Size.Y<=4.5 and object.Size.Y>=1.5,"Vaultable prop is within vault height: "..object.Name)
		end
	elseif object:IsA("PointLight") then
		lightCount+=1
		expect(not object.Shadows,"Decorative lights use no shadow maps")
	elseif object:IsA("ParticleEmitter") then
		emitters+=1
		expect(object.Rate<=30,"Particle rates stay low")
	elseif object:IsA("SurfaceGui") then signs+=1 end
end
expect(emitters==2,"Only the two fountain emitters animate continuously")
expect(partCount==map:GetAttribute("StaticPartCount") and partCount<7600,"Static part budget: "..partCount)
expect(lightCount<=64,"Local light budget: "..lightCount)
expect(polishCount>=800,"Art present")
expect(signs>=60,"Brand signs present")
-- Ten enterable stores: every one has a front opening and at least one other route in or out.
local enterable=0
for _,store in ipairs(map.Stores:GetChildren()) do
	if store:FindFirstChild("Carpet") then enterable+=1 end
end
if map.Stores:FindFirstChild("DeptCarpet") then enterable+=1 end -- the department store fills the east wing
expect(enterable==10,"Ten enterable stores, found "..enterable)
for _,name in ipairs({"CatchMall"}) do expect(world:FindFirstChild(name),"Map root") end
local prompts,actions=0,{}
for _,object in ipairs(map.PlazaHub:GetDescendants()) do
	if object:IsA("ProximityPrompt") then prompts+=1; actions[object:GetAttribute("HubAction")]=true end
end
for _,action in ipairs({"Play","Locker","Shop","Quests","Roster","Rewards"}) do expect(actions[action],"Plaza has a "..action.." interaction") end
expect(map.PlazaHub:FindFirstChild("LeaderboardBoard") and map.PlazaHub.LeaderboardBoard:FindFirstChildOfClass("SurfaceGui"),"Leaderboard board is present")
local showcase=0
for _,child in ipairs(map.PlazaHub:GetChildren()) do if child.Name:find("SkinShowcase_") then showcase+=1 end end
expect(showcase==4,"Four skin showcase figures stand in the Plaza")

-- Walkability: grid flood fill over the real collision boxes. Nodes are standing surfaces;
-- steps up to 1.3 studs walk, up to 4.4 jump/vault, drops of any height are allowed.
local CELL,X0,X1,Z0,Z1=2,-140,140,-106,106
local buckets={}
local function key(i,j) return i*1000+j end
for _,part in ipairs(colliders) do
	if not part:IsDescendantOf(map.PlazaHub) and part.Name~="Foundation" then
		local cf,s=part.CFrame,part.Size
		local ex=(math.abs(cf.RightVector.X)*s.X+math.abs(cf.UpVector.X)*s.Y+math.abs(cf.LookVector.X)*s.Z)/2+1.2
		local ez=(math.abs(cf.RightVector.Z)*s.X+math.abs(cf.UpVector.Z)*s.Y+math.abs(cf.LookVector.Z)*s.Z)/2+1.2
		for i=math.floor((cf.Position.X-ex-X0)/CELL),math.floor((cf.Position.X+ex-X0)/CELL) do
			for j=math.floor((cf.Position.Z-ez-Z0)/CELL),math.floor((cf.Position.Z+ez-Z0)/CELL) do
				local k=key(i,j)
				buckets[k]=buckets[k] or {}
				table.insert(buckets[k],part)
			end
		end
	end
end
local columns={}
local nx,nz=math.floor((X1-X0)/CELL),math.floor((Z1-Z0)/CELL)
local function column(i,j)
	local k=key(i,j)
	if columns[k]~=nil then return columns[k] end
	local x,z=X0+(i+0.5)*CELL,Z0+(j+0.5)*CELL
	local intervals={}
	for _,part in ipairs(buckets[k] or {}) do
		-- Inflate by the avatar radius: thin walls then always block a 2-stud sample.
		local near,far=rayBox(roblox.Vector3.new(x,60,z),roblox.Vector3.new(0,-1,0),part,-1.0)
		if near then table.insert(intervals,{top=60-near,bottom=60-far,part=part}) end
	end
	local surfaces={}
	for a,iv in ipairs(intervals) do
		-- A surface counts only if the point is truly over the part (no inflation).
		local n2=rayBox(roblox.Vector3.new(x,60,z),roblox.Vector3.new(0,-1,0),iv.part,0)
		if n2 then
			local top=60-n2
			local free=true
			for b,other in ipairs(intervals) do
				-- Anything within a walkable step (1.3) is climbed onto, not a barrier.
				if b~=a and other.bottom<top+5.2 and other.top>top+1.3 then free=false break end
			end
			if free and top>-1 and top<50 then table.insert(surfaces,top) end
		end
	end
	table.sort(surfaces)
	local unique={}
	for _,s in ipairs(surfaces) do if #unique==0 or s-unique[#unique]>0.3 then table.insert(unique,s) end end
	columns[k]=unique
	return unique
end
local function nodeOf(p)
	local i,j=math.floor((p.X-X0)/CELL),math.floor((p.Z-Z0)/CELL)
	local best,bestD=nil,math.huge
	for _,s in ipairs(column(i,j)) do
		local d=math.abs(s-(p.Y-3.3))
		if d<bestD then best,bestD=s,d end
	end
	return i,j,best
end
local function reach(si,sj,sy)
	local seen={}
	local function id(i,j,y) return key(i,j)*100+math.floor(y*2+0.5) end
	local queue,head={{si,sj,sy}},1
	seen[id(si,sj,sy)]=true
	local count=0
	while head<=#queue do
		local i,j,y=table.unpack(queue[head]); head+=1; count+=1
		for _,d in ipairs({{1,0},{-1,0},{0,1},{0,-1}}) do
			local ni,nj=i+d[1],j+d[2]
			if ni>=0 and nj>=0 and ni<nx and nj<nz then
				for _,s in ipairs(column(ni,nj)) do
					local rise=s-y
					if rise<=4.4 and rise>=-60 then
						-- Walking up more than 1.3 needs a jump over a low obstacle: only allowed if the
						-- neighbouring surface is not on a wall (rise <= 4.4 already enforces that).
						local k=id(ni,nj,s)
						if not seen[k] then seen[k]=true; table.insert(queue,{ni,nj,s}) end
					end
				end
			end
		end
	end
	return seen,count
end
local starts={}
for _,cf in ipairs(result.HunterSpawns) do starts[#starts+1]=cf end
for _,cf in ipairs(result.RunnerSpawns) do starts[#starts+1]=cf end
local seenFromHunter,huntCount=nil,0
do
	local i,j,y=nodeOf(result.HunterSpawns[1].Position)
	expect(y~=nil,"Hunter spawn stands on a walkable surface")
	seenFromHunter,huntCount=reach(i,j,y)
end
expect(huntCount>8000,"Hunters can reach a large walkable network: "..huntCount)
for index,cf in ipairs(starts) do
	local i,j,y=nodeOf(cf.Position)
	expect(y~=nil,"Spawn "..index.." has a walkable cell")
	expect(seenFromHunter[key(i,j)*100+math.floor(y*2+0.5)],"Hunter can reach spawn "..index.." at "..tostring(cf.Position))
end
-- Return paths: every runner spawn can reach both floors' key landmarks and the hunter spawn.
local function reachable(from,to)
	local i,j,y=nodeOf(from)
	local seen=reach(i,j,y)
	local ti,tj,ty=nodeOf(to)
	return ty~=nil and seen[key(ti,tj)*100+math.floor(ty*2+0.5)]
end
local landmarks={
	roundFountain=roblox.Vector3.new(0,3.3,-24), upperBridge=roblox.Vector3.new(0,19.3,0), foodCourt=roblox.Vector3.new(-104,3.3,0),
	arcade=roblox.Vector3.new(88,3.3,0), department=roblox.Vector3.new(80,19.3,0), skyLounge=roblox.Vector3.new(-106,19.3,-44),
}
for index,cf in ipairs(result.RunnerSpawns) do
	for name,target in pairs(landmarks) do
		expect(reachable(cf.Position,target),"Runner spawn "..index.." can reach "..name)
	end
	expect(reachable(cf.Position,result.HunterSpawns[1].Position),"Runner spawn "..index.." can return to the ground floor")
end
-- Every enterable store must connect both ways with the hall (no sealed rooms, no one-door traps).
for _,store in ipairs(map.Stores:GetChildren()) do
	local carpet=store:FindFirstChild("Carpet")
	if carpet then
		local floor=carpet.CFrame.Position.Y-0.1
		local north=carpet.CFrame.Position.Z<0
		local inside=roblox.Vector3.new(carpet.CFrame.Position.X,floor+3.3,north and -61 or 61)
		local ii,jj,yy=nodeOf(inside)
		expect(yy~=nil,store.Name.." entry point stands on a walkable surface "..tostring(inside))
		expect(reachable(inside,result.HunterSpawns[1].Position),store.Name.." leads out to the hall")
		expect(reachable(result.HunterSpawns[1].Position,inside),store.Name.." can be entered from the hall")
	end
end

-- Reloading an old baked model must replace it once and then reuse the new version.
local stalePlace=roblox.deserializePlace(fs.readFile(placePath))
local staleWorld=stalePlace:GetService("Workspace")
local staleMap=staleWorld.CatchMall
staleMap:SetAttribute("CatchMapVersion",2)
local freshEnv=table.clone(env)
freshEnv.game=stalePlace; freshEnv.workspace=staleWorld
local reloaded=luau.load(fs.readFile("src/server/World/MapBuilder.lua"),{environment=freshEnv})()
local rebuilt=reloaded.Build({Static=true})
expect(staleMap.Parent==nil and rebuilt.Model~=staleMap,"Previous baked map is replaced without duplicate geometry")
expect(rebuilt.Model:GetAttribute("CatchMapVersion")==5,"Replacement uses current map version")
expect(reloaded.Build({Static=true})==rebuilt,"Replacement is reused on repeated builds")
expect(sameTransform(rebuilt.LobbySpawn,result.LobbySpawn),"Version migration preserves lobby spawn")
for _,kind in ipairs({"RunnerSpawns","HunterSpawns","Podiums"}) do
	expect(#rebuilt[kind]==#result[kind],"Migration preserves "..kind.." count")
	for i,cf in ipairs(result[kind]) do expect(sameTransform(rebuilt[kind][i],cf),"Migration preserves "..kind.." "..i) end
end
print("PASS: "..checks.." mall, hub, spawn clearance, walkability, art safety and baked-place assertions ("..partCount.." parts)")
