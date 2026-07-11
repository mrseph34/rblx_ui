--!strict
-- Overhead chat bubbles: a themed speech bubble that pops above a character's
-- head, types its text out, holds, then fades and self-destroys. This is the
-- ambient over-head chatter counterpart to the anchored NPCDialogScreen panel —
-- use it for barks, emotes, player chat, quest hints, mob taunts.
--
-- Usage (from a controller/handler with the theme controller):
--   local chat = UIChatBubbleController.new(themeController)
--   chat:Say(character, "Hello there!")            -- default duration
--   chat:Say(character, "...", { duration = 2, typeSpeed = 60, tail = true })
--
-- Multiple Say calls on one character stack: the newest replaces the visible
-- bubble (a real barks system rarely shows two at once over one head). Fully
-- theme-driven and re-skins live like every other piece.

local RunService = game:GetService("RunService")

local Types = require(script.Parent.Parent.Types)
local UIStyler = require(script.Parent.Parent.UIStyler)
local ThemeShape = require(script.Parent.Parent.ThemeShape)

local UIChatBubbleController = {}
UIChatBubbleController.__index = UIChatBubbleController

export type ChatBubbleController = typeof(setmetatable({} :: {
	_themeController: any,
	_active: { [Instance]: any },
}, UIChatBubbleController))

-- How high above the head the bubble floats, and its max width (px).
local OFFSET_Y = 3.4
local MAX_WIDTH = 260
local DEFAULT_DURATION = 3.5
local DEFAULT_TYPE_SPEED = 55

function UIChatBubbleController.new(themeController: any): ChatBubbleController
	local self = setmetatable({}, UIChatBubbleController)
	self._themeController = themeController
	self._active = {}
	if themeController and themeController.ThemeChanged then
		themeController.ThemeChanged:Connect(function()
			self:_RestyleAll()
		end)
	end
	return self :: any
end

local function adornPart(character: Instance): BasePart?
	if character:IsA("Model") then
		return (character:FindFirstChild("Head") :: BasePart?)
			or (character :: Model).PrimaryPart
			or (character:FindFirstChildWhichIsA("BasePart") :: BasePart?)
	end
	return character:IsA("BasePart") and character or nil
end

-- Show a bubble over `character`. Replaces any bubble already on that character.
function UIChatBubbleController:Say(character: Instance, text: string, opts: { duration: number?, typeSpeed: number?, tail: boolean? }?)
	local part = adornPart(character)
	if not part then
		return
	end
	-- Clear an existing bubble on this character (newest wins).
	self:_Clear(character)

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "ChatBubble"
	billboard.Adornee = part
	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	billboard.ResetOnSpawn = false
	billboard.StudsOffsetWorldSpace = Vector3.new(0, OFFSET_Y, 0)
	billboard.Size = UDim2.fromOffset(MAX_WIDTH, 90)
	billboard.SizeOffset = Vector2.new(0, 0.5)

	-- Bubble surface auto-sizes to the wrapped text.
	local bubble = UIStyler.Frame("Bubble")
	bubble.AnchorPoint = Vector2.new(0.5, 1)
	bubble.Position = UDim2.fromScale(0.5, 1)
	bubble.AutomaticSize = Enum.AutomaticSize.XY
	bubble.Size = UDim2.fromOffset(0, 0)
	bubble.Parent = billboard
	local corner = UIStyler.Corner(12)
	corner.Parent = bubble
	local stroke = UIStyler.Stroke(Color3.new(), 1.5)
	stroke.Parent = bubble
	UIStyler.PaddingXY(12, 8).Parent = bubble

	local label = UIStyler.TextLabel("Text")
	label.AutomaticSize = Enum.AutomaticSize.XY
	label.Size = UDim2.fromOffset(0, 0)
	label.TextWrapped = true
	label.RichText = false
	-- Cap width so long lines wrap instead of stretching off-screen.
	local sizeCap = Instance.new("UISizeConstraint")
	sizeCap.MaxSize = Vector2.new(MAX_WIDTH - 24, math.huge)
	sizeCap.Parent = label
	label.Parent = bubble

	-- Little tail pointing down at the head.
	local tail = UIStyler.TextLabel("Tail")
	tail.Size = UDim2.fromOffset(20, 14)
	tail.AnchorPoint = Vector2.new(0.5, 0)
	tail.Position = UDim2.fromScale(0.5, 1)
	tail.Text = "▼"
	tail.TextScaled = true
	tail.Visible = not (opts and opts.tail == false)
	tail.Parent = bubble

	billboard.Parent = part

	local entry = {
		billboard = billboard,
		bubble = bubble,
		corner = corner,
		stroke = stroke,
		label = label,
		tail = tail,
		fullText = text,
		typeToken = {},
	}
	self._active[character] = entry
	self:_StyleEntry(entry, self._themeController:GetTheme())

	-- Type it out (utf8-safe so emoji reveal cleanly), then hold + fade.
	local typeSpeed = (opts and opts.typeSpeed) or DEFAULT_TYPE_SPEED
	local duration = (opts and opts.duration) or DEFAULT_DURATION
	self:_TypeThenFade(character, entry, typeSpeed, duration)

	-- Auto-clean if the character leaves.
	character.AncestryChanged:Connect(function(_, parent)
		if not parent then
			self:_Clear(character)
		end
	end)
