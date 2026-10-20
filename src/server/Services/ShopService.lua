-- All prices, ownership, entitlements, and marketplace verification stay on the server.
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")

local ShopService = {}
ShopService.__index = ShopService

local function validPass(id)
	return type(id) == "number" and id > 0 and id < 9007199254740991 and id % 1 == 0
end

function ShopService.new(ctx)
	return setmetatable({ ctx = ctx, busy = {}, pending = {}, verified = {}, lastPrompt = {} }, ShopService)
end

function ShopService:_Notice(player, text, success)
	if player.Parent == Players then self.ctx.Remotes.Notice:FireClient(player, { kind = "purchase", text = text, success = success == true }) end
end

function ShopService:_PassItems(passId)
	local ids = {}
	for id, item in pairs(self.ctx.Catalog.Items) do
		if item.currency == "Robux" and item.gamePassId == passId then table.insert(ids, id) end
	end
	return ids
end

function ShopService:_Verify(player, passId, afterPurchase)
	local data = self.ctx.Services.DataService
	if not validPass(passId) or #self:_PassItems(passId) == 0 or not data:Ready(player) then return false, "unavailable" end
	self.verified[player] = self.verified[player] or {}
	if self.verified[player][passId] then
		data:Grant(player, self:_PassItems(passId))
		return true
	end
	local successfulQuery = false
	for attempt = 1, afterPurchase and 3 or 1 do
		local ok, owns = pcall(function() return MarketplaceService:UserOwnsGamePassAsync(player.UserId, passId) end)
		if player.Parent ~= Players or not data:Ready(player) then return false, "unavailable" end
		if ok then
			successfulQuery = true
			if owns then
				self.verified[player] = self.verified[player] or {}
				self.verified[player][passId] = true
				local granted = data:Grant(player, self:_PassItems(passId), afterPurchase and "Purchase verified. Your cosmetics are ready." or nil)
				return granted
			end
		end
		if afterPurchase and attempt < 3 then task.wait(attempt) end
	end
	return false, successfulQuery and "not_owned" or "unavailable"
end

function ShopService:Purchase(player, id)
	local data = self.ctx.Services.DataService
	if not data:Ready(player) then self:_Notice(player, "Your profile is still loading."); return false end
	local item = type(id) == "string" and self.ctx.Catalog.Get(id)
	if not item then self:_Notice(player, "This item is unavailable."); return false end
	local profile = data:Get(player)
	if profile.owned[id] then self:_Notice(player, "You already own " .. item.name .. ". Equip it from your inventory."); return true end
	if item.currency == "Free" then
		local ok = data:Grant(player, { id }, "Added " .. item.name .. " to your inventory.")
		return ok
	elseif item.currency == "Coins" then
		local ok, message = data:_PurchaseWithCoins(player, id)
		self:_Notice(player, message, ok)
		return ok
	elseif item.currency == "Milestone" then
		local milestone = item.milestone
		if not milestone then self:_Notice(player, "This reward is unavailable."); return false end
		local progress = profile.stats[milestone.stat] or profile[milestone.stat] or 0
		if progress >= milestone.value then return data:Grant(player, { id }, "Unlocked " .. item.name .. ".") end
		self:_Notice(player, "Reach " .. milestone.value .. " " .. milestone.stat .. " to unlock this cosmetic.")
		return false
	elseif item.currency ~= "Robux" then
		self:_Notice(player, "This item is unavailable.")
		return false
	end
	if not validPass(item.gamePassId) then
		self:_Notice(player, "This Robux cosmetic is not configured for sale yet.")
		return false
	end
	if self.busy[player] or self.pending[player] then self:_Notice(player, "Finish your current purchase first."); return false end
	if os.clock() - (self.lastPrompt[player] or -100) < 3 then self:_Notice(player, "Please wait a moment before trying again."); return false end
	self.busy[player] = true
	local owns, reason = self:_Verify(player, item.gamePassId, false)
	if player.Parent ~= Players then self.busy[player] = nil; return false end
	if owns then
		self.busy[player] = nil
		self:_Notice(player, "Ownership verified. " .. item.name .. " is in your inventory.", true)
		return true
	end
	if reason == "unavailable" then
		self.busy[player] = nil
		self:_Notice(player, "Roblox could not verify your ownership. Please try again shortly.")
		return false
	end
	self.pending[player] = item.gamePassId
	self.lastPrompt[player] = os.clock()
	local ok = pcall(function() MarketplaceService:PromptGamePassPurchase(player, item.gamePassId) end)
	self.busy[player] = nil
	if not ok then
		self.pending[player] = nil
		self:_Notice(player, "Roblox could not open the purchase prompt. Please try again later.")
		return false
	end
	self:_Notice(player, "Confirm the price and purchase in the Roblox prompt.")
	return true
