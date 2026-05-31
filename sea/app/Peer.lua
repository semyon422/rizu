local class = require("class")
local ClientRemoteValidation = require("sea.app.remotes.ClientRemoteValidation")
local Remote = require("icc.Remote")

---@class sea.Peer
---@field nc nats.INats NATS connection (for passing to InternalPeer)
---@field inbox string caller's inbox subject (for passing to InternalPeer)
---@field ip string
---@field port integer
---@field session sea.Session?
---@field user sea.User
---@field peer_id string
---@field peer sea.Peer
---@field remote sea.ClientRemoteValidation
---@field remote_no_return sea.ClientRemoteValidation
---@field ws_peer icc.WebsocketPeer WebSocket peer (for decode and one-way sends)
---@field broadcast_sids {[string]: integer} NATS subscription SIDs keyed by subject, cleaned up on disconnect
---@field dispatch_nats fun(nats_msg: {subject: string, reply_to?: string, payload: string}) NATS message dispatcher (set by setup_dispatch)
---@operator call: sea.Peer
local Peer = class()

---@param th icc.TaskHandler
---@param ws_peer icc.IPeer WebSocket peer (for sending to this connection)
---@param nc nats.INats NATS connection
---@param inbox string caller's inbox subject
---@param user sea.User
---@param ip string
---@param port integer
---@param peer_id string
---@param session sea.Session?
function Peer:new(th, ws_peer, nc, inbox, user, ip, port, peer_id, session)
	self.nc = nc
	self.inbox = inbox
	self.ws_peer = ws_peer
	self.user = user
	self.peer_id = peer_id
	self.peer = self
	self.ip = ip
	self.port = port
	self.session = session
	self.broadcast_sids = {} ---@type {[string]: integer}
	self.dispatch_nats = nil
	-- Local peer: remote calls go through WebSocket
	self.remote = ClientRemoteValidation(Remote(th, ws_peer))
	self.remote_no_return = ClientRemoteValidation(-Remote(th, ws_peer))
end

--- Set up the NATS dispatcher for server→client messages.
--- Must be called after the peer is created so client_task_handler exists.
---@param client_task_handler icc.TaskHandler
function Peer:setup_dispatch(client_task_handler)
	self.dispatch_nats = function(nats_msg)
		local msg = self.ws_peer:decode(nats_msg.payload)
		if not msg then return end
		msg.reply_to = nats_msg.reply_to
		local NatsPeer = require("icc.nats.NatsPeer")
		local reply_peer = nats_msg.reply_to and NatsPeer(self.nc, nil, nats_msg.reply_to) or self.ws_peer
		local ok, err = xpcall(client_task_handler.handleCall, debug.traceback,
			client_task_handler, reply_peer, {}, msg)
		if not ok then
			print("nats dispatch error", err)
		end
	end
end

--- Subscribe this peer to a NATS broadcast subject.
--- Tracks the SID for cleanup on disconnect. Idempotent.
---@param subject string
function Peer:subscribe(subject)
	if self.broadcast_sids[subject] then
		return
	end
	local sid
	_, _, sid = self.nc:subscribe(subject, self.dispatch_nats)
	self.broadcast_sids[subject] = sid
end

--- Unsubscribe this peer from a NATS broadcast subject.
---@param subject string
function Peer:unsubscribe(subject)
	local sid = self.broadcast_sids[subject]
	if sid then
		self.nc:unsubscribe(sid)
		self.broadcast_sids[subject] = nil
	end
end

return Peer
