local class = require("class")
local config = require("rizu.build.package.config")

local RepoAssembler = require("rizu.build.package.RepoAssembler")
local UpdateIndexWriter = require("rizu.build.package.UpdateIndexWriter")
local ZipPackager = require("rizu.build.package.ZipPackager")
local MacOSPackager = require("rizu.build.package.MacOSPackager")

local _name = config.repo.name

---@class rizu.build.package.RepoBuilder
---@operator call: rizu.build.package.RepoBuilder
---@field assembler rizu.build.package.RepoAssembler
---@field update_index_writer rizu.build.package.UpdateIndexWriter
---@field zip_packager rizu.build.package.ZipPackager
---@field macos_packager rizu.build.package.MacOSPackager
local RepoBuilder = class()

---@param ctx rizu.build.Context
---@param git_repo repo.CurrentRepo
---@param src_fs? fs.IFilesystem
function RepoBuilder:new(ctx, git_repo, src_fs)
	self.assembler = RepoAssembler(ctx, git_repo, src_fs)
	self.update_index_writer = UpdateIndexWriter(ctx)
	self.zip_packager = ZipPackager(ctx)
	self.macos_packager = MacOSPackager(ctx, src_fs)
end

---@return nil
function RepoBuilder:buildGenericRepo()
	self.assembler:build()
end

---@return nil
function RepoBuilder:build()
	self:buildGenericRepo()
	self.update_index_writer:write("build/repo/" .. _name)
end

---@return nil
function RepoBuilder:build_zip()
	self.zip_packager:build()
end

---@return nil
function RepoBuilder:buildMacos()
	self.macos_packager:build()
end

return RepoBuilder
