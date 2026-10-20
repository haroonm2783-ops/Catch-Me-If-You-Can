local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local shared = ReplicatedStorage:WaitForChild("CatchShared")
local remoteFolder = ReplicatedStorage:WaitForChild("CatchRemotes")
local ctx = {
	Config=require(shared.Config), Catalog=require(shared.Catalog), Rules=require(shared.Rules), Achievements=require(shared.Achievements),
	Remotes={}, State={}, Profile={}, Controllers={}, Signals={},
}
for _, name in ipairs({"State","Action","Profile","Notice","Query"}) do ctx.Remotes[name] = remoteFolder:WaitForChild(name) end
for _, name in ipairs({"UIController","MovementController","EffectsController"}) do
	ctx.Controllers[name] = require(script.Parent.Controllers[name]).new(ctx)
end
local function deliver(method, value)
	for name, controller in pairs(ctx.Controllers) do
		if controller[method] then
			local ok, err = pcall(controller[method],controller,value)
			if not ok then warn("[Catch] " .. name .. "." .. method .. ": " .. tostring(err)) end
		end
	end
end
ctx.Remotes.State.OnClientEvent:Connect(function(state)
	if type(state) ~= "table" then return end
	ctx.State = state
	deliver("OnState",state)
end)
ctx.Remotes.Profile.OnClientEvent:Connect(function(profile)
	if type(profile) ~= "table" then return end
	ctx.Profile = profile
	deliver("OnProfile",profile)
end)
ctx.Remotes.Notice.OnClientEvent:Connect(function(notice)
	if type(notice) == "table" then deliver("OnNotice",notice) end
end)
for _, name in ipairs({"UIController","MovementController","EffectsController"}) do
	ctx.Controllers[name]:Start()
end
Players.LocalPlayer.CharacterAdded:Connect(function(character) deliver("OnCharacter",character) end)
if Players.LocalPlayer.Character then deliver("OnCharacter",Players.LocalPlayer.Character) end
-- Handles late clients and slow profile loads without treating absent data as saved.
task.spawn(function()
	while true do
		local ok, response = pcall(function() return ctx.Remotes.Query:InvokeServer() end)
		if ok and type(response)=="table" then
			if type(response.state)=="table" then ctx.State=response.state; deliver("OnState",response.state) end
			if type(response.profile)=="table" then ctx.Profile=response.profile; deliver("OnProfile",response.profile) end
		end
		if ctx.Profile.loaded then break end
		task.wait(3)
	end
end)