end

-- Coin packs. The prompt is only intent; coins are granted from ProcessReceipt below.
function ShopService:PurchaseProduct(player, id)
	local data = self.ctx.Services.DataService
	if not data:Ready(player) then self:_Notice(player, "Your profile is still loading."); return false end
	local product = type(id) == "string" and self.ctx.Catalog.Product(id)
	if not product then self:_Notice(player, "This coin pack is unavailable."); return false end
	if not validPass(product.productId) then
		self:_Notice(player, "Coin packs are not configured for sale yet.")
		return false
	end
	if os.clock() - (self.lastPrompt[player] or -100) < 3 then self:_Notice(player, "Please wait a moment before trying again."); return false end
	self.lastPrompt[player] = os.clock()
	local ok = pcall(function() MarketplaceService:PromptProductPurchase(player, product.productId) end)
	if not ok then self:_Notice(player, "Roblox could not open the purchase prompt. Please try again later."); return false end
	return true
end

function ShopService:ProcessReceipt(info)
	local notYet = Enum.ProductPurchaseDecision.NotProcessedYet
	if type(info) ~= "table" or type(info.PurchaseId) ~= "string" or info.PurchaseId == "" then return notYet end
	local player = Players:GetPlayerByUserId(info.PlayerId)
	-- A player who left gets the receipt again next join; Roblox keeps resending until it is granted.
	if not player then return notYet end
	local product = self.ctx.Catalog.ProductByRobloxId(info.ProductId)
	if not product then
		warn("[Catch] Receipt for unknown developer product " .. tostring(info.ProductId))
		return notYet
	end
	local data = self.ctx.Services.DataService
	local ok, granted = pcall(function()
		return data:GrantProductCoins(player, info.PurchaseId, product.coins)
	end)
	if not ok or not granted then return notYet end
	self:_Notice(player, "+" .. product.coins .. " coins added. Spend them on any cosmetic!", true)
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

function ShopService:_Refresh(player)
	local data = self.ctx.Services.DataService
	while player.Parent == Players and not data:Ready(player) do task.wait(0.2) end
	if player.Parent ~= Players then return end
	local seen = {}
	local failed = false
	for _, item in pairs(self.ctx.Catalog.Items) do
		if item.currency == "Robux" and validPass(item.gamePassId) and not seen[item.gamePassId] then
			seen[item.gamePassId] = true
			local _, reason = self:_Verify(player, item.gamePassId, false)
			if reason == "unavailable" then failed = true end
			if player.Parent ~= Players then return end
		end
	end
	if failed then self:_Notice(player, "Some pass ownership checks are unavailable. Rejoin or select the item later to retry.") end
end

function ShopService:Start()
	if self.started then return end
	self.started = true
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, wasPurchased)
		if self.pending[player] == passId then self.pending[player] = nil end
		if not wasPurchased or not validPass(passId) or #self:_PassItems(passId) == 0 then return end
		-- The prompt result is an intent signal. Grant only after a server ownership query.
		task.spawn(function()
			local verified = self:_Verify(player, passId, true)
			if not verified then self:_Notice(player, "Purchase verification is delayed. Rejoin to restore owned passes; you do not need to buy again.") end
		end)
	end)
	MarketplaceService.ProcessReceipt = function(info) return self:ProcessReceipt(info) end
	Players.PlayerAdded:Connect(function(player) task.spawn(function() self:_Refresh(player) end) end)
	Players.PlayerRemoving:Connect(function(player)
		self.busy[player] = nil
		self.pending[player] = nil
		self.verified[player] = nil
		self.lastPrompt[player] = nil
	end)
	for _, player in ipairs(Players:GetPlayers()) do task.spawn(function() self:_Refresh(player) end) end
end

return ShopService
