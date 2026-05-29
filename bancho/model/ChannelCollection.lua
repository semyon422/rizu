--- Channel registry.
---
--- Accepts an optional `web.ISharedDict` for cross-worker persistence.
--- When a dict is provided, channel data is stored as flat JSON-compatible
--- tables keyed by `"c:<real_name>"`.
--- When no dict is provided, falls back to in-memory tables (for tests).

local Channel = require("bancho.model.Channel")

local class = require("class")

---@class bancho.model.ChannelCollection
---@operator call: bancho.model.ChannelCollection
---@field _dict? web.ISharedDict
---@field _list bancho.model.Channel[]
---@field _by_name {[string]: bancho.model.Channel}
local ChannelCollection = class()

---@param dict? web.ISharedDict Shared dict for cross-worker persistence
function ChannelCollection:new(dict)
	self._dict = dict
	self._list = {}
	self._by_name = {}
	return self
end

--- Get a channel by name.
---@param name string
---@return bancho.model.Channel?
function ChannelCollection:get(name)
	if self._dict then
		local data = self._dict:get("c:" .. name)
		if data then
			return Channel:fromData(data)
		end
		return nil
	end

	return self._by_name[name]
end

--- Add a channel.
---@param channel bancho.model.Channel
function ChannelCollection:add(channel)
	if self._dict then
		self._dict:set("c:" .. channel.real_name, channel:toData())
		return
	end

	table.insert(self._list, channel)
	self._by_name[channel.real_name] = channel
end

--- Remove a channel.
---@param channel bancho.model.Channel
function ChannelCollection:remove(channel)
	if self._dict then
		self._dict:delete("c:" .. channel.real_name)
		return
	end

	self._by_name[channel.real_name] = nil

	for i = 1, #self._list do
		if self._list[i] == channel then
			table.remove(self._list, i)
			break
		end
	end
end

--- Send a message to all players in a channel.
--- For dict-backed collections, uses PlayerCollection:enqueue() via player queue.
--- For in-memory collections, calls Player:enqueue() directly.
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
	if self._dict then
		---@type bancho.model.Channel[]
		local result = {}
		local keys = self._dict:get_keys()
		for _, key in ipairs(keys) do
			if type(key) == "string" and key:sub(1, 2) == "c:" then
				local data = self._dict:get(key)
				if data then
					table.insert(result, Channel:fromData(data))
				end
			end
		end
		return result
	end

	return self._list
end

--- Return the number of channels.
---@return integer
function ChannelCollection:len()
	if self._dict then
		return #self:all()
	end
	return #self._list
end

return ChannelCollection
