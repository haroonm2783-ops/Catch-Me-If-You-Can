-- Shared tunables. Prices and pass IDs live in Catalog.lua.
local Config = {
	GameName = "CATCH ME IF YOU CAN",
	Version = "0.7.0",
	-- "Mall" (default) or "NeonHeights" (the earlier rooftop map, kept as an alternate).
	Map = "Mall",
	Round = {
		MaxPlayers = 12, MinimumPlayers = 2, Duration = 180, Intermission = 16,
		ResultsDuration = 10, HeadStart = 5, FinalSeconds = 30, RespawnDelay = 2, ScareDistance = 34,
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
		PickupXP = 3, PickupCoins = 1, CloseCallXP = 5, FindXP = 8,
	},
	-- Hiding, searching and scanning: tuned so hiding is a short breather, never a safe zone.
	Hide = {
		MaxSeconds = 7, Cooldown = 12, SpotLock = 3, SearchCooldown = 0.9, PromptSlack = 4,
		ScanCooldown = 25, ScanRadius = 45, ScanDuration = 2.2,
		PickupRadius = 4.6, PickupCap = 25, CloseCallNear = 7, CloseCallFar = 22, CloseCallMax = 5, CloseCallGap = 8,
	},
	-- Only set IDs for audio you own or have permission to use in this experience.
	-- Music=0 is silent; SFX=0 use quiet engine-bundled cues. Positive IDs override.
	-- Unavailable audio is skipped; every action also has visual feedback.
	Audio = {
		Music = 0, Sprint = 0, Slide = 0, Vault = 0, Land = 0, Tag = 0, Win = 0, Lose = 0,
		Level = 0, Countdown = 0, Final = 0, Purchase = 0,
		-- Mall gameplay cues. Leave 0 to use the bundled engine fallbacks; paste a verified rbxassetid to override.
		Pickup = 0, CloseCall = 0, Found = 0, Hide = 0, Reveal = 0, Scan = 0,
		-- Looping mall ambience (crowd, fountain, muzak) under the music; 0 = silent.
		Ambience = 0,
	},
}
return table.freeze(Config)
