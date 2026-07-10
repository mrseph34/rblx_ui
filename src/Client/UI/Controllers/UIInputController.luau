--!strict
-- Cross-platform action dispatcher. Translates keyboard/gamepad input into
-- abstract actions (from InputConfig) and fires bound callbacks. Screens and
-- the ClientHandler bind actions here instead of touching UserInputService, so
-- rebinding is a config edit and PC/console share one path.

local UserInputService = game:GetService("UserInputService")

local InputConfig = require(script.Parent.Parent.Config.InputConfig)
local UISignal = require(script.Parent.Parent.UISignal)

local UIInputController = {}
UIInputController.__index = UIInputController

function UIInputController.new()
	local self = setmetatable({}, UIInputController)
	self._handlers = {} :: { [string]: { (...any) -> () } }
	-- Reverse lookup: KeyCode -> action id, built once from InputConfig.
	self._keyToAction = {} :: { [Enum.KeyCode]: string }
	self.ActionFired = UISignal.new()
	self:_BuildLookup()
	self:_Listen()
	return self
end

function UIInputController:_BuildLookup()
	for action, binding in InputConfig.Actions do
		for _, key in binding.keyboard do
			self._keyToAction[key] = action
		end
		for _, key in binding.gamepad do
			self._keyToAction[key] = action
		end
	end
end

function UIInputController:_Listen()
	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if processed then
			return
		end
		local action = self._keyToAction[input.KeyCode]
		if action then
			self:Fire(action)
		end
	end)
end

-- Bind a callback to an action id. Returns a { Disconnect } handle.
function UIInputController:BindAction(action: string, handler: (...any) -> ())
	local list = self._handlers[action]
	if not list then
		list = {}
		self._handlers[action] = list
	end
	table.insert(list, handler)
	return {
		Disconnect = function()
			local index = table.find(list, handler)
			if index then
				table.remove(list, index)
			end
		end,
	}
end

function UIInputController:Fire(action: string, ...)
	self.ActionFired:Fire(action, ...)
	local list = self._handlers[action]
	if list then
		for _, handler in table.clone(list) do
			task.spawn(handler, ...)
		end
	end
end

return UIInputController
