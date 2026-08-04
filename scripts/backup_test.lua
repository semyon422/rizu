local test = {}

local function read(path)
	local file = assert(io.open(path, "rb"))
	local content = file:read("*a")
	file:close()
	return content
end

---@param t testing.T
function test.daily_timer_runs_at_fourteen_local_time(t)
	local timer = read("scripts/systemd/rizu-backup.timer")
	t:assert(timer:find("OnCalendar=*-*-* 14:00:00 Asia/Yekaterinburg", 1, true))
	t:assert(timer:find("Persistent=true", 1, true))
end

---@param t testing.T
function test.backup_scope_and_retention(t)
	local script = read("scripts/backup")
	t:assert(script:find('find \'$BACKUP_ROOT/database\'', 1, true))
	t:assert(script:find("-mtime +6 -delete", 1, true))
	t:assert(script:find('$state_root/storages/charts/', 1, true))
	t:assert(script:find('$state_root/storages/replays/', 1, true))
	t:eq(script:find("app_config.lua", 1, true), nil)
	t:eq(script:find("bancho_config.lua", 1, true), nil)
end

return test
