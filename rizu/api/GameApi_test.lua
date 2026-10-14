local Online = require("rizu.api.Online")
local Play = require("rizu.api.Play")
local Result = require("rizu.api.Result")
local Gameplay = require("rizu.api.Gameplay")
local OnlineClient = require("rizu.online.OnlineClient")
local TimeRateModel = require("sphere.models.TimeRateModel")
local ReplayBase = require("sea.replays.ReplayBase")
local Settings = require("rizu.config.Settings")
local FakeFilesystem = require("fs.FakeFilesystem")

local test = {}

---@param t testing.T
function test.online(t)
	local client = OnlineClient()
	local online = Online(client, {get = function(_, url) return url and "image of " .. url end} --[[@as any]])
	local account, count = 0, 0
	online:on("account_changed", function() account = account + 1 end)
	online:on("online_count_changed", function() count = count + 1 end)

	t:eq(online:getUsername(), nil)
	t:eq(online:getOnlineCount(), nil)

	client:setUser({name = "Nimue", avatar = "a.png"} --[[@as any]])
	t:eq(account, 1)
	t:eq(online:getUsername(), nil, "a name is shown only while connected")
	client:setConnected(true)
	client:setOnlineCount(7)
	t:eq(account, 2)
	t:eq(count, 1)
	t:eq(online:getUsername(), "Nimue")
	t:eq(online:getAvatarUrl(), "a.png")
	t:eq(online:getOnlineCount(), 7)
	t:eq(online:getAvatar("a.png"), "image of a.png")
end

---@return rizu.api.Play play
---@return table game
---@return fun(): integer changes How many times the game was told the mods changed.
local function createPlay()
	local replay_base = ReplayBase()
	local changed = 0
	local game = {
		replayBase = replay_base,
		timeRateModel = TimeRateModel(replay_base),
		modifierSelectModel = {replayBase = replay_base, change = function() changed = changed + 1 end},
		gameplayInteractor = {},
		settings = Settings.createConfig(FakeFilesystem()),
	}
	return Play(game --[[@as any]]), game, function() return changed end
end

---@param t testing.T
function test.play_rate(t)
	local play, game, changes = createPlay()
	local events = 0
	play:on("rate_changed", function() events = events + 1 end)

	t:eq(play:getRateText(), "1.00x")
	play:changeRate(2)
	t:eq(events, 1)
	t:eq(changes(), 1)
	t:eq(play:getRateText(), "1.10x")
	t:assert(math.abs(play:getRate() - 1.1) < 1e-6)
	t:eq(play:getModCount(), 0)
	t:eq(play:getMutatorCount(), 0)

	play:prepare(true)
	t:eq(game.gameplayInteractor.autoplay, true)
	t:eq(game.gameplayInteractor.replaying, false)

	play:setRateType("exp")
	t:eq(play:getRateType(), "exp")
	t:tdeq({play:getRateValue()}, {1, -20, 20, 1})
	t:eq(play:getRateText(), "+1")
	play:setRateValue(0)
	t:eq(play:getRate(), 1)
	t:eq(events, 3)
end

---@param t testing.T
function test.play_mods_and_judging(t)
	local play, game, changes = createPlay()
	local events = 0
	play:on("mods_changed", function() events = events + 1 end)

	play:setToggle("constant_scroll", true)
	play:setToggle("taps_only", true)
	t:eq(play:getToggle("constant_scroll"), true)
	t:eq(game.replayBase.const, true)
	t:eq(play:getModCount(), 2)
	t:eq(events, 2)
	t:eq(changes(), 2)

	t:eq(play:getToggle("auto_timings"), true)
	play:setToggle("auto_timings", false)
	t:eq(play:getToggle("auto_timings"), false)
	t:eq(play:getTimingSystem(), "sphere")
	t:assert(game.replayBase.timing_values)

	play:setTimingSystem("osuod")
	play:setTimingValue(9.699999)
	t:eq(play:getTimingSystem(), "osuod")
	t:eq(play:getTimingValue(), 9.7)
	t:eq(play:getOsuScoreVersion(), 1)
	play:setOsuScoreVersion(2)
	t:eq(play:getOsuScoreVersion(), 2)
	t:eq(play:getTimingValue(), 9.7)
	t:eq(game.replayBase.subtimings.data, 2)

	play:setTimingSystem("etternaj")
	play:setTimingValue(7)
	t:eq(game.replayBase.subtimings, nil)
	play:setTimingSystem("osuod")
	t:eq(play:getTimingValue(), 9.7, "a system comes back with its last value")
	play:setTimingSystem("etternaj")
	t:eq(play:getTimingValue(), 7)
