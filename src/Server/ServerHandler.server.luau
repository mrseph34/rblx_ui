--!strict
-- The one server Script. Boots server systems in a controlled order and injects
-- shared context. Adding a server system = add a module under Services and boot
-- it here; nothing else changes.

local ShopService = require(script.Parent.Services.ShopService)

ShopService.Init()

print("[ServerHandler] rblx_ui server booted")
