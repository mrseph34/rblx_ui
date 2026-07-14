--!strict
-- NPC dialogue box with a typewriter reveal. Renders a bottom-anchored themed
-- panel: portrait swatch, speaker name, and body text that types out at the
-- line's speed. Click while typing to reveal the whole line instantly; click a
-- finished line to advance. The last line may show choice buttons.
--
-- Fully theme-driven like every screen, so it matches whatever theme/style is
-- active. Drive it with Show({ sequenceId = "welcome_merchant" }) or a raw
-- sequence table; choices fire onChoice(id).

local RunService = game:GetService("RunService")

local UIStyler = require(script.Parent.Parent.UIStyler)
local TextConfig = require(script.Parent.Parent.Config.TextConfig)
local NPCDialogConfig = require(script.Parent.Parent.Config.NPCDialogConfig)
local UIScreenBase = require(script.Parent.UIScreenBase)
local UIPanelComponent = require(script.Parent.Parent.Components.UIPanelComponent)
local UIButtonComponent = require(script.Parent.Parent.Components.UIButtonComponent)

local NPCDialogScreen = setmetatable({}, { __index = UIScreenBase })
NPCDialogScreen.__index = NPCDialogScreen

function NPCDialogScreen.new()
	local self = UIScreenBase.new("NPCDialogScreen", 16)
	self._lines = {}
	self._index = 1
	self._typing = false
	self._choiceButtons = {}
	self._onChoice = nil :: ((string) -> ())?
	self._defaultSpeed = 45
	return setmetatable(self, NPCDialogScreen)
end

