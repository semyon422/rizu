local fs_util = require("fs.util")

---@class rizu.build.package.FileCopier
local FileCopier = {}

---@param ctx rizu.build.Context
---@param src string
---@param dst string
---@param src_fs? fs.IFilesystem
function FileCopier.copy(ctx, src, dst, src_fs)
	src_fs = src_fs or ctx.fs
	assert(fs_util.copy(src, dst, src_fs, ctx.fs))
	fs_util.find(src, src_fs, function(path)
		local target = dst .. path:sub(#src + 1)
		ctx.shell:execute(string.format("chmod --reference=%q -- %q", path, target))
	end)
end

return FileCopier
