local class = require("class")

---@class repo.CurrentRepo
---@operator call: repo.CurrentRepo
local CurrentRepo = class()

---@param ctx build.Context
function CurrentRepo:new(ctx)
	self.ctx = ctx
end

function CurrentRepo:getDirName()
	return "." -- We run from root
end

function CurrentRepo:log_date()
	local res = self.ctx.shell:popen("git log -1 --format=%cd")
	return res and res:match("^%s*(.+)%s*\n.*$") or "unknown"
end

function CurrentRepo:log_commit()
	local res = self.ctx.shell:popen("git log -1 --format=%H")
	return res and res:match("^%s*(.+)%s*\n.*$") or "unknown"
end

return CurrentRepo