end

function UIChatBubbleController:_TypeThenFade(character: Instance, entry: any, speed: number, duration: number)
	local token = {}
	entry.typeToken = token
	local full = entry.fullText
	entry.label.Text = ""
	task.spawn(function()
		local acc = 0
		local shown = 0
		while shown < #full and entry.typeToken == token and entry.billboard.Parent do
			local dt = RunService.Heartbeat:Wait()
			acc += dt * speed
			local target = math.min(#full, math.floor(acc))
			if target > shown then
				shown = target
				local byteEnd = (utf8.offset(full, shown + 1) or (#full + 1)) - 1
				entry.label.Text = string.sub(full, 1, byteEnd)
			end
		end
		if entry.typeToken ~= token then
			return
		end
		entry.label.Text = full
		-- Hold, then fade out and clear.
		task.wait(duration)
		if entry.typeToken ~= token or not entry.billboard.Parent then
			return
		end
		local theme = self._themeController:GetTheme()
		local info = theme.Animations.Disappear
		for _, obj in { entry.bubble, entry.tail } do
			UIStyler.Tween(obj, info, { BackgroundTransparency = 1 })
		end
		UIStyler.Tween(entry.label, info, { TextTransparency = 1 })
		UIStyler.Tween(entry.stroke, info, { Transparency = 1 })
		task.wait(info.Time)
		if self._active[character] == entry then
			self:_Clear(character)
		end
	end)
end

function UIChatBubbleController:_Clear(character: Instance)
	local entry = self._active[character]
	if not entry then
		return
	end
	entry.typeToken = {}
	entry.billboard:Destroy()
	self._active[character] = nil
end

function UIChatBubbleController:_RestyleAll()
	local theme = self._themeController:GetTheme()
	for _, entry in self._active do
		self:_StyleEntry(entry, theme)
	end
end

function UIChatBubbleController:_StyleEntry(entry: any, theme: Types.UITheme)
	local c = theme.Colors
	local radius = ThemeShape.Radius(theme, theme.Radii.Large)
	entry.bubble.BackgroundColor3 = c.SurfaceRaised
	entry.corner.CornerRadius = UDim.new(0, radius)
	entry.stroke.Color = c.Stroke
	entry.stroke.Thickness = theme.Effects.StrokeThickness
	entry.stroke.Transparency = 0.2
	entry.label.FontFace = theme.Fonts.Body
	entry.label.TextSize = theme.TextSizes.Body
	entry.label.TextColor3 = c.TextPrimary
	-- Same LegacyArial bug as the button icon fix: never assigning FontFace left
	-- this glyph (▼) on the emoji/symbol-incapable engine default.
	entry.tail.FontFace = theme.Fonts.Body
	entry.tail.TextColor3 = c.SurfaceRaised
end

return UIChatBubbleController
