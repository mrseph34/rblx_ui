--!strict
-- Schemas for the client UI system: theme tokens, layout packs, component
-- props and per-screen data shapes. Pure types — no runtime logic.

-- ========================================================================
-- Theme tokens
-- ========================================================================

export type UIThemeColors = {
	Primary: Color3,
	Secondary: Color3,
	Accent: Color3,
	Background: Color3,
	Surface: Color3,
	SurfaceRaised: Color3,
	Success: Color3,
	Warning: Color3,
	Error: Color3,
	TextPrimary: Color3,
	TextSecondary: Color3,
	TextOnPrimary: Color3,
	Stroke: Color3,
	Overlay: Color3,
	Disabled: Color3,
}

export type UIThemeFonts = {
	Title: Font,
	Subtitle: Font,
	Body: Font,
	Button: Font,
	Numeric: Font,
}

export type UIThemeTextSizes = {
	Title: number,
	Subtitle: number,
	Body: number,
	Button: number,
	Small: number,
}

export type UIThemeRadii = {
	Small: number,
	Medium: number,
	Large: number,
	-- Oversized on purpose: UICorner clamps it to a full pill/circle.
	Pill: number,
}

export type UIThemeSpacing = {
	XS: number,
	S: number,
	M: number,
	L: number,
	XL: number,
}

export type UIThemeAnimations = {
	Appear: TweenInfo,
	Disappear: TweenInfo,
	Hover: TweenInfo,
	Press: TweenInfo,
	-- Value changes, attention pulses, toggle knobs, bar fills.
	Emphasis: TweenInfo,
	-- Used for every property tween during a live theme swap.
	ThemeSwap: TweenInfo,
}

export type UIThemeEffects = {
	UseGradients: boolean,
	GradientIntensity: number, -- 0..1
	ShadowTransparency: number, -- 0..1 (1 = shadow invisible)
	HoverScale: number,
	PressScale: number,
	StrokeThickness: number,
}

export type UITheme = {
	Id: string,
	DisplayName: string,
	Colors: UIThemeColors,
	Fonts: UIThemeFonts,
	TextSizes: UIThemeTextSizes,
	Radii: UIThemeRadii,
	Spacing: UIThemeSpacing,
	Animations: UIThemeAnimations,
	Effects: UIThemeEffects,
}

-- ========================================================================
-- Layout packs
-- ========================================================================

export type UIPackShop = {
	Layout: "Grid" | "List",
	Columns: number,
	CardHeight: number,
	ShowCategoryBar: boolean,
}

export type UIPackHUD = {
	Compact: boolean,
	ShowObjectives: boolean,
	Scale: number,
}

export type UIPackTutorial = {
	ShowStepList: boolean,
}

export type UIPackModal = {
	WidthScale: number,
}

export type UIPack = {
	Id: string,
	DisplayName: string,
	Shop: UIPackShop,
	HUD: UIPackHUD,
	Tutorial: UIPackTutorial,
	Modal: UIPackModal,
}

-- ========================================================================
-- Components
-- ========================================================================

export type UIComponentProps = {
	id: string?,
	text: string?,
	textKey: string?,
	icon: string?, -- emoji placeholder
	iconId: string?, -- rbxassetid:// image
	variant: string?,
	size: UDim2?,
	position: UDim2?,
	anchorPoint: Vector2?,
	layoutOrder: number?,
	enabled: boolean?,
	onClick: ((...any) -> ())?,
	tags: { string }?,
	[string]: any,
}

-- ========================================================================
-- Screen data
-- ========================================================================

export type ToastData = {
	text: string?,
	textKey: string?,
	variant: ("Info" | "Success" | "Error" | "Warning")?,
	duration: number?,
	icon: string?,
}

export type ModalData = {
	kind: ("Info" | "Confirm" | "Danger")?,
	title: string?,
	titleKey: string?,
	body: string?,
	bodyKey: string?,
	confirmKey: string?,
	cancelKey: string?,
	onConfirm: (() -> ())?,
	onCancel: (() -> ())?,
}

export type ObjectiveData = {
	id: string,
	text: string?,
	textKey: string?,
	done: boolean?,
}

export type HUDElementFormat = "Number" | "Time" | "Bar"

export type HUDElement = {
	id: string,
	format: HUDElementFormat,
	region: string,
	order: number,
	labelKey: string?,
	icon: string?,
	maxValue: number?,
	colorToken: string?,
}

export type HUDScreenData = {
	values: { [string]: number }?,
	objectives: { ObjectiveData }?,
}

export type ShopScreenData = {
	categoryId: string?,
	balances: { [string]: number }?,
}

export type TutorialStep = {
	id: string,
	titleKey: string?,
	textKey: string,
	highlightTargetId: string?,
	hintKeys: { string }?,
}

export type TutorialScreenData = {
	steps: { TutorialStep }?,
	onComplete: ((completed: boolean) -> ())?,
}

local Types = {}

return Types
