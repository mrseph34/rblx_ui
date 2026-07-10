--!strict
-- Cross-platform input bindings. Actions are abstract ("ToggleShop"); this maps
-- each to keyboard keys and gamepad buttons. UIInputController consumes it so
-- screens never hardcode a KeyCode. Add a binding here to wire a new hotkey.

local InputConfig = {}

export type ActionBinding = {
	keyboard: { Enum.KeyCode },
	gamepad: { Enum.KeyCode },
}

InputConfig.Actions = {
	ToggleShop = { keyboard = { Enum.KeyCode.B }, gamepad = { Enum.KeyCode.ButtonY } },
	ToggleThemeEditor = { keyboard = { Enum.KeyCode.T }, gamepad = { Enum.KeyCode.ButtonSelect } },
	ToggleHUD = { keyboard = { Enum.KeyCode.H }, gamepad = {} },
	CloseTop = { keyboard = { Enum.KeyCode.Escape }, gamepad = { Enum.KeyCode.ButtonB } },
	AdvanceTutorial = { keyboard = { Enum.KeyCode.E }, gamepad = { Enum.KeyCode.ButtonA } },
} :: { [string]: ActionBinding }

return InputConfig
