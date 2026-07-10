--!strict
-- Shared data schemas used by both the server (validation) and the client
-- (rendering). Pure types — no runtime logic. Add new fields freely; remove
-- or rename only deliberately, since both domains compile against these.

export type CurrencyId = "Coins" | "Gems"

export type CurrencyDef = {
	id: CurrencyId,
	nameKey: string,
	-- Emoji placeholder for MVP; swap for an "rbxassetid://..." image later.
	icon: string,
	-- Name of a theme color token (e.g. "Accent"), resolved client-side.
	colorToken: string,
	order: number,
}

export type ShopItemTag = "New" | "Sale" | "Rare" | "Limited" | "Popular"

export type ShopItem = {
	id: string,
	nameKey: string,
	descriptionKey: string?,
	-- "" means "no icon yet" — the client renders a monogram swatch placeholder.
	iconId: string,
	price: number,
	currencyType: CurrencyId,
	category: string,
	tags: { ShopItemTag }?,
}

export type ShopCategory = {
	id: string,
	nameKey: string,
	order: number,
}

export type CurrencyBalances = { [string]: number }

export type PurchaseResult = {
	success: boolean,
	messageKey: string,
	balances: CurrencyBalances?,
}

local Types = {}

return Types
