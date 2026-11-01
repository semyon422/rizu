local Events = require("rizu.api.Events")

---`rizu.api.Online` for a logged in player with no avatar.
---@class rizu.api.fake.FakeOnline : rizu.api.Events
---@operator call: rizu.api.fake.FakeOnline
local FakeOnline = Events + {}

function FakeOnline:isConnected() return true end
function FakeOnline:isLoggedIn() return true end
function FakeOnline:isAuthenticationResolved() return true end
function FakeOnline:getUsername() return "Player" end
function FakeOnline:getAvatarUrl() return nil end
function FakeOnline:getOnlineCount() return 42 end
function FakeOnline:getOnlinePlayers()
	local players = {} ---@type rizu.api.Online.Player[]
	for i = 1, 42 do
		local role = i == 1 and "admin" or i % 5 == 0 and "donator" or nil
		players[i] = {name = "Player " .. i, role = role, chartplays_count = i * 37, play_time = i * 5400}
	end
	return players
end
function FakeOnline:getRecentScores()
	local scores = {} ---@type rizu.api.Online.RecentScore[]
	for i = 1, 10 do
		scores[i] = {player_name = "Player " .. i, title = "Song " .. i, difficulty = "4K Hard", accuracy = 1 - i / 100}
	end
	return scores
end
function FakeOnline:getAvatar(url) return nil end
function FakeOnline:login(email, password, f) f(true) end
function FakeOnline:logout() end

return FakeOnline
