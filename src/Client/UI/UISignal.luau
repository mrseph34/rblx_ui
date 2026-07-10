-- Minimal signal primitive used by UI controllers (ThemeChanged, PackChanged,
-- ScreenShown, ...). Handlers run in their own thread so one failing listener
-- can never break the others. Connections expose Disconnect() with the same
-- shape as RBXScriptConnection, so cleanup code can treat both uniformly.

local UISignal = {}
UISignal.__index = UISignal

function UISignal.new()
	return setmetatable({ _handlers = {} }, UISignal)
end

function UISignal:Connect(handler: (...any) -> ())
	local handlers = self._handlers
	table.insert(handlers, handler)

	local connection = {}
	function connection.Disconnect(_self)
		local index = table.find(handlers, handler)
		if index then
			table.remove(handlers, index)
		end
	end
	return connection
end

function UISignal:Fire(...)
	for _, handler in table.clone(self._handlers) do
		task.spawn(handler, ...)
	end
end

function UISignal:Clear()
	table.clear(self._handlers)
end

return UISignal