end

---@param t testing.T
function test.result(t)
	local judges = {
		timings = {name = "etternaj", data = 4},
		getKey = function() return "etterna" end,
		getJudges = function() return {1, 0, 1} end,
	}
	local score_engine = {
		scores = {},
		sequence = {
			{base = {currentTime = 1, lastMean = 0.01}, misc = {deltaTime = -0.02}, etterna = {last_judge = 1}},
			{base = {currentTime = 2, isMiss = true}, misc = {}, etterna = {last_judge = 3}},
		},
	}
	local game = {
		rhythm_engine = {score_engine = score_engine, pause_counter = {count = 2}},
		computeContext = {chartdiff = {judges_count = 3}, chartplay = {rate = 1.5, pause_count = 0}},
		resultController = {},
		replayBase = {rate = 1.2, modifiers = {{id = 1}}},
	}
	local result = Result(game --[[@as any]])

	t:eq(result:hasScore(), false)
	score_engine.judgesSource = judges
	score_engine.accuracySource = {}
	t:eq(result:hasScore(), true)

	t:tdeq(result:getHits(), {
		{time = 1, kind = "hit", delta = -0.02, judge = 1, accuracy = 0, mean = 0.01, normalscore = 0},
		{time = 2, kind = "miss", delta = 0, judge = 3, accuracy = 0, mean = 0, normalscore = 0},
	})
	local early, late = result:getHitWindow()
	t:assert(early < 0 and late > 0)
	t:tdeq({result:getMaxCombo()}, {0, 3})

	-- After a play the numbers are the player's own, for a replayed score they are the score's.
	t:tdeq({result:getRate(), result:getPauseCount(), #result:getMutators()}, {1.2, 2, 1})
	game.resultController.replay = {}
	game.resultController.replay_base = {modifiers = {}}
	t:tdeq({result:getRate(), result:getPauseCount(), #result:getMutators()}, {1.5, 0, 0})
end

---@param t testing.T
function test.gameplay_score(t)
	local sequence = {
		{base = {isMiss = false, isEarlyHit = false}, misc = {deltaTime = -0.012}, osu = {visual_judge = 2}},
		{base = {isMiss = true, isEarlyHit = false}, misc = {deltaTime = 0.2}},
	}
	local score_engine = {
		scores = {base = {hitCount = 1, missCount = 1}},
		sequence = sequence,
		judgesSource = {getKey = function() return "osu" end, getJudgeNames = function() return {"300", "200"} end},
	}
	local mania = Gameplay({rhythm_engine = {score_engine = score_engine}} --[[@as any]])
	t:tdeq({mania:getHitCounts()}, {1, 1})
	t:eq(mania:getScore(), nil, "a missing source reads as nil")
	t:eq(mania:getJudgementCount(), 2)
	t:tdeq({mania:getJudgement(1)}, {"hit", -0.012, 2})
	t:tdeq({mania:getJudgement(2)}, {"miss", 0})
	t:tdeq(mania:getJudgeNames(), {"300", "200"})

	local taiko = Gameplay({rhythm_engine = {rules = {hits = 3, misses = 2}}} --[[@as any]])
	t:tdeq({taiko:getHitCounts()}, {3, 2})
	t:eq(taiko:getJudgementCount(), 0)
	t:tdeq(taiko:getVisibleNotes(), {})
	t:eq(taiko:isColumnPressed(1), false)
end

return test
