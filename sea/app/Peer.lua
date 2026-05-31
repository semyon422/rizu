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
	self.user = user
	self.peer_id = peer_id
	self.peer = self
	self.ip = ip
	self.port = port
	self.session = session
	-- Local peer: remote calls go through WebSocket
	self.remote = ClientRemoteValidation(Remote(th, ws_peer))
	self.remote_no_return = ClientRemoteValidation(-Remote(th, ws_peer))
end

return Peer
