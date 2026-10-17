local UpdaterIO = require("rizu.update.UpdaterIO")

local test = {}

local function new_headers()
	return {}
end

---@param t testing.T
function test.download_file_uses_network_and_writer(t)
	---@type string
	local requested_url
	local network = {
		download = function(_, url)
			requested_url = url
			return {
				status = 200,
				headers = new_headers(),
				body = "file body",
			}
		end,
	}
	---@type {path: string, body: string}
	local written
	local io = UpdaterIO(network --[[@as any]], function(path, body)
		written = {path = path, body = body}
		return true
	end)

	local ok, err = io:downloadAsync("https://example.test/file.lua", "file.lua")

	t:eq(err, nil)
	t:eq(ok, true)
	t:eq(requested_url, "https://example.test/file.lua")
	t:tdeq(written, {path = "file.lua", body = "file body"})
end

---@param t testing.T
function test.download_without_path_returns_body(t)
	local network = {
		download = function()
			return {
				status = 200,
				headers = new_headers(),
				body = "files json",
			}
		end,
	}
	local io = UpdaterIO(network --[[@as any]], function()
		error("writer should not be called")
	end)

	t:eq(io:downloadAsync("https://example.test/files.json"), "files json")
end

---@param t testing.T
function test.download_reports_network_error(t)
	local network = {
		download = function()
			return nil, "timeout"
		end,
	}
	local io = UpdaterIO(network --[[@as any]])

	local ok, err = io:downloadAsync("https://example.test/file.lua", "file.lua")

	t:eq(ok, nil)
	t:eq(err, "timeout")
end

---@param t testing.T
function test.download_reports_http_error(t)
	local network = {
		download = function()
			return {
				status = 404,
				headers = new_headers(),
				body = "missing",
			}
		end,
	}
	local io = UpdaterIO(network --[[@as any]])

	local ok, err = io:downloadAsync("https://example.test/file.lua", "file.lua")

	t:eq(ok, nil)
	t:eq(err, "HTTP 404")
end

---@param t testing.T
function test.remove_and_crc32_use_injected_functions(t)
	---@type string
	local removed
	---@type string
	local hashed
	local io = UpdaterIO({download = function() end} --[[@as any]], nil, function(path)
		removed = path
		return true
	end, function(path)
		hashed = path
		return 123
	end)

	t:eq(io:removeAsync("old.lua"), true)
	t:eq(io:crc32Async("new.lua"), 123)
	t:eq(removed, "old.lua")
	t:eq(hashed, "new.lua")
end

---@param t testing.T
function test.network_is_required(t)
	local ok, err = pcall(function()
		UpdaterIO()
	end)

	t:eq(ok, false)
	t:assert(tostring(err):find("network is required", 1, true))
end

return test
