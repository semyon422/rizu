--- Repository stub for testing.
---
--- Provides in-memory storage for users, scores, and beatmaps.

local class = require("class")

---@class bancho.stub.Repo
---@operator call: bancho.stub.Repo
local Repo = class()

function Repo:new()
	---@type {[integer]: table} id -> user record
	self._users = {}
	---@type {[string]: table[]} md5 -> score records
	self._scores = {}
	---@type {[string]: table} md5 -> beatmap record
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

--- Find a user by name and verify password.
--- Stub: direct comparison (real impl uses bcrypt.verify).
---@param name string
---@param password_md5 string
---@return table?
function Repo:findUserByNameAndPassword(name, password_md5)
	local user = self:findUserByName(name)
	if user and user.pw_bcrypt == password_md5 then
		return user
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
	---@type table[]
	local result = {}
	for _, s in ipairs(scores) do
		if s.mode == mode then
			table.insert(result, s)
		end
	end
	return result
end

--- Find best score for a user on a map.
---@param map_md5 string
---@param user_id integer
---@param mode integer
---@return table?
function Repo:findBestScore(map_md5, user_id, mode)
	local scores = self._scores[map_md5] or {}
	---@type table?
	local best = nil
	for _, s in ipairs(scores) do
		if s.user_id == user_id and s.mode == mode then
			if not best or (s.pp or 0) > (best.pp or 0) then
				best = s
			end
		end
	end
	return best
end

--- Add a score.
---@param score table
---@return integer score_id
function Repo:addScore(score)
	if not self._scores[score.map_md5] then
		self._scores[score.map_md5] = {}
	end
	score.id = #self._scores[score.map_md5] + 1
	table.insert(self._scores[score.map_md5], score)
	return score.id
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
