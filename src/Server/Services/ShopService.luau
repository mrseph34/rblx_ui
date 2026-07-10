--!strict
-- Authoritative purchase validation. Holds a per-player balance table (in
-- memory for MVP — swap for a ProfileStore wrapper later) and validates every
-- purchase against ShopConfig so the client can never fabricate currency. The
-- client's optimistic UI is confirmed or corrected by the result this returns.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShopConfig = require(ReplicatedStorage.Shared.Config.ShopConfig)
local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)
local SharedTypes = require(ReplicatedStorage.Shared.Types)

local ShopService = {}

local balances: { [number]: SharedTypes.CurrencyBalances } = {}

function ShopService.GetBalances(player: Player): SharedTypes.CurrencyBalances
	return balances[player.UserId] or table.clone(ShopConfig.StartingBalances)
end

local function handlePurchase(player: Player, itemId: string): SharedTypes.PurchaseResult
	local item = ShopConfig.GetItemById(itemId)
	if not item then
		return { success = false, messageKey = "shop.purchase_failed" }
	end
	local playerBalances = balances[player.UserId]
	if not playerBalances then
		playerBalances = table.clone(ShopConfig.StartingBalances)
		balances[player.UserId] = playerBalances
	end
	if not ShopConfig.CanAfford(playerBalances, item) then
		return { success = false, messageKey = "shop.cant_afford", balances = playerBalances }
	end
	playerBalances[item.currencyType] = (playerBalances[item.currencyType] or 0) - item.price
	return { success = true, messageKey = "shop.purchase_success", balances = playerBalances }
end

function ShopService.Init()
	local folder = Remotes.CreateAll()
	local purchase = folder:FindFirstChild("PurchaseItem") :: RemoteFunction
	local currencyChanged = folder:FindFirstChild("CurrencyChanged") :: RemoteEvent

	purchase.OnServerInvoke = function(player: Player, itemId: any): SharedTypes.PurchaseResult
		if typeof(itemId) ~= "string" then
			return { success = false, messageKey = "shop.purchase_failed" }
		end
		local result = handlePurchase(player, itemId)
		if result.success and result.balances then
			currencyChanged:FireClient(player, result.balances)
		end
		return result
	end

	Players.PlayerAdded:Connect(function(player: Player)
		balances[player.UserId] = table.clone(ShopConfig.StartingBalances)
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		balances[player.UserId] = nil
	end)
end

return ShopService
