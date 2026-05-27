--- In-memory channel registry.

local Channel = require("bancho.model.Channel")

local class = require("class")

---@class bancho.model.ChannelCollection
---@operator call: bancho.model.ChannelCollection
---@field _list bancho.model.Channel[]
---@field _by_name {[string]: bancho.model.Channel}
local ChannelCollection = class()

function ChannelCollection:new()
	self._list = {}
	self._by_name = {}
	return self
end

--- Get a channel by name.
---@param name string
---@return bancho.model.Channel?
function ChannelCollection:get(name)
	return self._by_name[name]
end

--- Add a channel.
---@param channel bancho.model.Channel
function ChannelCollection:add(channel)
	table.insert(self._list, channel)
	self._by_name[channel.real_name] = channel
end

--- Remove a channel.
---@param channel bancho.model.Channel
function ChannelCollection:remove(channel)
	self._by_name[channel.real_name] = nil

	for i = 1, #self._list do
		if self._list[i] == channel then
			table.remove(self._list, i)
			break
		end
	end
end

--- Send a message to all players in a channel.
---@param channel bancho.model.Channel
---@param msg string
---@param sender bancho.model.Player
function ChannelCollection:sendTo(channel, msg, sender)
	for _, p in pairs(channel.players) do
		if p.id ~= sender.id then
			p:enqueue(msg)
		end
	end
end

--- Return the list of all channels.
---@return bancho.model.Channel[]
function ChannelCollection:all()
	return self._list
end

--- Return the number of channels.
---@return integer
function ChannelCollection:len()
	return #self._list
end

return ChannelCollection
