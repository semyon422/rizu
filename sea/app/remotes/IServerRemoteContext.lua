---@meta

---@class sea.IServerRemoteContext
---@field user sea.User
---@field session sea.Session
---@field ip string
---@field port integer
---@field peer_id string ip:port
---@field remote sea.ClientRemote
---@field remote_no_return sea.ClientRemote
---@field peer sea.Peer
local IServerRemoteContext = {}
