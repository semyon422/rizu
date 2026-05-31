local class = require("class")
local ClientRemoteValidation = require("sea.app.remotes.ClientRemoteValidation")
local NatsPeer = require("icc.nats.NatsPeer")
local Remote = require("icc.Remote")

---@class sea.InternalPeer
---@operator call: sea.InternalPeer
---@field user sea.User
---@field peer_id string ip:port
---@field remote sea.ClientRemoteValidation
---@field remote_no_return sea.ClientRemoteValidation
---@field peer sea.InternalPeer
local InternalPeer = class()

---@param th icc.TaskHandler
---@param nc nats.INats NATS connection
---@param inbox string caller's inbox subject prefix
---@param user sea.User
---@param peer_id string target peer ID
function InternalPeer:new(th, nc, inbox, user, peer_id)
	self.user = user
	self.peer_id = peer_id
	self.peer = self

	-- Create target-specific NATS peer
	local nats = NatsPeer(nc, inbox, peer_id)
	self.remote = ClientRemoteValidation(Remote(th, nats))
	self.remote_no_return = ClientRemoteValidation(-Remote(th, nats))
end

return InternalPeer
