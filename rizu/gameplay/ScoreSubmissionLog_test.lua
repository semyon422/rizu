local FakeFilesystem = require("fs.FakeFilesystem")
local ScoreSubmissionLog = require("rizu.gameplay.ScoreSubmissionLog")

local test = {}

---@param t testing.T
function test.writes_structured_entries(t)
	local fs = FakeFilesystem()
	local log = ScoreSubmissionLog(fs)
	log:write("rejected", {
		replay_hash = "abc",
		error = "first line\nsecond line",
	})

	local content = assert(fs:read(ScoreSubmissionLog.path))
	t:assert(content:find("\trejected\t", 1, true))
	t:assert(content:find("error=first line second line", 1, true))
	t:assert(content:find("replay_hash=abc", 1, true))
end

---@param t testing.T
function test.mirrors_entries_to_console(t)
	local fs = FakeFilesystem()
	local log = ScoreSubmissionLog(fs)
	local old_print = print
	local printed
	_G.print = function(...)
		printed = table.concat({...}, " ")
	end
	log:write("accepted", {job_id = 42})
	_G.print = old_print

	t:assert(printed:find("score submission", 1, true))
	t:assert(printed:find("\taccepted\t", 1, true))
	t:assert(printed:find("job_id=42", 1, true))
end

---@param t testing.T
function test.preserves_recent_entries_within_size_limit(t)
	local fs = FakeFilesystem()
	local log = ScoreSubmissionLog(fs)
	log.max_size = 100
	log:write("old", {message = string.rep("a", 70)})
	log:write("new", {message = string.rep("b", 40)})

	local content = assert(fs:read(ScoreSubmissionLog.path))
	t:assert(#content <= log.max_size)
	t:assert(content:find("\tnew\t", 1, true))
	t:assert(not content:find("\told\t", 1, true))
end

return test
