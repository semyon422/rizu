local class = require("class")

---@class rizu.ScoreSubmissionLog
---@operator call: rizu.ScoreSubmissionLog
---@field max_size integer
---@field path string
local ScoreSubmissionLog = class()

ScoreSubmissionLog.max_size = 1024 * 1024
ScoreSubmissionLog.path = "userdata/logs/score_submissions.log"

---@param fs fs.IFilesystem
function ScoreSubmissionLog:new(fs)
	self.fs = fs
	fs:createDirectory("userdata/logs")
end

---@param value any
---@return string
local function formatValue(value)
	local sanitized = (tostring(value):gsub("[\r\n\t]", " "))
	return sanitized
end

---@param event string
---@param fields {[string]: any}?
function ScoreSubmissionLog:write(event, fields)
	local parts = {
		os.date("!%Y-%m-%dT%H:%M:%SZ"),
		formatValue(event),
	}
	---@type string[]
	local keys = {}
	---@type {[string]: any}
	local entry_fields = fields or {}
	for key in pairs(entry_fields) do
		table.insert(keys, key)
	end
	table.sort(keys)
	for _, key in ipairs(keys) do
		table.insert(parts, formatValue(key) .. "=" .. formatValue(entry_fields[key]))
	end
	local line = table.concat(parts, "\t") .. "\n"

	local content = self.fs:read(self.path) or ""
	local keep_size = self.max_size - #line
	if keep_size < 0 then
		line = line:sub(#line - self.max_size + 1)
	elseif #content > keep_size then
		content = content:sub(#content - keep_size + 1)
		local newline = content:find("\n", 1, true)
		content = newline and content:sub(newline + 1) or ""
	end

	local ok, err = self.fs:write(self.path, content .. line)
	if not ok then
		print("score submission log write failed", err)
	end
end

return ScoreSubmissionLog
