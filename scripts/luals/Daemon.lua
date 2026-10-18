local bit = require("bit")
local json = require("json")
local posix = require("scripts.luals.posix")
local LanguageServer = require("scripts.luals.LanguageServer")

--- A background process that keeps one LuaLS workspace warm and answers JSON-line requests on a
--- Unix socket: {"action": "status" | "stop" | "diagnostics", "file": ..., "level": ...}.
local Daemon = {}

---@param root string
---@return string
local function base_path(root)
	local hash = 2166136261
	for i = 1, #root do
		hash = bit.bxor(hash, root:byte(i))
		-- FNV-1a prime 2^24 + 403, multiplied in parts so the double stays exact.
		hash = bit.tobit(bit.lshift(hash, 24) + hash * 403)
	end
	return ("%s/rizu-luals-%s"):format(os.getenv("TMPDIR") or "/tmp", bit.tohex(hash))
end

---@param root string
---@return string
function Daemon.socket_path(root)
	return base_path(root) .. ".sock"
end

---@param root string
---@return string
function Daemon.log_path(root)
	return base_path(root) .. ".daemon.log"
end

---@param root string
---@param request table
---@param timeout number seconds
---@return table? response
---@return string? error
function Daemon.request(root, request, timeout)
	local fd, err = posix.connect_unix(Daemon.socket_path(root))
	if not fd then
		return nil, err
	end
	local ok
	ok, err = posix.write_all(fd, json.encode(request) .. "\n")
	---@type string?
	local line
	if ok then
		line, err = posix.read_line(fd, timeout)
	end
	posix.close(fd)
	if not line then
		return nil, "no response from the LuaLS daemon: " .. err
	end
	local response = json.decode_safe(line)
	if type(response) ~= "table" then
		return nil, "invalid response from the LuaLS daemon"
	end
	return response
end

---@param server scripts.luals.LanguageServer
---@param root string
---@param request {[string]: any}
---@return table response
---@return boolean? stop
local function handle(server, root, request)
	if request.action == "status" then
		return {ok = true, project = root, pid = posix.getpid(), settled = server.workspace_diagnosed}
	elseif request.action == "stop" then
		return {ok = true, stopping = true, project = root}, true
	elseif request.action == "diagnostics" then
		local level = request.level or "Warning"
		if type(request.file) ~= "string" or not LanguageServer.levels[level] then
			error("expected a file and a level", 0)
		end
		local diagnostics = server:diagnostics(request.file, level)
		return {ok = true, file = request.file, diagnostics = json.array(diagnostics)}
	end
	error(("unknown action: %s"):format(request.action), 0)
end

--- Runs the daemon in this process until it is stopped.
---@param root string
---@param executable string
function Daemon.serve(root, executable)
	local path = Daemon.socket_path(root)
	local server = LanguageServer(executable, root, base_path(root) .. "-log")
	posix.unlink(path)
	local listener = assert(posix.listen_unix(path))
	print(("LuaLS daemon %d serving %s on %s"):format(posix.getpid(), root, path))
	io.stdout:flush()

	local ok, err = pcall(function()
		local stopping = false
		while not stopping do
			-- LuaLS output is always drained, or it blocks once the pipe is full.
			local ready = posix.poll({server.output, listener})
			if ready[server.output] then
				server:receive()
			end
			local client = ready[listener] and posix.accept(listener)
			if client then
				local line = posix.read_line(client, 5)
				local request = line and json.decode_safe(line)
				---@type table
				local response
				if type(request) == "table" then
					local handled, result, stop = pcall(handle, server, root, request)
					response = handled and result or {ok = false, error = tostring(result)}
					stopping = handled and stop or false
				else
					response = {ok = false, error = "invalid request"}
				end
				posix.write_all(client, json.encode(response) .. "\n")
				posix.close(client)
			end
		end
	end)

	posix.close(listener)
	posix.unlink(path)
	server:close()
	if not ok then
		error(err, 0)
	end
end

--- Starts the daemon in the background and waits until it has diagnosed the whole workspace, so
--- checks give the same results as later ones.
---@param root string
---@param command string[] runs `serve` for this project
---@return string message
function Daemon.start(root, command)
	local status = Daemon.request(root, {action = "status"}, 3)
	if status and status.ok then
		return ("LuaLS daemon already running for %s (pid %d)"):format(status.project, status.pid)
	end
	posix.unlink(Daemon.socket_path(root))

	local log_path = Daemon.log_path(root)
	local null = assert(posix.open("/dev/null"))
	local log = assert(posix.open(log_path, true))
	local pid = assert(posix.spawn(command, {stdin = null, stdout = log, stderr = log, new_session = true}))
	posix.close(null)
	posix.close(log)

	local deadline = posix.now() + 300
	while posix.now() < deadline do
		status = Daemon.request(root, {action = "status"}, 1)
		if status and status.ok and status.settled then
			return ("LuaLS daemon started for %s (pid %d)"):format(status.project, status.pid)
		end
		if posix.try_wait(pid) then
			error("the LuaLS daemon exited during startup; see " .. log_path, 0)
		end
		posix.poll({}, 0.2)
	end
	if status and status.ok then
		return ("LuaLS daemon started for %s (pid %d), still diagnosing the workspace"):format(status.project, status.pid)
	end
	posix.terminate(pid, 5)
	error("timed out starting the LuaLS daemon; see " .. log_path, 0)
end

return Daemon
