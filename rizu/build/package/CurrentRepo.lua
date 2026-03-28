local class = require("class")

---@class repo.CurrentRepo
---@operator call: repo.CurrentRepo
---@field ctx rizu.build.Context
local CurrentRepo = class()

---@param ctx rizu.build.Context
function CurrentRepo:new(ctx)
	self.ctx = ctx
end

---@return string
function CurrentRepo:getDirName()
	return "." -- We run from root
end

---@return string
function CurrentRepo:log_date()
	local res = self.ctx.shell:popen("git log -1 --format=%cd")
	return res and res:match("^%s*(.+)%s*\n.*$") or "unknown"
end

---@return string
function CurrentRepo:log_commit()
	local res = self.ctx.shell:popen("git log -1 --format=%H")
	return res and res:match("^%s*(.+)%s*\n.*$") or "unknown"
end

return CurrentRepo
