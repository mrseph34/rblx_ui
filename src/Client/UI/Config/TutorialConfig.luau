--!strict
-- Step-based onboarding data. Each step references text keys and, optionally, a
-- highlightTargetId that maps to a registered highlight anchor (see
-- UIScreenController:RegisterHighlightTarget). TutorialScreen walks this list.

local Types = require(script.Parent.Parent.Types)

local TutorialConfig = {}

TutorialConfig.Steps = {
	{
		id = "welcome",
		titleKey = "tutorial.welcome.title",
		textKey = "tutorial.welcome.text",
		highlightTargetId = "hud.topRight",
	},
	{
		id = "shop",
		titleKey = "tutorial.shop.title",
		textKey = "tutorial.shop.text",
		highlightTargetId = "nav.shop",
		hintKeys = { "tutorial.hint.tap" },
		-- Nav rail buttons are icon-square, so a Circle callout (with an arrow
		-- pointing up at it from the popup below) reads better than the
		-- default RoundedSquare rectangle.
		highlightShape = "Circle",
		highlightArrowDirection = "Up",
	},
	{
		id = "themes",
		titleKey = "tutorial.themes.title",
		textKey = "tutorial.themes.text",
		highlightTargetId = "nav.theme",
		highlightShape = "Circle",
		highlightArrowDirection = "Up",
	},
} :: { Types.TutorialStep }

return TutorialConfig
