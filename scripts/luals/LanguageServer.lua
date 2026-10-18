local class = require("class")
local json = require("json")
local posix = require("scripts.luals.posix")

local SEVERITY_NAMES = {"error", "warning", "information", "hint"}
local SEVERITY_LEVELS = {Error = 1, Warning = 2, Information = 3, Hint = 4}

---@class scripts.luals.Diagnostic
---@field severity string
---@field line integer
---@field column integer
---@field endLine integer
---@field endColumn integer
---@field code any string, or json.null
---@field source any string, or json.null
---@field message string

--- One LuaLS process speaking LSP over its standard streams, with the project as its workspace.
---@class scripts.luals.LanguageServer
---@operator call: scripts.luals.LanguageServer
local LanguageServer = class()

LanguageServer.levels = SEVERITY_LEVELS

---@param executable string
---@param root string
---@param log_dir string
function LanguageServer:new(executable, root, log_dir)
	self.root = root
	self.next_id = 0
	self.buffer = ""
	---@type {[integer]: table}
	self.responses = {}
	--- LuaLS only pushes diagnostics when they differ from its last push for that file, so every
	--- push is kept, including the ones from the background workspace scan.
	---@type {[string]: table[]}
	self.published = {}
	---@type {[string]: integer}
	self.versions = {}
	self.workspace_ready = false
	--- True once LuaLS has diagnosed every workspace file in the background. Until then a file's
	--- inferred types can still change as LuaLS compiles the files around it.
	self.workspace_diagnosed = false

	posix.run({"mkdir", "-p", log_dir})
	-- See sync_changes().
	self.stamp = log_dir .. "/changes.stamp"
	assert(io.open(self.stamp, "wb")):close()
	self.known_files = self:find_files()
	--- Files that existed when LuaLS scanned the workspace.
	self.scanned_files = self.known_files
	--- Files LuaLS only knows about because they are open.
	---@type {[string]: true}
	self.kept_open = {}
	local stdin_read, stdin_write = assert(posix.pipe())
	local stdout_read, stdout_write = assert(posix.pipe())
	---@cast stdin_write integer
	---@cast stdout_write integer
	local stderr = assert(posix.open(log_dir .. "/server.stderr.log", true))
	self.pid = assert(posix.spawn({
		executable,
		"--logpath=" .. log_dir,
		"--loglevel=error",
		"--configpath=" .. root .. "/.luarc.json",
		-- Enables the textDocument/diagnostic handler used by diagnostics().
		"--preview=true",
	}, {stdin = stdin_read, stdout = stdout_write, stderr = stderr}))
	posix.close(stdin_read)
	posix.close(stdout_write)
	posix.close(stderr)
	self.input = stdin_write
	self.output = stdout_read

	self:initialize()
end

