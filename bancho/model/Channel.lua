--- Chat channel representation.

local Privileges = require("bancho.constants.Privileges")

local class = require("class")

---@class bancho.model.Channel
---@field name string
---@field real_name string
---@field topic string
---@field players table<integer, any> player id -> player
---@field read_priv integer
---@field write_priv integer
---@field auto_join boolean
---@field instance boolean (auto-delete when empty)
local Channel = class()

function Channel:new(name, topic, read_priv, write_priv, auto_join, instance)
	self.real_name = name
	self.name = name
	self.topic = topic
	self.players = {}
	self.read_priv = read_priv or Privileges.UNRESTRICTED
	self.write_priv = write_priv or Privileges.UNRESTRICTED
	self.auto_join = auto_join ~= false
	self.instance = instance or false
	return self
end

function Channel:contains(player)
	if type(player) == "string" then
		return self.players[player] ~= nil
	else
		return self.players[player.id] ~= nil
	end
end

function Channel:canRead(priv)
	if self.read_priv == 0 then return true end
	return bit.band(priv, self.read_priv) ~= 0
end

function Channel:canWrite(priv)
	if self.write_priv == 0 then return true end
	return bit.band(priv, self.write_priv) ~= 0
end

function Channel:add(player)
	self.players[player.id] = player
end

function Channel:remove(player)
	self.players[player.id] = nil
end

return Channel
