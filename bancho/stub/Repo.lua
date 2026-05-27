--- Repository stub for testing.
---
--- Provides in-memory storage for users, scores, and beatmaps.

local class = require("class")

---@class bancho.stub.Repo
local Repo = class()

function Repo:new()
	---@type table<integer, table> id -> user record
	self._users = {}
	---@type table<string, table[]> md5 -> score records
	self._scores = {}
	---@type table<string, table> md5 -> beatmap record
	self._beatmaps = {}
	return self
end

--- Find a user by id.
---@param id integer
---@return table?
function Repo:findUser(id)
	return self._users[id]
end

--- Find a user by name.
---@param name string
---@return table?
function Repo:findUserByName(name)
	for _, u in pairs(self._users) do
		if u.name:lower() == name:lower() then
			return u
		end
	end
	return nil
end

--- Add a user.
---@param user table
function Repo:addUser(user)
	self._users[user.id] = user
end

--- Find scores by map md5 and mode.
---@param map_md5 string
---@param mode integer
---@return table[]
function Repo:findScores(map_md5, mode)
	local scores = self._scores[map_md5] or {}
	local result = {}
	for _, s in ipairs(scores) do
		if s.mode == mode then
			table.insert(result, s)
		end
	end
	return result
end

--- Add a score.
---@param map_md5 string
---@param score table
function Repo:addScore(map_md5, score)
	if not self._scores[map_md5] then
		self._scores[map_md5] = {}
	end
	table.insert(self._scores[map_md5], score)
end

--- Find a beatmap by md5.
---@param md5 string
---@return table?
function Repo:findBeatmap(md5)
	return self._beatmaps[md5]
end

--- Add a beatmap.
---@param bmap table
function Repo:addBeatmap(bmap)
	self._beatmaps[bmap.md5] = bmap
end

return Repo
