local class = require("class")
local Observable = require("Observable")

---@class rizu.online.UserChangedEvent
---@field type "user_changed"
---@field user sea.User?

---@class rizu.online.ConnectionChangedEvent
---@field type "connection_changed"
---@field connected boolean

---@class rizu.online.AuthenticationResolvedEvent
---@field type "authentication_resolved"

---@class rizu.online.LoginStartedEvent
---@field type "login_started"

---@class rizu.online.LoginSucceededEvent
---@field type "login_succeeded"
---@field user sea.User

---@class rizu.online.LoginFailedEvent
---@field type "login_failed"
---@field error string

---@alias rizu.online.Event rizu.online.UserChangedEvent|rizu.online.ConnectionChangedEvent|rizu.online.AuthenticationResolvedEvent|rizu.online.LoginStartedEvent|rizu.online.LoginSucceededEvent|rizu.online.LoginFailedEvent
---@alias rizu.online.EventObserver {receive: fun(self: table, event: rizu.online.Event)}
---@alias rizu.online.EventReceiver fun(event: rizu.online.Event)

---@class rizu.OnlineClient
---@operator call: rizu.OnlineClient
---@field user sea.User?
---@field connected boolean
---@field authentication_resolved boolean
---@field observable util.Observable
---@field leaderboards sea.Leaderboard[]
---@field leaderboard_users sea.LeaderboardUser[]
local OnlineClient = class()

function OnlineClient:new()
	self.connected = false
	self.authentication_resolved = false
	self.observable = Observable()
	self.leaderboards = {}
	self.leaderboards_users = {}
	self.completed_chartplay_ids = {}
end

---@param user sea.User?
function OnlineClient:setUser(user)
	if self.user == user then
		return
	end
	self.user = user
	self.observable:send({type = "user_changed", user = user})
end

---@return sea.User?
function OnlineClient:getUser()
	return self.user
end

---@param connected boolean
function OnlineClient:setConnected(connected)
	if self.connected == connected then
		return
	end
	self.connected = connected
	self.authentication_resolved = false
	self.observable:send({type = "connection_changed", connected = connected})
end

---@return boolean
function OnlineClient:isConnected()
	return self.connected
end

function OnlineClient:authenticationResolved()
	if self.authentication_resolved then return end
	self.authentication_resolved = true
	self.observable:send({type = "authentication_resolved"})
end

---@return boolean
function OnlineClient:isAuthenticationResolved()
	return self.authentication_resolved
end

function OnlineClient:loginStarted()
	self.observable:send({type = "login_started"})
end

---@param user sea.User
function OnlineClient:loginSucceeded(user)
	self.observable:send({type = "login_succeeded", user = user})
end

---@param err string
function OnlineClient:loginFailed(err)
	self.observable:send({type = "login_failed", error = err})
end

---@param observer rizu.online.EventObserver|rizu.online.EventReceiver
---@return util.Observer
function OnlineClient:onChanged(observer)
	---@cast observer util.Observer|util.EventReceiver
	return self.observable:add(observer)
end

---@param observer util.Observer
---@return util.Observer?
function OnlineClient:offChanged(observer)
	return self.observable:remove(observer)
end

---@param leaderboards sea.Leaderboard[]
function OnlineClient:setLeaderboards(leaderboards)
	self.leaderboards = leaderboards
end

---@param leaderboards_users sea.LeaderboardUser[]
function OnlineClient:setLeaderboardUsers(leaderboards_users)
	self.leaderboards_users = leaderboards_users
end

---@param chartplay_id integer
function OnlineClient:chartplaySubmissionCompleted(chartplay_id)
	table.insert(self.completed_chartplay_ids, chartplay_id)
end

---@param lb_id integer
---@return sea.Leaderboard?
function OnlineClient:getLeaderboard(lb_id)
	for _, lb in ipairs(self.leaderboards) do
		if lb.id == lb_id then
			return lb
		end
	end
end

---@param lb_id integer
---@return sea.LeaderboardUser?
function OnlineClient:getLeaderboardUser(lb_id)
	for _, lu in ipairs(self.leaderboards_users) do
		if lu.leaderboard_id == lb_id then
			return lu
		end
	end
end

return OnlineClient
