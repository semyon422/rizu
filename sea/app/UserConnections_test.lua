local UserConnections = require("sea.app.UserConnections")
local UserConnectionsRepo = require("sea.app.repos.UserConnectionsRepo")
local FakeSharedDict = require("web.nginx.FakeSharedDict")
local NatsPeer = require("icc.nats.NatsPeer")
local Message = require("icc.Message")
local StringBufferPeer = require("icc.StringBufferPeer")
local User = require("sea.access.User")

local buffer_peer = StringBufferPeer()

local test = {}

local TestNats = require("icc.nats.TestNats")

--- Simulate the full two-way call flow:
--- 1. Connection 1 calls peer2.remote:getRandomNumber() via NATS
--- 2. Connection 2 receives via NATS, handles call, responds via NATS
--- 3. Connection 1 receives response via NATS inbox, coroutine resumes
---@param t testing.T
function test.full_call(t)
	local dict = FakeSharedDict()
	local repo = UserConnectionsRepo(dict)
	local users_repo = {
		getUser = function(self, id)
			local u = User()
			u.id = id
			u.name = "user" .. id
			return u
		end
	}
	local uc = UserConnections(repo, users_repo)

	-- Setup handlers
	local tbl = {
		getRandomNumber = function(self)
			return 42
		end
	}
	local whitelist = {getRandomNumber = true}
	local nc = TestNats()
	uc:setup(tbl, whitelist, whitelist, nc)

	local sid1 = "1.1.1.1:1"
	local sid2 = "2.2.2.2:2"

	uc:onConnect(sid1, 1)
	uc:onConnect(sid2, 2)

	-- Connection 1's inbox subscription (for receiving responses)
	nc:subscribe("icc.inbox." .. sid1 .. ".*", function(nats_msg)
		local id = tonumber(nats_msg.subject:match("^.+%.(%d+)$"))
		if not id then return end

		local decoded = buffer_peer:decode(nats_msg.payload)
		if not decoded then return end

		---@type icc.Message
		local msg = setmetatable({
			id = id,
			ret = true,
			n = decoded.n or 0,
		}, {__index = Message})
		for i = 1, msg.n do
			msg[i] = decoded[i]
		end

		uc.task_handler:handleReturn(msg)
	end)

	-- Connection 2's peer subscription (for receiving calls)
	nc:subscribe("icc.peer." .. sid2, function(nats_msg)
		local msg = buffer_peer:decode(nats_msg.payload)
		if not msg then return end

		msg.reply_to = nats_msg.reply_to

		-- Connection 2 handles the call and responds via NATS
		local th = uc:createClientTaskHandler(tbl)
		local reply_peer = nats_msg.reply_to and NatsPeer(nc, nil, nats_msg.reply_to) or nil
		th:handleCall(reply_peer or {}, {}, msg)
	end)

	-- Connection 1 calls Connection 2
	local peer2_from_1 = uc:getPeer(sid2, {nc = nc, inbox = "icc.inbox." .. sid1})
	---@cast peer2_from_1 -?

	---@type integer?
	local result
	local done = false
	coroutine.wrap(function()
		result = peer2_from_1.remote:getRandomNumber()
		done = true
	end)()

	-- Flush pending NATS messages (simulates async delivery after yield)
	nc:flush()

	t:assert(done)
	t:eq(result, 42)
end

---@param t testing.T
function test.get_peer(t)
	local dict = FakeSharedDict()
	local repo = UserConnectionsRepo(dict)
	local users_repo = {
		getUser = function(self, id)
			local u = User()
			u.id = id
			u.name = "user" .. id
			return u
		end
	}
	local uc = UserConnections(repo, users_repo)

	local tbl = {
		getRandomNumber = function(self)
			return 42
		end
	}
	local whitelist = {getRandomNumber = true}
	local nc = TestNats()
	uc:setup(tbl, whitelist, whitelist, nc)

	local sid1 = "1.1.1.1:1"
	local sid2 = "2.2.2.2:2"

	uc:onConnect(sid1, 1)
	uc:onConnect(sid2, 2)

	-- Connection 1 wants to call Connection 2
	local peer2_from_1 = uc:getPeer(sid2, {nc = nc, inbox = "icc.inbox." .. sid1})
	---@cast peer2_from_1 -?

	t:eq(peer2_from_1.peer_id, sid2)
	t:eq(peer2_from_1.user.id, 2)
end

---@param t testing.T
function test.get_peers(t)
	local dict = FakeSharedDict()
	local repo = UserConnectionsRepo(dict)
	local users_repo = {
		getUser = function(self, id)
			local u = User()
			u.id = id
			u.name = "user" .. id
			return u
		end
	}
	local uc = UserConnections(repo, users_repo)

	local tbl = {}
	local whitelist = {}
	local nc = TestNats()
	uc:setup(tbl, whitelist, whitelist, nc)

	uc:onConnect("1.1.1.1:1", 1)
	uc:onConnect("2.2.2.2:2", 2)
	uc:onConnect("3.3.3.3:3", 3)

	local peers = uc:getPeers({nc = nc, inbox = "icc.inbox.caller"})

	t:eq(#peers, 3)
	for _, peer in ipairs(peers) do
		t:assert(peer.user ~= nil)
		t:assert(peer.peer_id ~= nil)
	end
end

return test
