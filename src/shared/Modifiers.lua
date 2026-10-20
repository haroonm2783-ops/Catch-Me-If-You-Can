-- Round modifiers: pure data and selection so the server and tests share one definition.
-- Every modifier applies equally to both teams; none can be bought.
local Modifiers = {}

local list = {
	{id="classic", name="CLASSIC CHASE", tagline="Caught runners watch the chase. Survive until time runs out.",
		minPlayers=2, weight=3, duration=180},
	{id="infection", name="INFECTION", tagline="Caught runners join the hunt. Be the last runner standing.",
		minPlayers=4, weight=3, duration=180, infection=true, infectDelay=4, infectCutoff=6},
	{id="swarm", name="SWARM", tagline="Extra hunter, shorter chase. Stay moving.",
		minPlayers=6, weight=2, duration=120, extraHunters=1},
	{id="frenzy", name="SLIDE FRENZY", tagline="Slides and vaults recharge twice as fast for everyone.",
		minPlayers=2, weight=2, duration=180, cooldownScale=0.5},
}
Modifiers.List = list
Modifiers.ById = {}
for _, modifier in ipairs(list) do Modifiers.ById[modifier.id] = modifier end
Modifiers.Default = Modifiers.ById.classic

function Modifiers.Get(id)
	return Modifiers.ById[id] or Modifiers.Default
end

-- Hunters for a modifier: never leave fewer than two runners, never fewer than one hunter.
function Modifiers.HunterCount(modifier, playerCount, baseCount)
	local count = baseCount + (modifier.extraHunters or 0)
	return math.max(math.min(count, playerCount - 2), math.min(baseCount, 1) )
end

-- Weighted choice among modifiers the lobby is big enough for, avoiding an immediate repeat.
-- `roll` is a function(maximumInclusive) -> integer in [1, maximum]. Practice is always Classic.
function Modifiers.Pick(playerCount, lastId, practice, roll)
	if practice then return Modifiers.Default end
	local pool, total = {}, 0
	for _, modifier in ipairs(list) do
		if playerCount >= modifier.minPlayers and modifier.id ~= lastId then
			table.insert(pool, modifier)
			total += modifier.weight
		end
	end
	if #pool == 0 then return Modifiers.Default end
	local target = roll(total)
	for _, modifier in ipairs(pool) do
		target -= modifier.weight
		if target <= 0 then return modifier end
	end
	return pool[#pool]
end

-- Safe subset for clients.
function Modifiers.Public(modifier)
	return {id=modifier.id, name=modifier.name, tagline=modifier.tagline, duration=modifier.duration}
end

return Modifiers
