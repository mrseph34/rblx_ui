-- Single source of truth for remote object names and classes. The server
-- calls CreateAll() once at boot; clients look remotes up with WaitFor().
-- Add a remote by adding one entry to Definitions — never Instance.new a
-- remote anywhere else.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = {}

Remotes.FolderName = "UIRemotes"

Remotes.Definitions = {
	-- client -> server: (itemId: string) -> Types.PurchaseResult
	PurchaseItem = "RemoteFunction",
	-- server -> client: (balances: Types.CurrencyBalances)
	CurrencyChanged = "RemoteEvent",
}

-- Server only. Idempotent.
function Remotes.CreateAll(): Folder
	local folder = ReplicatedStorage:FindFirstChild(Remotes.FolderName)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = Remotes.FolderName
		folder.Parent = ReplicatedStorage
	end
	for name, className in Remotes.Definitions do
		if not folder:FindFirstChild(name) then
			local remote = Instance.new(className)
			remote.Name = name
			remote.Parent = folder
		end
	end
	return folder
end

-- Client. Returns nil (with a warning) instead of infinitely yielding if the
-- server never created the remote, so UI can boot in degraded/test setups.
function Remotes.WaitFor(name: string, timeout: number?): Instance?
	local folder = ReplicatedStorage:WaitForChild(Remotes.FolderName, timeout or 10)
	if not folder then
		warn("[Remotes] Folder '" .. Remotes.FolderName .. "' never appeared")
		return nil
	end
	local remote = folder:WaitForChild(name, timeout or 10)
	if not remote then
		warn("[Remotes] Remote '" .. name .. "' never appeared")
	end
	return remote
end

return Remotes
