-- Shared tunables. Prices and pass IDs live in Catalog.lua.
local Config = {
	GameName = "CATCH ME IF YOU CAN",
	Version = "0.3.0",
	Round = {
		MaxPlayers = 12, MinimumPlayers = 2, Duration = 180, Intermission = 16,
		ResultsDuration = 10, HeadStart = 5, FinalSeconds = 30, RespawnDelay = 2,
		StudioSolo = true,
	},
	Movement = {
		WalkSpeed = 17, RunnerSprint = 26, HunterSprint = 27, Acceleration = 7,
		JumpPower = 48, SlideSpeed = 35, SlideDuration = 0.72, SlideCooldown = 3,
		SlideAccelerationTime = 0.1, SlideMinimumSpeed = 4,
		VaultCooldown = 1.1, VaultDistance = 5, VaultHeight = 4.5,
		TagRange = 5.8, TagCooldown = 0.65,
	},
	Persistence = {
		StoreName = "CatchMeIfYouCan_v1", AutosaveSeconds = 60, Retries = 3,
		UseStudioDataStores = false, SessionLockSeconds = 180,
	},
	Progression = {
		RoundXP = 45, WinXP = 80, TagXP = 25, SurvivalXPPerSecond = 0.4,
		RoundCoins = 12, WinCoins = 25, TagCoins = 6,
	},
	-- Only set IDs for audio you own or have permission to use in this experience.
	-- Music=0 is silent; SFX=0 use quiet engine-bundled cues. Positive IDs override.
	-- Unavailable audio is skipped; every action also has visual feedback.
	Audio = {
		Music = 0, Sprint = 0, Slide = 0, Vault = 0, Land = 0, Tag = 0, Win = 0, Lose = 0,
		Level = 0, Countdown = 0, Final = 0, Purchase = 0,
	},
}
return table.freeze(Config)
