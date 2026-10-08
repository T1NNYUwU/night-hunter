--!strict
-- Shop items, bought with coins during the day and used at night. Shared so the HUD and the
-- server agree on names, prices and keys. Effects live on the server (Economy.luau).

export type Item = { name: string, price: number, max: number, key: string, desc: string }

local Items = {
	order = { "decoy", "battery", "adrenaline" },
	list = {
		decoy = {
			name = "Noise Maker",
			price = 20,
			max = 3,
			key = "Q",
			desc = "Throw it ahead of you: a loud noise where it lands. The hunter goes to check.",
		},
		battery = {
			name = "Battery",
			price = 10,
			max = 3,
			key = "R",
			desc = "Refills your flashlight.",
		},
		adrenaline = {
			name = "Adrenaline",
			price = 25,
			max = 2,
			key = "X",
			desc = "6 seconds of fast running that costs no stamina.",
		},
	} :: { [string]: Item },
}

-- Coins paid out by the server.
Items.REWARD = {
	crate = 10,
	fuse = 12,
	key = 15,
	nightSurvived = 15,
}

Items.ADRENALINE_SECONDS = 6
Items.ADRENALINE_SPEED = 24

return Items
