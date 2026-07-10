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
	local backdrop = Instance.new("TextButton")
	backdrop.Name = "Backdrop"
	backdrop.Text = ""
	backdrop.AutoButtonColor = false
	backdrop.Size = UDim2.fromScale(1, 1)
	backdrop.BackgroundColor3 = Color3.new(0, 0, 0)
	backdrop.BackgroundTransparency = 0.5
	backdrop.Parent = self.Root
	self._backdrop = backdrop

	local pack = self.ThemeController:GetPack()
	local panel = UIPanelComponent.new()
	self._panel = panel
	panel:Create(self.Root, {
		title = "",
		showClose = false,
		size = UDim2.fromScale(pack.Modal.WidthScale, 0.34),
	})

	local body = UIStyler.TextLabel("Body")
	body.Size = UDim2.new(1, -32, 1, -110)
	body.Position = UDim2.fromOffset(16, 8)
	body.TextWrapped = true
	body.TextYAlignment = Enum.TextYAlignment.Top
	body.Parent = panel.Body
	self._body = body

	local buttonRow = UIStyler.Frame("Buttons")
	buttonRow.BackgroundTransparency = 1
	buttonRow.Size = UDim2.new(1, -32, 0, 46)
	buttonRow.AnchorPoint = Vector2.new(0.5, 1)
	buttonRow.Position = UDim2.new(0.5, 0, 1, -14)
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
		size = UDim2.new(0, 130, 1, 0),
		layoutOrder = 1,
		onClick = function()
			self:_Close(false)
		end,
	})

	self._confirmButton = UIButtonComponent.new()
	self._confirmButton:Create(buttonRow, {
		textKey = "modal.confirm",
		variant = "Primary",
		size = UDim2.new(0, 150, 1, 0),
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
	self._body.TextSize = self:GetTheme().TextSizes.Body
	self._body.TextColor3 = self:GetTheme().Colors.TextSecondary

	self._confirmButton:SetContent({ textKey = data.confirmKey or (isInfo and "modal.ok" or "modal.confirm") })
	self._confirmButton.Props.variant = data.kind == "Danger" and "Danger" or "Primary"
	self._confirmButton:ApplyTheme(self:GetTheme())
	self._cancelButton.Root.Visible = not isInfo
	if not isInfo then
		self._cancelButton:SetContent({ textKey = data.cancelKey or "modal.cancel" })
	end

	self._panel:PlayAnimation("Appear")
end

return ModalScreen
