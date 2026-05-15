local class = require("class")
local stbl = require("stbl")
local zlib = require("zlib")
local json = require("json")
local config = require("rizu.build.package.config")
local fs_util = require("fs.util")

---@class rizu.build.package.UpdateIndexWriter
---@operator call: rizu.build.package.UpdateIndexWriter
---@field ctx rizu.build.Context
local UpdateIndexWriter = class()

---@param ctx rizu.build.Context
function UpdateIndexWriter:new(ctx)
	self.ctx = ctx
end

local function serialize(t)
	return ("return %s\n"):format(stbl.encode(t))
end

---@param gamerepo string
function UpdateIndexWriter:write(gamerepo)
	local files = {}
	fs_util.find(gamerepo, self.ctx.fs, function(path)
		local content = self.ctx.fs:read(path)
		if content then
			local rel_path = path:sub(#gamerepo + 2)
			table.insert(files, {
				path = rel_path,
				url = config.game.repo .. "/" .. rel_path,
				hash = zlib.crc32(0, content),
			})
		end
	end)

	self.ctx.fs:createDirectory(gamerepo .. "/userdata")
	self.ctx.fs:write(gamerepo .. "/userdata/files.lua", serialize(files))
	self.ctx.fs:write("build/repo/files.json", json.encode(files))
	assert(self.ctx.fs:getInfo("build/repo/files.json") ~= nil, "missing files.json")
end

return UpdateIndexWriter
