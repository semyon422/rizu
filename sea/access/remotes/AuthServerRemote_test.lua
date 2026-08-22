local AuthServerRemote = require("sea.access.remotes.AuthServerRemote")
local Session = require("sea.access.Session")
local User = require("sea.access.User")

local test = {}

---@param t testing.T
function test.login_by_token_accepts_signed_session_csrf_field(t)
	local stored_session = Session()
	stored_session.id = 10
	stored_session.user_id = 20
	stored_session.active = true
	stored_session.created_at = 30
	stored_session.updated_at = 40

	local users = {
		checkSession = function(_, session)
			t:eq(session.csrf_token, nil)
			t:eq(session.id, stored_session.id)
			return stored_session
		end,
		getUser = function()
			local user = User()
			user.id = stored_session.user_id
			return user
		end,
	}
	local sessions = {
		decode = function()
			return {
				id = 10,
				user_id = 20,
				active = true,
				created_at = 30,
				updated_at = 40,
				csrf_token = "signed-web-session-field",
			}
		end,
	}
	local heartbeats = {}
	local user_connections = {
		heartbeat = function(_, peer_id, user_id)
			table.insert(heartbeats, {peer_id, user_id})
		end,
	}
	local remote = AuthServerRemote(users --[[@as sea.Users]], sessions --[[@as web.Sessions]], user_connections --[[@as sea.UserConnections]])
	remote.session = Session()
	remote.user = User()
	remote.peer_id = "peer"

	t:eq(remote:loginByToken("token"), true)
	t:eq(remote.session.id, stored_session.id)
	t:eq(remote.user.id, stored_session.user_id)
	t:tdeq(heartbeats, {{"peer", stored_session.user_id}})
end

return test
