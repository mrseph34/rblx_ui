--!strict
-- Index (collection browse) screen. A bar-for-bar reproduction of the reference
-- "collection" layout — category header over a scrollable 5-column tile grid
-- (unlocked / locked) with a fixed progress-bar + count footer.
--
-- Like the boxy shop list row, this deliberately does NOT theme: the whole
-- surface is rendered through the EXACT reference primitive (Reference/RefIndex,
-- which builds a RefSkin.Modal) with the reference's own hardcoded colours,
-- sizes, positions, text sizes and outline thicknesses. This screen just hosts
-- that reproduction and wires its close button to navigation. It's a browse
-- screen, so there's no live-data wiring beyond rendering.

local UIScreenBase = require(script.Parent.UIScreenBase)
local RefIndex = require(script.Parent.Parent.Reference.RefIndex)

local IndexScreen = setmetatable({}, { __index = UIScreenBase })
IndexScreen.__index = IndexScreen

function IndexScreen.new()
	local self = UIScreenBase.new("IndexScreen", 6)
	return setmetatable(self, IndexScreen)
end

function IndexScreen:_BuildContent()
	-- Render the reference collection modal directly into Root, exactly as the
	-- RefPreview harness does — same values, same look. RefIndex.build returns the
	-- RefSkin.Modal { root, header, body, close }.
	local modal = RefIndex.build(self.Root)
	self._modal = modal

	-- Wire the reference's own close (the red X in the header) to navigation.
	-- RefIndex.build does not pass onClose, so the returned close button is unbound
	-- until we connect it here.
	modal.close.Activated:Connect(function()
		self.ScreenController:HideScreen("index")
	end)
end

return IndexScreen
