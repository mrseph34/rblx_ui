--!strict
-- Generic confirm/cancel/info dialog host. One instance serves all modals; the
-- controller shows it with ModalData describing the current dialog. Dims the
-- screen, animates a panel in, wires confirm/cancel to callbacks.

local UIStyler = require(script.Parent.Parent.UIStyler)
local TextConfig = require(script.Parent.Parent.Config.TextConfig)
local UIScreenBase = require(script.Parent.UIScreenBase)
local UIPanelComponent = require(script.Parent.Parent.Components.UIPanelComponent)
local UIButtonComponent = require(script.Parent.Parent.Components.UIButtonComponent)

local ModalScreen = setmetatable({}, { __index = UIScreenBase })
ModalScreen.__index = ModalScreen

function ModalScreen.new()
	local self = UIScreenBase.new("ModalScreen", 20)
	self._data = nil :: any
	return setmetatable(self, ModalScreen)
end

function ModalScreen:_BuildContent()
	-- No Root-level AspectRatioConstraint here (unlike ShopScreen's pattern):
	-- the backdrop below is a full-screen click-catcher that must cover the
	-- TRUE viewport, not a design-locked box — Root has AnchorPoint (0,0), so
	-- constraining it would shrink it flush to the top-left and leave part of
	-- the real screen unprotected (clicks would pass through outside the
	-- shrunk box). The panel below carries its own AspectRatioConstraint
	-- instead, computed from the active pack's WidthScale.

	-- Invisible click-catcher, not a dim overlay — blocks clicks from passing
	-- through to whatever's behind the modal (the actual reason this exists),
	-- without the visible black tint the other screens' backdrops had (removed
	-- there entirely as unneeded).
	local backdrop = Instance.new("TextButton")
	backdrop.Name = "Backdrop"
	backdrop.Text = ""
	backdrop.AutoButtonColor = false
	backdrop.Size = UDim2.fromScale(1, 1)
	backdrop.BackgroundTransparency = 1
	backdrop.Parent = self.Root
	self._backdrop = backdrop

	local pack = self.ThemeController:GetPack()
	local panel = UIPanelComponent.new()
	self._panel = panel
	self:_SetAnimatedPanel(panel)
	panel:Create(self.Root, {
		title = "",
		showClose = false,
		size = UDim2.fromScale(pack.Modal.WidthScale, 0.34),
	})
	-- pack.Modal.WidthScale/0.34*1.89 reproduces the panel's own previous
	-- effective shape exactly (it used to be WidthScale x 0.34 of a
	-- 1.89-locked Root), just correctly centered now.
	local panelAspect = UIStyler.AspectRatio(pack.Modal.WidthScale / 0.34 * 1.89, Enum.DominantAxis.Width)
	panelAspect.Parent = panel.Root

	local body = UIStyler.TextLabel("Body")
	body.Size = UDim2.fromScale(0.92, 0.72)
	body.Position = UDim2.fromScale(0.04, 0.04)
	body.TextWrapped = true
	body.TextYAlignment = Enum.TextYAlignment.Top
	body.TextScaled = true
	self._bodyConstraint = UIStyler.TextSizeConstraint(20, 10)
	self._bodyConstraint.Parent = body
	-- Dialogs may pass styled bodies (colored item lists, bold totals).
	body.RichText = true
	body.Parent = panel.Body
	self._body = body

	local buttonRow = UIStyler.Frame("Buttons")
	buttonRow.BackgroundTransparency = 1
	buttonRow.Size = UDim2.fromScale(0.92, 0.19)
	buttonRow.AnchorPoint = Vector2.new(0.5, 1)
	buttonRow.Position = UDim2.fromScale(0.5, 0.94)
	UIStyler.ListLayout({
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 10),
	}).Parent = buttonRow
	buttonRow.Parent = panel.Body

	self._cancelButton = UIButtonComponent.new()
	self._cancelButton:Create(buttonRow, {
		textKey = "modal.cancel",
		variant = "Ghost",
		size = UDim2.fromScale(0.34, 1),
		layoutOrder = 1,
		onClick = function()
			self:_Close(false)
		end,
	})

	self._confirmButton = UIButtonComponent.new()
	self._confirmButton:Create(buttonRow, {
		textKey = "modal.confirm",
		variant = "Primary",
		size = UDim2.fromScale(0.4, 1),
		layoutOrder = 2,
		onClick = function()
			self:_Close(true)
		end,
	})
end

function ModalScreen:_Close(confirmed: boolean)
	local data = self._data
	self.ScreenController:HideModal()
	if data then
		if confirmed and data.onConfirm then
			data.onConfirm()
		elseif not confirmed and data.onCancel then
			data.onCancel()
		end
	end
end

function ModalScreen:_OnShow(data: any?)
	self._data = data
	if not data then
		return
	end
	local isInfo = data.kind == "Info"
	self._panel._title.Text = TextConfig.Resolve(data.titleKey or data.title)
	self._body.Text = TextConfig.Resolve(data.bodyKey or data.body)
	self._body.FontFace = self:GetTheme().Fonts.Body
	self._bodyConstraint.MaxTextSize = self:GetTheme().TextSizes.Body
	self._body.TextColor3 = self:GetTheme().Colors.TextSecondary

	self._confirmButton:SetContent({ textKey = data.confirmKey or (isInfo and "modal.ok" or "modal.confirm") })
	self._confirmButton.Props.variant = data.kind == "Danger" and "Danger" or "Primary"
	self._confirmButton:ApplyTheme(self:GetTheme())
	self._cancelButton.Root.Visible = not isInfo
	if not isInfo then
		self._cancelButton:SetContent({ textKey = data.cancelKey or "modal.cancel" })
	end

	-- Intro is driven centrally by UIScreenBase:Show (active animation pack).
end

return ModalScreen
