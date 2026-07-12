--!strict
-- Bottom-of-screen speech bar — the on-screen (UI) counterpart to the overhead
-- chat bubble. A slim themed bar pinned to the bottom that types out a line with
-- an optional speaker name, then auto-hides. Use it for narration, subtitles,
-- radio chatter, quest voice-over — anything that reads as "someone is talking"
-- without the full NPCDialogScreen panel or an above-head bubble.
--
-- Show({ speaker = "Radio", text = "...", duration = 4, typeSpeed = 50 }) or feed
-- a queue of lines; each types, holds, then the next plays. Fully themed.

local RunService = game:GetService("RunService")

local UIStyler = require(script.Parent.Parent.UIStyler)
local ThemeShape = require(script.Parent.Parent.ThemeShape)
local UIScreenBase = require(script.Parent.UIScreenBase)

local ChatBarScreen = setmetatable({}, { __index = UIScreenBase })
ChatBarScreen.__index = ChatBarScreen

function ChatBarScreen.new()
	local self = UIScreenBase.new("ChatBarScreen", 15)
	self._queue = {}
	self._typing = false
	self._typeToken = {}
	return setmetatable(self, ChatBarScreen)
end

function ChatBarScreen:_BuildContent()
	-- Bar pinned near the bottom, centred — pure Scale fractions of Root
	-- (never a fixed pixel Offset), a thin wide strip rather than an
	-- aspect-locked shaped panel.
	local bar = UIStyler.Frame("Bar")
	bar.AnchorPoint = Vector2.new(0.5, 1)
	bar.Position = UDim2.fromScale(0.5, 0.92)
	bar.Size = UDim2.fromScale(0.6, 0.16)
	bar.Parent = self.Root
	self._bar = bar
	self._corner = UIStyler.Corner(14)
	self._corner.Parent = bar
	self._stroke = UIStyler.Stroke(Color3.new(), 1.5)
	self._stroke.Parent = bar
	UIStyler.PaddingScale(0.08).Parent = bar

	-- Speaker chip (top-left, hidden when no speaker).
	local speaker = UIStyler.TextLabel("Speaker")
	speaker.Size = UDim2.fromScale(1, 0.26)
	speaker.TextXAlignment = Enum.TextXAlignment.Left
	speaker.TextScaled = true
	self._speakerConstraint = UIStyler.TextSizeConstraint(16, 8)
	self._speakerConstraint.Parent = speaker
	speaker.Parent = bar
	self._speaker = speaker

	-- Body (typewriter target).
	local body = UIStyler.TextLabel("Body")
	body.Size = UDim2.fromScale(1, 0.68)
	body.Position = UDim2.fromScale(0, 0.3)
	body.TextXAlignment = Enum.TextXAlignment.Left
	body.TextYAlignment = Enum.TextYAlignment.Top
	body.TextWrapped = true
	body.RichText = false
	body.TextScaled = true
	self._bodyConstraint = UIStyler.TextSizeConstraint(18, 9)
	self._bodyConstraint.Parent = body
	body.Parent = bar
	self._body = body

	-- Click anywhere on the bar skips the type / advances.
	local hit = Instance.new("TextButton")
	hit.Name = "Advance"
	hit.Text = ""
	hit.BackgroundTransparency = 1
	hit.Size = UDim2.fromScale(1, 1)
	hit.ZIndex = 3
	hit.Parent = bar
	hit.Activated:Connect(function()
		self:_OnClick()
	end)
end

-- Public: show a single line or queue several. `data.lines` = { {speaker,text,...} }.
function ChatBarScreen:Show(data: any?)
	UIScreenBase.Show(self, data)
end

function ChatBarScreen:_OnShow(data: any?)
	self._queue = {}
	if data and data.lines then
		for _, l in data.lines do
			table.insert(self._queue, l)
		end
	elseif data then
		table.insert(self._queue, data)
	end
	self:_Repaint()
	self:_Next()
end

function ChatBarScreen:_Next()
	local line = table.remove(self._queue, 1)
	if not line then
		self.ScreenController:HideScreen("chatBar")
		return
	end
	self._current = line
	self._speaker.Text = line.speaker or ""
	self._speaker.Visible = (line.speaker ~= nil and line.speaker ~= "")
	self:_TypeLine(line)
end

function ChatBarScreen:_TypeLine(line: any)
	local full = line.text or ""
	self._fullText = full
	self._typing = true
	self._body.Text = ""
	local token = {}
	self._typeToken = token
	local speed = line.typeSpeed or 50
	local duration = line.duration or 3.5
	task.spawn(function()
		local acc, shown = 0, 0
		while shown < #full and self._typing and self._typeToken == token do
			local dt = RunService.Heartbeat:Wait()
			acc += dt * speed
			local target = math.min(#full, math.floor(acc))
			if target > shown then
				shown = target
				local byteEnd = (utf8.offset(full, shown + 1) or (#full + 1)) - 1
				self._body.Text = string.sub(full, 1, byteEnd)
			end
		end
		if self._typeToken ~= token then
			return
		end
		self._typing = false
		self._body.Text = full
		-- Auto-advance after holding, unless another click already advanced.
		task.wait(duration)
		if self._typeToken == token then
			self:_Next()
		end
	end)
end

function ChatBarScreen:_OnClick()
	if self._typing then
		-- Reveal the whole line instantly.
		self._typeToken = {}
		self._typing = false
		self._body.Text = self._fullText
		task.delay(self._current and self._current.duration or 3.5, function()
			-- no-op; a subsequent click advances
		end)
	else
		self._typeToken = {}
		self:_Next()
	end
end

function ChatBarScreen:_Repaint()
	local theme = self:GetTheme()
	local c = theme.Colors
	self._bar.BackgroundColor3 = c.SurfaceRaised
	self._corner.CornerRadius = UDim.new(0, ThemeShape.Radius(theme, theme.Radii.Large))
	self._stroke.Color = c.Stroke
	self._stroke.Thickness = theme.Effects.StrokeThickness
	self._stroke.Transparency = 0.2
	self._speaker.FontFace = theme.Fonts.Title
	self._speakerConstraint.MaxTextSize = theme.TextSizes.Small
	self._speaker.TextColor3 = c.Accent
	self._body.FontFace = theme.Fonts.Body
	self._bodyConstraint.MaxTextSize = theme.TextSizes.Body
	self._body.TextColor3 = c.TextPrimary
end

function ChatBarScreen:_OnHide()
	self._typing = false
	self._typeToken = {}
end

return ChatBarScreen
