local Online = require("rizu.api.Online")
local Play = require("rizu.api.Play")
local Result = require("rizu.api.Result")
local Gameplay = require("rizu.api.Gameplay")
local Input = require("rizu.api.Input")
local Skins = require("rizu.api.Skins")
local OnlineClient = require("rizu.online.OnlineClient")
local TimeRateModel = require("sphere.models.TimeRateModel")
local ModifierSelectModel = require("sphere.models.ModifierSelectModel")
local GameApi = require("rizu.api.GameApi")
local ReplayBase = require("sea.replays.ReplayBase")

local test = {}

---@param t testing.T
function test.online(t)
	local client = OnlineClient()
	local logins = {}
	local game = {
		online_client = client,
		avatar_cache = {get = function(_, url) return url and "image of " .. url end},
		onlineModel = {authManager = {
			login = function(_, email, password) logins[#logins + 1] = email .. ":" .. password end,
			logout = function() logins[#logins + 1] = "logout" end,
		}},
	}
	local online = Online(game --[[@as any]])
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

	local results = {}
	online:login("a@b", "pw", function(ok, err) results[#results + 1] = {ok, err} end)
	online:login("c@d", "pw", function(ok, err) results[#results + 1] = {ok, err} end)
	client:loginFailed("wrong password")
	t:tdeq(results, {{false, "wrong password"}, {false, "wrong password"}})
	client:loginSucceeded({} --[[@as any]])
	t:eq(#results, 2, "a login that has ended does not hear the next one")
	online:logout()
	t:tdeq(logins, {"a@b:pw", "c@d:pw", "logout"})
end

---@param t testing.T
function test.version(t)
	t:eq(type(GameApi.version), "number")
end

---@return rizu.api.Play play
---@return table game
---@return fun(): integer changes How many times the game was told the mods changed.
local function createPlay()
	local replay_base = ReplayBase()
	local select_model = ModifierSelectModel(replay_base)
	local changed = 0
	local change = select_model.change
	select_model.change = function(self) changed = changed + 1; change(self) end
	local time_rate_model = TimeRateModel(replay_base)
	-- The backend, not the API, tells the select model about a new rate.
	time_rate_model:onChanged(function() select_model:change() end)
	local game = {
		replayBase = replay_base,
		timeRateModel = time_rate_model,
		modifierSelectModel = select_model,
		gameplayInteractor = {replay_stores = {}},
		chartSelector = {},
	}
	return Play(game --[[@as any]]), game, function() return changed end
end

---@param t testing.T
function test.play_rate(t)
	local play, _, changes = createPlay()
	local events = 0
	play:on("rate_changed", function() events = events + 1 end)

	play:changeRate(2)
	t:eq(events, 1)
	t:eq(changes(), 1)
	t:assert(math.abs(play:getRate() - 1.1) < 1e-6)
	t:eq(play:getModCount(), 0)
	t:eq(play:getMutatorCount(), 0)

	play:setRateType("exp")
	t:eq(play:getRateType(), "exp")
	t:tdeq({play:getRateValue()}, {1, -20, 20, 1})
	play:setRateValue(0)
	t:eq(play:getRate(), 1)
	t:eq(events, 3)
end

---@param t testing.T
function test.play_mods(t)
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
end

---@param t testing.T
function test.play_mutators(t)
	local play, game, changes = createPlay()
	local events = 0
	play:on("mods_changed", function() events = events + 1 end)

	t:assert(#play:getAvailableMutators() > 0)
	play:addMutator("Mirror")
	play:addMutator("Shift")
	t:eq(play:getMutatorCount(), 2)
	t:eq(play:getMutatorName(play:getMutators()[2]), "Shift")
	t:eq(play:getMutatorPosition(), 3)
	t:eq(events, 2)
	t:assert(changes() >= 2, "the select model is told")

	play:setMutatorPosition(1)
	play:addMutator("BracketSwap")
	t:eq(play:getMutatorName(play:getMutators()[1]), "BracketSwap")
	play:setMutatorPosition(99)
	t:eq(play:getMutatorPosition(), 4, "the insertion point stays in the list")

	t:eq(play:hasMutatorValue(play:getMutators()[1]), false)
	local shift = play:getMutators()[3]
	t:eq(play:hasMutatorValue(shift), true)
	local before = shift.value
	t:eq(play:changeMutatorValue(3, 1), true)
	t:assert(shift.value ~= before)
	t:eq(play:changeMutatorValue(1, 1), false, "a mutator without a setting has nothing to change")

	play:addMutator("NoLongNote")
	t:eq(play:canAddMutator("NoLongNote"), false)
	local count = play:getMutatorCount()
	play:addMutator("NoLongNote")
	t:eq(play:getMutatorCount(), count, "a mutator that can be used once is not added twice")

	play:removeMutator(1)
	t:eq(play:getMutatorCount(), count - 1)
	t:eq(#game.replayBase.modifiers, count - 1)
end

---@param t testing.T
function test.play_start(t)
	local play, game = createPlay()
	local loaded = {}
	local interactor = game.gameplayInteractor
	game.gameInteractor = {loadGameplaySelectedChartAsync = function() return interactor.autoplay end}
	interactor.loadLocalReplay = function(_, hash) return hash == "h", "no replay" end
	game.chartSelector.chartview = {hash = "h", index = 1, chartmeta_mode = "mania"}

	local function start(options)
		local result
		play:start(options, function(ok, err) result = {ok, err} end)
		return result
	end

	-- Loading runs in a coroutine, which the test runner finishes before returning.
	t:tdeq(start({autoplay = true}), {true})
	t:eq(interactor.autoplay, true)
	t:eq(interactor.replaying, false)
	t:tdeq(start({}), {false})
	t:eq(interactor.autoplay, false)

	t:eq(play:hasLocalReplays(), false)
	t:tdeq(start({replay = true}), {false, "The selected chart has no local replay."})
	interactor.replay_stores.mania = {}
	t:eq(play:hasLocalReplays(), true)
	t:tdeq(start({replay = true}), {false})
	loaded[1] = true
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
	t:eq(mania:getJudgeWindows(), nil)

	local taiko = Gameplay({rhythm_engine = {rules = {hits = 3, misses = 2}}} --[[@as any]])
	t:tdeq({taiko:getHitCounts()}, {3, 2})
	t:eq(taiko:getJudgementCount(), 0)
	t:tdeq(taiko:getVisibleNotes(), {})
	t:eq(taiko:isColumnPressed(1), false)
end

---@param t testing.T
function test.gameplay_beat_phase(t)
	local function tempo(time, beat_duration)
		return {tempo = {point = {absoluteTime = time}, getBeatDuration = function() return beat_duration end}}
	end
	local time = 0.75
	local chart = {layers = {main = {getPointList = function() return {tempo(0, 0.5), tempo(1, 1)} end}}}
	local gameplay = Gameplay({rhythm_engine = {chart = chart, visual_info = {getTime = function() return time end}}} --[[@as any]])
	t:eq(gameplay:getBeatPhase(), 0.5)
	time = 1.25
	t:eq(gameplay:getBeatPhase(), 0.25)
	local empty_chart = {layers = {main = {getPointList = function() return {} end}}}
	t:eq(Gameplay({rhythm_engine = {chart = empty_chart}} --[[@as any]]):getBeatPhase(), nil)
end

---@param t testing.T
function test.input_bindings(t)
	local config, writes = {}, 0
	local game = {configModel = {configs = {input = config}, write = function() writes = writes + 1 end}}
	local input = Input(game --[[@as any]])
	local changes = {}
	input:on("bindings_changed", function(mode) changes[#changes + 1] = mode end)

	t:tdeq(input:getColumns("4key"), {"key1", "key2", "key3", "key4"})
	t:eq(input:getSlotCount("key1"), 1)
	t:eq(input:getSlotCount("scratch1"), 2)

	t:eq(input:getBinding("4key", "key2", 1), nil)
	input:setBinding("4key", "key2", 1, "d", "keyboard", 1)
	t:tdeq({input:getBinding("4key", "key2", 1)}, {"d", "keyboard", 1})
	t:eq(writes, 1)

	input:clearBinding("4key", "key2", 1)
	t:eq(input:getBinding("4key", "key2", 1), nil)
	input:setBinding("4key", "key1", 1, "a", "keyboard", 1)
	input:resetBindings("4key")
	t:eq(input:getBinding("4key", "key1", 1), nil)
	t:eq(writes, 4)
	t:tdeq(changes, {"4key", "4key", "4key", "4key"})
end

---@param t testing.T
function test.skins(t)
	local list = {{path = "builtin/mania"}, {path = "skins/a"}}
	local registry_listener, selected
	local game = {
		skinRegistry = {
			onChanged = function(_, f) registry_listener = f end,
			getSkinsFor = function() return list end,
			resolve = function() return list[2] end,
			select = function(_, gamemode, mode, skin) selected = {gamemode, mode, skin} end,
		},
		chartSelector = {chartview = {chartmeta_mode = "mania"}, isPlayableChartview = function() return true end},
		modifierCoordinator = {state = {inputMode = "7key"}},
	}
	local skins = Skins(game --[[@as any]])
	local changed = 0
	skins:on("skins_changed", function() changed = changed + 1 end)

	t:tdeq({skins:getContext()}, {"mania", "7key"})
	t:eq(skins:getList("mania", "7key"), list)
	t:eq(skins:getSelected("mania", "7key"), list[2])
	skins:select("mania", "7key", list[1])
	t:tdeq(selected, {"mania", "7key", list[1]})
	registry_listener()
	t:eq(changed, 1)

	game.chartSelector.isPlayableChartview = function() return false end
	t:eq(skins:getContext(), nil)
end

return test
