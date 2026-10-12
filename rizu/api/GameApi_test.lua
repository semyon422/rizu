local Online = require("rizu.api.Online")
local Play = require("rizu.api.Play")
local OnlineClient = require("rizu.online.OnlineClient")
local TimeRateModel = require("sphere.models.TimeRateModel")
local ReplayBase = require("sea.replays.ReplayBase")

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

---@param t testing.T
function test.play_rate(t)
	local replay_base = ReplayBase()
	local changed = 0
	local game = {
		replayBase = replay_base,
		timeRateModel = TimeRateModel(replay_base),
		modifierSelectModel = {replayBase = replay_base, change = function() changed = changed + 1 end},
		gameplayInteractor = {},
	}
	local play = Play(game --[[@as any]])
	local events = 0
	play:on("rate_changed", function() events = events + 1 end)

	t:eq(play:getRateText(), "1.00x")
	play:changeRate(2)
	t:eq(events, 1)
	t:eq(changed, 1)
	t:eq(play:getRateText(), "1.10x")
	t:assert(math.abs(play:getRate() - 1.1) < 1e-6)
	t:eq(play:getModCount(), 0)
	t:eq(play:getMutatorCount(), 0)

	play:prepare(true)
	t:eq(game.gameplayInteractor.autoplay, true)
	t:eq(game.gameplayInteractor.replaying, false)
end

return test
