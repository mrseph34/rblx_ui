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

-- Optional tiled surface texture (e.g. a Roblox "studs" image) layered over the
-- flat fill of panels and cards, under the content. OPTIONAL on a theme so
-- themes that omit it render flat exactly as before.
export type UIThemeTexture = {
	Image: string, -- "rbxassetid://..."
	TileSize: number, -- px size of one repeated tile (ScaleType = Tile)
	Tint: Color3, -- ImageColor3 applied to the texture
	Transparency: number, -- 0..1 (1 = texture invisible, so it reads as subtle grain)
}

-- Optional glyph/element outline: the "chunky Roblox" bold dark line around text
-- (and small elements like slider/toggle knobs). Applied via a Contextual
-- UIStroke so it outlines a label's text but a frame's border. OPTIONAL — themes
-- that omit it get no outline, exactly as before.
export type UIThemeTextOutline = {
	Color: Color3,
	Thickness: number,
	Transparency: number, -- 0..1 (0 = solid outline)
}

-- Shape: the "feel" of surfaces independent of colour/font. Decides how round
-- things are and whether buttons/cards read as Flat, Bubbly (pill-round, springy)
-- or Raised3D (bevel + drop shadow that depresses on press). OPTIONAL on a theme
-- so older theme files keep working; ThemeShape.Resolve fills in Flat defaults.
export type UIThemeShapeStyle = "Flat" | "Bubbly" | "Raised3D"

export type UIThemeShape = {
	-- Multiplies every corner radius. 1 = as-authored, >1 rounder, <1 boxier.
	-- Bubbly styles push this high; the styler still clamps to a full pill.
	RoundnessScale: number,
	Style: UIThemeShapeStyle,
	-- Raised3D: how many px the bevel/shadow drops the surface, and how bright the
	-- top highlight / how dark the bottom shade read (0..1). Ignored by Flat.
	Depth: number,
	HighlightTransparency: number, -- 0..1, top inner-bevel brightness
	ShadowStrength: number, -- 0..1, bottom drop-shadow darkness (1 = strongest)
	-- Bubbly: extra hover/press springiness added on top of Effects scales.
	Bounce: number,
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
	-- Optional; ThemeShape.Resolve(theme) returns a full shape with Flat defaults
	-- when a theme omits this, so every theme is shape-safe without editing it.
	Shape: UIThemeShape?,
	-- Optional; a tiled "studs"-style texture over panel/card fills. nil = flat.
	Texture: UIThemeTexture?,
	-- Optional; a bold outline around text glyphs + knob borders. nil = no outline.
	TextOutline: UIThemeTextOutline?,
}

-- ========================================================================
-- Layout packs
-- ========================================================================

export type UIPackShop = {
	-- How entries flow in the scroll frame.
	Container: "Grid" | "List",
	Columns: number,
	CardHeight: number,
	-- EntryLayoutConfig spec id — decides the per-card focal/arrangement.
	EntryLayout: string,
	ShowCategoryBar: boolean,
}

export type Region = "TopLeft" | "TopCenter" | "TopRight" | "BottomLeft" | "BottomCenter" | "BottomRight"

export type UIPackHUD = {
	Compact: boolean,
	ShowObjectives: boolean,
	Scale: number,
	-- Where the currency chips sit, and which side their icon is on. Moving
	-- these per pack is what gives each pack a different "feel".
	MoneyRegion: Region,
	MoneyIconSide: "Left" | "Right",
	-- Optional per-element region overrides (elementId -> region). Lets a pack —
	-- or runtime code via GameHUDScreen:SetElementRegion — move ANY HUD element
	-- (timer, level, health, a skills bar, ...) anywhere, not just the money.
	Regions: { [string]: Region }?,
}

export type UIPackNav = {
	Side: "Left" | "Right",
	Vertical: "Top" | "Center" | "Bottom",
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
	Nav: UIPackNav,
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
	-- Optional per-step highlight styling (see UIHighlightComponent) — falls
	-- back to its own defaults (RoundedSquare, no arrow) when omitted.
	highlightShape: ("Circle" | "Square" | "RoundedSquare")?,
	highlightArrowDirection: ("Up" | "Down" | "Left" | "Right")?,
}

export type TutorialScreenData = {
	steps: { TutorialStep }?,
	onComplete: ((completed: boolean) -> ())?,
}

local Types = {}

return Types
