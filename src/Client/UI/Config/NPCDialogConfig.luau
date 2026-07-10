--!strict
-- Data-driven NPC dialogue. A sequence is an ordered list of lines; each line
-- names a speaker, the text (via key), an optional portrait tint (placeholder
-- until real portraits), and an optional per-line type speed. The last line may
-- carry choices (buttons). NPCDialogScreen types each line out at its speed.
--
-- Add dialogue by adding a sequence here — the screen renders whatever it's
-- handed, so writers never touch UI code.

local NPCDialogConfig = {}

export type DialogChoice = { textKey: string, id: string }

export type DialogLine = {
	speakerKey: string,
	textKey: string,
	portraitColor: Color3?,
	-- Characters per second for this line (falls back to the sequence default).
	typeSpeed: number?,
	choices: { DialogChoice }?,
}

export type DialogSequence = {
	id: string,
	defaultTypeSpeed: number,
	lines: { DialogLine },
}

NPCDialogConfig.Sequences = {
	welcome_merchant = {
		id = "welcome_merchant",
		defaultTypeSpeed = 45,
		lines = {
			{ speakerKey = "npc.merchant.name", textKey = "npc.merchant.l1", portraitColor = Color3.fromRGB(206, 158, 74) },
			{ speakerKey = "npc.merchant.name", textKey = "npc.merchant.l2", portraitColor = Color3.fromRGB(206, 158, 74) },
			{
				speakerKey = "npc.merchant.name",
				textKey = "npc.merchant.l3",
				portraitColor = Color3.fromRGB(206, 158, 74),
				typeSpeed = 30,
				choices = {
					{ id = "shop", textKey = "npc.choice.shop" },
					{ id = "bye", textKey = "npc.choice.bye" },
				},
			},
		},
	},
} :: { [string]: DialogSequence }

function NPCDialogConfig.Get(id: string): DialogSequence?
	return NPCDialogConfig.Sequences[id]
end

return NPCDialogConfig
