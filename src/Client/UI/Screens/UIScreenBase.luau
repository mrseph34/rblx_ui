--!strict
-- Base class for screens. Each screen owns exactly one ScreenGui built via
-- script; the base handles construction, the show/hide fade, controller
-- injection and teardown. Subclasses override _BuildContent (populate the root)
-- and optionally _OnShow/_OnHide/Update.
--
-- Screens receive the theme + screen controllers via SetControllers, so they
-- can read the active theme/pack and (for interactive screens) drive
-- navigation without global singletons.

local Players = game:GetService("Players")

local Types = require(script.Parent.Parent.Types)
local UIStyler = require(script.Parent.Parent.UIStyler)

local UIScreenBase = {}
UIScreenBase.__index = UIScreenBase

function UIScreenBase.new(name: string, displayOrder: number?)
	local self = setmetatable({}, UIScreenBase)
	self.Name = name
	self.ThemeController = nil :: any
	self.ScreenController = nil :: any
	self._built = false
	self._visible = false

	local gui = Instance.new("ScreenGui")
	gui.Name = name
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = displayOrder or 1
	gui.Enabled = false
	self.Gui = gui

	-- Full-screen transparent root every screen parents content into.
	local root = UIStyler.Frame("Root")
	root.BackgroundTransparency = 1
	root.Size = UDim2.fromScale(1, 1)
	root.Parent = gui
	self.Root = root

	return self
end

function UIScreenBase:SetControllers(themeController: any, screenController: any)
	self.ThemeController = themeController
	self.ScreenController = screenController
end

function UIScreenBase:_EnsureBuilt()
	if self._built then
		return
	end
	self._built = true
	-- Parent to the local player's PlayerGui lazily (first show), so screens
	-- can be constructed before the GUI hierarchy is needed.
	local playerGui = Players.LocalPlayer and Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if playerGui then
		self.Gui.Parent = playerGui
	end
	self:_BuildContent()
end

-- Override: build content into self.Root using components.
function UIScreenBase:_BuildContent() end

-- Override: react to show/hide (start timers, refresh data).
function UIScreenBase:_OnShow(_data: any?) end
function UIScreenBase:_OnHide() end

function UIScreenBase:GetTheme(): Types.UITheme
	return self.ThemeController:GetTheme()
end

function UIScreenBase:Show(data: any?)
	self:_EnsureBuilt()
	self._visible = true
	self.Gui.Enabled = true
	local theme = self:GetTheme()
	self.Root.Size = UDim2.fromScale(1, 1)
	-- Fade the root in; individual components animate themselves on build.
	UIStyler.Tween(self.Root, theme.Animations.Appear, { BackgroundTransparency = 1 })
	self:_OnShow(data)
end

function UIScreenBase:Hide()
	if not self._visible then
		return
	end
	self._visible = false
	self:_OnHide()
	local theme = self:GetTheme()
	local fade = UIStyler.Tween(self.Root, theme.Animations.Disappear, { BackgroundTransparency = 1 })
	fade.Completed:Once(function()
		if not self._visible then
			self.Gui.Enabled = false
		end
	end)
end

function UIScreenBase:Update(_data: any) end

function UIScreenBase:IsVisible(): boolean
	return self._visible
end

function UIScreenBase:Destroy()
	if self.Gui then
		self.Gui:Destroy()
	end
end

return UIScreenBase