---@param message table
function LanguageServer:send(message)
	message.jsonrpc = "2.0"
	local body = json.encode(message)
	assert(posix.write_all(self.input, ("Content-Length: %d\r\n\r\n%s"):format(#body, body)))
end

---@param method string
---@param params table?
---@return integer id
function LanguageServer:request(method, params)
	self.next_id = self.next_id + 1
	self:send({id = self.next_id, method = method, params = params})
	return self.next_id
end

---@param method string
---@param params table?
function LanguageServer:notify(method, params)
	self:send({method = method, params = params})
end

---@param message {[string]: any}
function LanguageServer:handle(message)
	local method = message.method
	if method and message.id ~= nil then
		---@type any
		local result = json.null
		if method == "workspace/configuration" then
			local items = message.params and message.params.items or {}
			---@type table[]
			local configurations = {}
			for i = 1, #items --[[@as integer]] do
				configurations[i] = json.object({})
			end
			result = json.array(configurations)
		elseif method == "workspace/workspaceFolders" then
			result = json.array({{uri = self:uri(self.root), name = self.root:match("[^/]+$")}})
		end
		self:send({id = message.id, result = result})
	elseif method == "textDocument/publishDiagnostics" then
		self.published[message.params.uri] = message.params.diagnostics
	elseif method == "$/progress" then
		---@type {[string]: any}
		local params = message.params
		local value = params.value or {}
		if value.kind == "begin" and value.title == "Loading workspace" then
			self.loading_token = params.token
		elseif value.kind == "begin" and value.title == "Diagnosing workspace" then
			self.diagnosing_token = params.token
		elseif value.kind == "end" and params.token == self.loading_token then
			self.workspace_ready = true
		elseif value.kind == "end" and params.token == self.diagnosing_token then
			self.workspace_diagnosed = true
		end
	elseif message.id ~= nil then
		self.responses[message.id] = message
	end
end

--- Reads and handles every complete message LuaLS has written so far.
function LanguageServer:receive()
	local chunk, err = posix.read(self.output)
	if not chunk then
		error("LuaLS protocol error: " .. err)
	elseif chunk == "" then
		error("LuaLS exited unexpectedly")
	end
	self.buffer = self.buffer .. chunk
	while true do
		local header_end = self.buffer:find("\r\n\r\n", 1, true)
		if not header_end then
			return
		end
		local length = tonumber(self.buffer:sub(1, header_end):match("[Cc]ontent%-[Ll]ength:%s*(%d+)"))
		if not length then
			error("LuaLS protocol error: missing Content-Length")
		end
		local body_end = header_end + 3 + length
		if #self.buffer < body_end then
			return
		end
		local body = self.buffer:sub(header_end + 4, body_end)
		self.buffer = self.buffer:sub(body_end + 1)
		self:handle(json.decode(body))
	end
end

--- Keeps handling LuaLS messages until `done()` is true.
---@param done fun(): any
---@param timeout number seconds
---@param what string
function LanguageServer:wait(done, timeout, what)
	local deadline = posix.now() + timeout
	while not done() do
		local remaining = deadline - posix.now()
		if remaining <= 0 then
			error("timed out waiting for LuaLS " .. what)
		end
		if posix.poll({self.output}, remaining)[self.output] then
			self:receive()
		end
	end
end

---@param id integer
---@param timeout number
---@param what string
---@return table
function LanguageServer:wait_response(id, timeout, what)
	self:wait(function() return self.responses[id] end, timeout, what)
	local response = self.responses[id]
	self.responses[id] = nil
	if response.error then
		error(("LuaLS %s failed: %s"):format(what, response.error.message or json.encode(response.error)))
	end
	return response
end

---@param path string absolute
---@return string
function LanguageServer:uri(path)
	return "file://" .. path:gsub("[^%w%-%._~/]", function(c)
		return ("%%%02X"):format(c:byte())
	end)
end

function LanguageServer:initialize()
	local root_uri = self:uri(self.root)
	local id = self:request("initialize", {
		processId = posix.getpid(),
		-- The progress titles handle() matches on are localized.
		locale = "en-us",
		rootUri = root_uri,
		workspaceFolders = {{uri = root_uri, name = self.root:match("[^/]+$")}},
		capabilities = {
			workspace = {configuration = true, workspaceFolders = true},
			textDocument = {publishDiagnostics = {relatedInformation = true}},
		},
	})
	self:wait_response(id, 60, "initialize")
	self:notify("initialized", json.object({}))
	self:wait(function() return self.workspace_ready end, 300, "workspace indexing")
end

---@param path string
---@return string? nil when the file is gone
local function read_file(path)
	local file = io.open(path, "rb")
	if not file then
		return nil
	end
	local text = file:read("*a")
	file:close()
	return text
end

---@param uri string
---@return integer
function LanguageServer:next_version(uri)
	local version = (self.versions[uri] or 0) + 1
	self.versions[uri] = version
	return version
end

---@param path string
---@param text string
function LanguageServer:did_open(path, text)
	local uri = self:uri(path)
	self:notify("textDocument/didOpen", {
		textDocument = {uri = uri, languageId = "lua", version = self:next_version(uri), text = text},
	})
end

---@param path string
function LanguageServer:did_close(path)
	self:notify("textDocument/didClose", {textDocument = {uri = self:uri(path)}})
end

--- Gives LuaLS a file's new text. Opening sets the text synchronously, so a request sent after
--- it sees the new text. Closing a file LuaLS found in its workspace scan keeps that text, but
--- closing any other file drops it, so those stay open.
---@param path string
---@param text string
function LanguageServer:update(path, text)
	if self.kept_open[path] then
		local uri = self:uri(path)
		self:notify("textDocument/didChange", {
			textDocument = {uri = uri, version = self:next_version(uri)},
			contentChanges = {{text = text}},
		})
		return
	end
	self:did_open(path, text)
	if self.scanned_files[path] then
		self:did_close(path)
	else
		self.kept_open[path] = true
	end
end

---@param path string
function LanguageServer:remove(path)
	if self.kept_open[path] then
		self:did_close(path)
		self.kept_open[path] = nil
	elseif self.scanned_files[path] then
		-- An empty file defines nothing, which is as close to deleted as LuaLS gets.
		self:update(path, "")
	end
end

--- Lists the project's .lua files, only those modified after `newer` when given.
---@param newer string?
---@return {[string]: true}
function LanguageServer:find_files(newer)
	local root = self.root
	local argv = {
		"find", root,
		"(", "-path", root .. "/.git", "-o", "-path", root .. "/build", "-o", "-path", root .. "/tree", ")", "-prune",
		"-o", "-type", "f", "-name", "*.lua",
	}
	if newer then
		table.insert(argv, "-newer")
		table.insert(argv, newer)
	end
	table.insert(argv, "-print")
	---@type {[string]: true}
	local paths = {}
	for path in assert(posix.capture(argv)):gmatch("[^\n]+") do
		paths[path] = true
	end
	return paths
end

--- LuaLS does not watch workspace files itself, so this sends it the project files modified,
--- added or removed since the last call. Moved files keep their mtime, hence the full listing.
function LanguageServer:sync_changes()
	local next_stamp = self.stamp .. ".next"
	assert(io.open(next_stamp, "wb")):close()
	local changed = self:find_files(self.stamp)
	local current = self:find_files()
	assert(os.rename(next_stamp, self.stamp))

	for path in pairs(current) do
		if not self.known_files[path] then
			changed[path] = true
		end
	end
	for path in pairs(self.known_files) do
		if not current[path] then
			self:remove(path)
		end
	end
	self.known_files = current

	for path in pairs(changed) do
		local text = read_file(path)
		if text then
			self:update(path, text)
		end
	end
end

--- Diagnoses the file as it is on disk.
---@param path string absolute path of a project .lua file
---@param level "Error"|"Warning"|"Information"|"Hint"
---@return scripts.luals.Diagnostic[]
function LanguageServer:diagnostics(path, level)
	self:sync_changes()
	local uri = self:uri(path)
	-- Diagnostics with a neededFileStatus of "Opened" only run on open files.
	local opened_here = not self.kept_open[path]
	if opened_here then
		self:did_open(path, assert(read_file(path)))
	end
	-- LuaLS answers only after diagnosing the file, and writes any resulting push before the
	-- answer. The answer itself is always "unchanged".
	local id = self:request("textDocument/diagnostic", {textDocument = {uri = uri}})
	self:wait_response(id, 45, "diagnostic request")
	if opened_here then
		self:did_close(path)
	end

	local minimum = SEVERITY_LEVELS[level]
	---@type scripts.luals.Diagnostic[]
	local result = {}
	for _, item in ipairs(self.published[uri] or {}) do
		local severity = item.severity or 2
		if severity <= minimum then
			local range = item.range or {}
			local start = range.start or {}
			local finish = range["end"] or {}
			table.insert(result, {
				severity = SEVERITY_NAMES[severity] or "unknown",
				line = (start.line or 0) + 1,
				column = (start.character or 0) + 1,
				endLine = (finish.line or 0) + 1,
				endColumn = (finish.character or 0) + 1,
				code = item.code ~= nil and item.code or json.null,
				source = item.source ~= nil and item.source or json.null,
				message = item.message or "",
			})
		end
	end
	table.sort(result, function(a, b)
		if a.line ~= b.line then return a.line < b.line end
		if a.column ~= b.column then return a.column < b.column end
		if a.severity ~= b.severity then return a.severity < b.severity end
		return tostring(a.code) < tostring(b.code)
	end)
	return result
end

function LanguageServer:close()
	pcall(function()
		local id = self:request("shutdown")
		self:wait(function() return self.responses[id] end, 5, "shutdown")
		self:notify("exit")
	end)
	posix.close(self.input)
	posix.close(self.output)
	posix.terminate(self.pid, 5)
end

return LanguageServer
