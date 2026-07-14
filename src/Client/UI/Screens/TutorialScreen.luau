--!strict
-- Step-based onboarding. Walks TutorialConfig steps, showing a popup per step
-- and a spotlight (dimmed overlay with a cut-out) over the step's highlight
-- target when one is registered with UIScreenController. Advancing is driven by
-- the popup button or the AdvanceTutorial input action.

local UIStyler = require(script.Parent.Parent.UIStyler)
local TextConfig = require(script.Parent.Parent.Config.TextConfig)
local TutorialConfig = require(script.Parent.Parent.Config.TutorialConfig)
local UIScreenBase = require(script.Parent.UIScreenBase)
local UIPanelComponent = require(script.Parent.Parent.Components.UIPanelComponent)
local UIButtonComponent = require(script.Parent.Parent.Components.UIButtonComponent)
local UIHighlightComponent = require(script.Parent.Parent.Components.UIHighlightComponent)

local TutorialScreen = setmetatable({}, { __index = UIScreenBase })
TutorialScreen.__index = TutorialScreen

function TutorialScreen.new()
	local self = UIScreenBase.new("TutorialScreen", 15)
	self._steps = TutorialConfig.Steps
	self._index = 1
	self._onComplete = nil :: ((boolean) -> ())?
	return setmetatable(self, TutorialScreen)
end

function TutorialScreen:_BuildContent()
	-- No Root-level AspectRatioConstraint here (unlike ShopScreen's pattern):
	-- the dim overlay below must cover the TRUE viewport, not a
	-- design-locked box — Root has AnchorPoint (0,0), so constraining it
	-- would shrink it flush to the top-left and leave part of the real
	-- screen undimmed. The popup panel below carries its own
	-- AspectRatioConstraint instead.

	-- Dim overlay (four frames forming a border around a highlight hole; here
	-- simplified to one translucent frame that we punch visually with a ring).
	local dim = UIStyler.Frame("Dim")
	dim.BackgroundColor3 = Color3.new(0, 0, 0)
	dim.BackgroundTransparency = 0.45
	dim.Parent = self.Root
	self._dim = dim

	-- Highlight that tracks the current step's target — see
	-- UIHighlightComponent for why this replaced a one-off ring built inline
	-- here (that version snapshotted the target's position once per step and
	-- never updated again, so it visibly drifted off target on any viewport
	-- resize or target reflow).
	local highlight = UIHighlightComponent.new()
	highlight:Create(self.Root, { shape = "RoundedSquare" })
	self._highlight = highlight

	-- Popup panel (bottom center).
	local panel = UIPanelComponent.new()
	self._panel = panel
	self:_SetAnimatedPanel(panel)
	panel:Create(self.Root, {
		title = "",
		showClose = true,
		size = UDim2.fromScale(0.42, 0.26),
		position = UDim2.fromScale(0.5, 0.8),
		onClose = function()
			self:_Finish(false)
		end,
	})
	-- 0.42/0.26*1.89 reproduces the panel's own previous effective shape
	-- exactly (it used to be 0.42 x 0.26 of a 1.89-locked Root), just
	-- correctly anchored now instead of dragged top-left.
	local panelAspect = UIStyler.AspectRatio(0.42 / 0.26 * 1.89, Enum.DominantAxis.Width)
	panelAspect.Parent = panel.Root

	local text = UIStyler.TextLabel("Text")
	text.Size = UDim2.fromScale(0.92, 0.66)
	text.Position = UDim2.fromScale(0.04, 0.04)
	text.TextWrapped = true
	text.TextYAlignment = Enum.TextYAlignment.Top
	text.TextXAlignment = Enum.TextXAlignment.Left
	text.TextScaled = true
	self._textConstraint = UIStyler.TextSizeConstraint(20, 10)
	self._textConstraint.Parent = text
	text.Parent = panel.Body
	self._text = text

	self._progress = UIStyler.TextLabel("Progress")
	self._progress.Size = UDim2.fromScale(0.26, 0.14)
	self._progress.AnchorPoint = Vector2.new(0, 1)
	self._progress.Position = UDim2.fromScale(0.04, 0.94)
	self._progress.TextXAlignment = Enum.TextXAlignment.Left
	self._progress.TextScaled = true
	self._progressConstraint = UIStyler.TextSizeConstraint(18, 9)
	self._progressConstraint.Parent = self._progress
	self._progress.Parent = panel.Body

	self._nextButton = UIButtonComponent.new()
	self._nextButton:Create(panel.Body, {
		text = "Next",
		variant = "Primary",
		size = UDim2.fromScale(0.4, 0.19),
		anchorPoint = Vector2.new(1, 1),
		position = UDim2.fromScale(0.96, 0.94),
		onClick = function()
			self:Advance()
		end,
	})
end

function TutorialScreen:_ShowStep()
	local step = self._steps[self._index]
	if not step then
		self:_Finish(true)
		return
	end
	local theme = self:GetTheme()
	self._panel._title.Text = TextConfig.Resolve(step.titleKey)
	local body = TextConfig.Resolve(step.textKey)
	if step.hintKeys then
		for _, hintKey in step.hintKeys do
			body ..= "\n\n<i>" .. TextConfig.Resolve(hintKey) .. "</i>"
		end
	end
	self._text.Text = body
	self._text.FontFace = theme.Fonts.Body
	self._textConstraint.MaxTextSize = theme.TextSizes.Body
	-- Dark text on the LIGHT tutorial body (never white on a light background).
	self._text.TextColor3 = theme.Colors.Stroke
	self._progress.Text = string.format("%d / %d", self._index, #self._steps)
	self._progress.FontFace = theme.Fonts.Numeric
	self._progressConstraint.MaxTextSize = theme.TextSizes.Small
	self._progress.TextColor3 = theme.Colors.Stroke

	local isLast = self._index >= #self._steps
	self._nextButton:SetContent({ text = isLast and TextConfig.Resolve("modal.ok") or "Next →" })

	self:_UpdateHighlight(step)
	-- Intro is driven centrally by UIScreenBase:Show (active animation pack).
end

-- Restyle the highlight for this step (shape/arrow, per-step overrides — see
-- TutorialConfig) and point it at the step's registered target, if any.
-- UIHighlightComponent:Track keeps itself correctly positioned from here on,
-- including across viewport resizes — no per-step position math needed.
function TutorialScreen:_UpdateHighlight(step: any)
	self._highlight:SetContent({
		shape = step.highlightShape or "RoundedSquare",
		showArrow = step.highlightArrowDirection ~= nil,
		arrowDirection = step.highlightArrowDirection,
	})
	local target = step.highlightTargetId and self.ScreenController:GetHighlightTarget(step.highlightTargetId)
	self._highlight:Track(target)
end

function TutorialScreen:Advance()
	self._index += 1
	if self._index > #self._steps then
		self:_Finish(true)
	else
		self:_ShowStep()
	end
end

function TutorialScreen:_Finish(completed: boolean)
	self.ScreenController:HideScreen("tutorial")
	if self._onComplete then
		self._onComplete(completed)
	end
end

function TutorialScreen:_OnShow(data: any?)
	if data and data.steps then
		self._steps = data.steps
	end
	if data and data.onComplete then
		self._onComplete = data.onComplete
	end
	self._index = 1
	self:_ShowStep()
end

return TutorialScreen
