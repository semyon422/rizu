local class = require("class")
local config = require("rizu.build.package.config")
local ArchiveUtil = require("rizu.build.package.ArchiveUtil")

local _name = config.repo.name

---@class rizu.build.package.ZipPackager
---@operator call: rizu.build.package.ZipPackager
---@field ctx rizu.build.Context
local ZipPackager = class()

---@param ctx rizu.build.Context
function ZipPackager:new(ctx)
	self.ctx = ctx
end

function ZipPackager:build()
	self.ctx.shell:execute(string.format("bash -lc 'cd %q && zip -qry %q %q'", "build/repo", _name .. ".zip", _name))
	local zip_path = "build/repo/" .. _name .. ".zip"
	assert(self.ctx.fs:getInfo(zip_path) ~= nil, "missing repo zip: " .. zip_path)
	local repo_zip_listing = ArchiveUtil.getZipListing(self.ctx, zip_path)
	assert(ArchiveUtil.hasEntry(repo_zip_listing, _name .. "/game.love"), "repo zip is missing " .. _name .. "/game.love")
end

return ZipPackager
