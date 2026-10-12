local Online = require("rizu.api.Online")
local Play = require("rizu.api.Play")
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

return test
