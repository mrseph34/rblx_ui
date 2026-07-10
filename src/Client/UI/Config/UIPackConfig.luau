--!strict
-- Layout packs: named bundles of layout choices (shop grid vs list, compact vs
-- large HUD, ...) that are orthogonal to themes. A theme sets how things look;
-- a pack sets how they're arranged. Screens read the active pack to decide
-- structure. Add a pack by appending here.

local Types = require(script.Parent.Parent.Types)

local UIPackConfig = {}

UIPackConfig.DefaultPackId = "Standard"

UIPackConfig.Packs = {
	{
		Id = "Standard",
		DisplayName = "Standard",
		Shop = { Layout = "Grid", Columns = 3, CardHeight = 190, ShowCategoryBar = true },
		HUD = { Compact = false, ShowObjectives = true, Scale = 1 },
		Tutorial = { ShowStepList = true },
		Modal = { WidthScale = 0.42 },
	},
	{
		Id = "Compact",
		DisplayName = "Compact / Streamer",
		Shop = { Layout = "List", Columns = 1, CardHeight = 84, ShowCategoryBar = true },
		HUD = { Compact = true, ShowObjectives = false, Scale = 0.85 },
		Tutorial = { ShowStepList = false },
		Modal = { WidthScale = 0.36 },
	},
	{
		Id = "Premium",
		DisplayName = "Premium / Large",
		Shop = { Layout = "Grid", Columns = 2, CardHeight = 230, ShowCategoryBar = true },
		HUD = { Compact = false, ShowObjectives = true, Scale = 1.1 },
		Tutorial = { ShowStepList = true },
		Modal = { WidthScale = 0.5 },
	},
} :: { Types.UIPack }

function UIPackConfig.GetById(id: string): Types.UIPack?
	for _, pack in UIPackConfig.Packs do
		if pack.Id == id then
			return pack
		end
	end
	return nil
end

return UIPackConfig