function NPCDialogScreen:_BuildContent()
	-- The AspectRatioConstraint lives on the PANEL, not Root — see
	-- ShopScreen's note for the full explanation. 0.5/0.26*1.89 reproduces
	-- the panel's own previous effective shape (0.5 x 0.26 of a 1.89-locked
	-- Root) exactly, just correctly anchored now instead of dragged
	-- top-left (this panel isn't screen-centered — position is 0.5, 0.82 —
	-- but Root's own shrink-to-top-left still dragged that anchor point off
	-- the true screen's bottom-center).
	local panel = UIPanelComponent.new()
	self._panel = panel
	self:_SetAnimatedPanel(panel)
	panel:Create(self.Root, {
		title = "",
		showClose = true,
		size = UDim2.fromScale(0.5, 0.26),
		position = UDim2.fromScale(0.5, 0.82),
		onClose = function()
			self:_Finish(nil)
		end,
	})
	local panelAspect = UIStyler.AspectRatio(0.5 / 0.26 * 1.89, Enum.DominantAxis.Width)
	panelAspect.Parent = panel.Root

	-- Portrait swatch (left) — a perfect square (AspectRatioConstraint 1:1,
	-- DominantAxis Height) instead of a fixed pixel Offset. Starting size is
	-- non-zero on both axes (never Scale=0) — an AspectRatioConstraint
	-- driving a Scale=0 starting dimension collapses to 0x0 instead of
	-- resolving correctly.
	local portrait = UIStyler.Frame("Portrait")
	portrait.Size = UDim2.fromScale(0.16, 0.6)
	portrait.Position = UDim2.fromScale(0.02, 0.05)
	UIStyler.AspectRatio(1, Enum.DominantAxis.Height).Parent = portrait
	UIStyler.Corner(12).Parent = portrait
	self._portraitInitial = UIStyler.TextLabel("Initial")
	self._portraitInitial.Size = UDim2.fromScale(1, 1)
	self._portraitInitial.TextScaled = true
	self._portraitInitial.TextColor3 = Color3.new(1, 1, 1)
	UIStyler.PaddingScale(0.2).Parent = self._portraitInitial
	self._portraitInitial.Parent = portrait
	portrait.Parent = panel.Body
	self._portrait = portrait

	-- Speaker name — Scale fractions of panel.Body, starting right of the
	-- portrait (0.205 = portrait's 0.02 margin + 0.16 width + a small gap).
	local speaker = UIStyler.TextLabel("Speaker")
	speaker.Size = UDim2.fromScale(0.775, 0.14)
	speaker.Position = UDim2.fromScale(0.205, 0.04)
	speaker.TextXAlignment = Enum.TextXAlignment.Left
	speaker.TextScaled = true
	self._speakerConstraint = UIStyler.TextSizeConstraint(22, 11)
	self._speakerConstraint.Parent = speaker
	speaker.Parent = panel.Body
	self._speaker = speaker

	-- Body text (typewriter target).
	local body = UIStyler.TextLabel("Body")
	body.Size = UDim2.fromScale(0.775, 0.62)
	body.Position = UDim2.fromScale(0.205, 0.18)
	body.TextXAlignment = Enum.TextXAlignment.Left
	body.TextYAlignment = Enum.TextYAlignment.Top
	body.TextWrapped = true
	body.RichText = false
	body.TextScaled = true
	self._bodyConstraint = UIStyler.TextSizeConstraint(18, 9)
	self._bodyConstraint.Parent = body
	body.Parent = panel.Body
	self._body = body

	-- Continue hint / click catcher over the whole panel body.
	local clickCatcher = Instance.new("TextButton")
	clickCatcher.Name = "Advance"
	clickCatcher.Text = ""
	clickCatcher.BackgroundTransparency = 1
	clickCatcher.Size = UDim2.fromScale(1, 1)
	clickCatcher.ZIndex = 3
	clickCatcher.Parent = panel.Body
	clickCatcher.Activated:Connect(function()
		self:_OnClick()
	end)
	self._clickCatcher = clickCatcher

	-- Continue indicator (bottom-right).
	local cont = UIStyler.TextLabel("Continue")
	cont.Size = UDim2.fromScale(0.26, 0.12)
	cont.AnchorPoint = Vector2.new(1, 1)
	cont.Position = UDim2.fromScale(0.98, 0.96)
	cont.TextXAlignment = Enum.TextXAlignment.Right
	cont.TextScaled = true
	self._continueConstraint = UIStyler.TextSizeConstraint(16, 8)
	self._continueConstraint.Parent = cont
	cont.Text = "click to continue ▶"
	cont.ZIndex = 4
	cont.Parent = panel.Body
	self._continue = cont

	-- Choice row (hidden until the final line offers choices).
	local choices = UIStyler.Frame("Choices")
	choices.BackgroundTransparency = 1
	choices.Size = UDim2.fromScale(0.775, 0.2)
	choices.AnchorPoint = Vector2.new(0, 1)
	choices.Position = UDim2.fromScale(0.205, 0.96)
	choices.Visible = false
	choices.ZIndex = 5
	UIStyler.ListLayout({
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Left,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 8),
	}).Parent = choices
	choices.Parent = panel.Body
	self._choices = choices
end

-- ---- typewriter -------------------------------------------------------

function NPCDialogScreen:_TypeLine(line: any)
	local fullText = TextConfig.Resolve(line.textKey)
	self._fullText = fullText
	self._typing = true
	self._body.Text = ""
	self._continue.Visible = false
	self._choices.Visible = false

	local speed = line.typeSpeed or self._defaultSpeed
	task.spawn(function()
		local shown = 0
		local acc = 0
		local token = {}
		self._typeToken = token
		while shown < #fullText and self._typing and self._typeToken == token do
			local dt = RunService.Heartbeat:Wait()
			acc += dt * speed
			local target = math.min(#fullText, math.floor(acc))
			if target > shown then
				shown = target
				-- utf8.offset keeps multi-byte glyphs (emoji) intact while typing.
				local byteEnd = (utf8.offset(fullText, shown + 1) or (#fullText + 1)) - 1
				self._body.Text = string.sub(fullText, 1, byteEnd)
			end
		end
		if self._typeToken == token then
			self:_FinishTyping()
		end
	end)
end

function NPCDialogScreen:_FinishTyping()
	self._typing = false
	self._body.Text = self._fullText
	local line = self._lines[self._index]
	if line and line.choices then
		self:_ShowChoices(line.choices)
	else
		self._continue.Visible = true
	end
end

function NPCDialogScreen:_OnClick()
	if self._typing then
		-- Skip to the full line.
		self._typeToken = {}
		self:_FinishTyping()
	elseif not self._choices.Visible then
		self:_Advance()
	end
end

function NPCDialogScreen:_Advance()
	self._index += 1
	local line = self._lines[self._index]
	if line then
		self:_RenderLine(line)
	else
		self:_Finish(nil)
	end
end

-- ---- rendering --------------------------------------------------------

function NPCDialogScreen:_RenderLine(line: any)
	local theme = self:GetTheme()
	self._portrait.BackgroundColor3 = line.portraitColor or theme.Colors.Primary
	self._speaker.Text = TextConfig.Resolve(line.speakerKey)
	self._speaker.FontFace = theme.Fonts.Title
	self._speakerConstraint.MaxTextSize = theme.TextSizes.Subtitle
	self._speaker.TextColor3 = theme.Colors.Accent
	self._portraitInitial.Text = string.upper(string.sub(TextConfig.Resolve(line.speakerKey), 1, 1))
	self._body.FontFace = theme.Fonts.Body
	self._bodyConstraint.MaxTextSize = theme.TextSizes.Body
	-- Dark text on the LIGHT dialog body (never white on a light background).
	self._body.TextColor3 = theme.Colors.Stroke
	self._continue.FontFace = theme.Fonts.Body
	self._continueConstraint.MaxTextSize = theme.TextSizes.Small
	self._continue.TextColor3 = theme.Colors.Stroke
	-- These four labels are parented into panel.Body after the panel's ApplyTheme
	-- ran, so the global outline pass missed them — outline them each render.
	UIStyler.ApplyThemeOutline(self._portraitInitial, theme.TextOutline)
	UIStyler.ApplyThemeOutline(self._speaker, theme.TextOutline)
	UIStyler.ApplyThemeOutline(self._body, theme.TextOutline)
	UIStyler.ApplyThemeOutline(self._continue, theme.TextOutline)
	self:_TypeLine(line)
end

function NPCDialogScreen:_ShowChoices(choices: any)
	for _, b in self._choiceButtons do
		b:Destroy()
	end
	table.clear(self._choiceButtons)
	self._continue.Visible = false
	self._choices.Visible = true
	for i, choice in choices do
		local button = UIButtonComponent.new()
		button:Create(self._choices, {
			textKey = choice.textKey,
			variant = i == 1 and "Primary" or "Ghost",
			size = UDim2.fromScale(0.42, 1),
			layoutOrder = i,
			onClick = function()
				self:_Finish(choice.id)
			end,
		})
		table.insert(self._choiceButtons, button)
	end
end

function NPCDialogScreen:_Finish(choiceId: string?)
	self._typing = false
	self._typeToken = {}
	self.ScreenController:HideScreen("npcDialog")
	if self._onChoice then
		self._onChoice(choiceId or "closed")
	end
end

function NPCDialogScreen:_OnShow(data: any?)
	local sequence
	if data and data.lines then
		sequence = data
	elseif data and data.sequenceId then
		sequence = NPCDialogConfig.Get(data.sequenceId)
	else
		sequence = NPCDialogConfig.Get("welcome_merchant")
	end
	self._lines = sequence.lines
	self._defaultSpeed = sequence.defaultTypeSpeed or 45
	self._onChoice = data and data.onChoice or nil
	self._index = 1
	-- Intro is driven centrally by UIScreenBase:Show (active animation pack).
	self:_RenderLine(self._lines[1])
end

function NPCDialogScreen:_OnHide()
	self._typing = false
	self._typeToken = {}
end

return NPCDialogScreen
