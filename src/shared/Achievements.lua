-- Single source for achievements (server unlocks, client profile display).
-- `stat` reads profile.stats[stat] or profile[stat]. Rewards are coins only.
local Achievements = {}
Achievements.List = {
	{id="first_round", name="FIRST FOOTSTEPS", text="Complete your first round", stat="rounds", goal=1, coins=20},
	{id="first_win", name="FIRST GLORY", text="Win your first chase", stat="wins", goal=1, coins=30},
	{id="tag_10", name="HOT PURSUIT", text="Make 10 successful tags", stat="tags", goal=10, coins=40},
	{id="tag_50", name="MALL CATCHER", text="Make 50 successful tags", stat="tags", goal=50, coins=80},
	{id="tag_200", name="APEX HUNTER", text="Make 200 successful tags", stat="tags", goal=200, coins=200},
	{id="survivor_600", name="LONG WAY HOME", text="Survive for 600 seconds in total", stat="survived", goal=600, coins=60},
	{id="survivor_3000", name="GHOST OF THE MALL", text="Survive for 3,000 seconds in total", stat="survived", goal=3000, coins=150},
	{id="veteran_25", name="FOOD COURT REGULAR", text="Complete 25 rounds", stat="rounds", goal=25, coins=75},
	{id="veteran_100", name="MALL LOCAL", text="Complete 100 rounds", stat="rounds", goal=100, coins=250},
	{id="streak_3", name="ON A ROLL", text="Win 3 rounds in a row", stat="bestStreak", goal=3, coins=50},
	{id="streak_7", name="UNSTOPPABLE", text="Win 7 rounds in a row", stat="bestStreak", goal=7, coins=200},
	{id="wins_10", name="TEN OUT OF TEN", text="Win 10 rounds", stat="wins", goal=10, coins=100},
	{id="hunter_5", name="NATURAL HUNTER", text="Win 5 rounds as a hunter", stat="hunterWins", goal=5, coins=75},
	{id="runner_10", name="BORN TO RUN", text="Win 10 rounds as a runner", stat="runnerWins", goal=10, coins=100},
	{id="level_10", name="RISING STAR", text="Reach level 10", stat="level", goal=10, coins=100},
	{id="level_25", name="MALL VETERAN", text="Reach level 25", stat="level", goal=25, coins=300},
	{id="pickups_100", name="COIN COLLECTOR", text="Collect 100 mall coins", stat="pickups", goal=100, coins=60},
	{id="pickups_500", name="COIN HOARDER", text="Collect 500 mall coins", stat="pickups", goal=500, coins=200},
	{id="finds_10", name="SHARP EYES", text="Discover 10 hidden runners", stat="finds", goal=10, coins=60},
	{id="close_10", name="CLOSE SHAVE", text="Survive 10 close calls", stat="closeCalls", goal=10, coins=60},
}
Achievements.ById = {}
for _, achievement in ipairs(Achievements.List) do Achievements.ById[achievement.id] = achievement end
return Achievements
