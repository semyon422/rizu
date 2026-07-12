local DlcWorker = require("rizu.dlc.DlcWorker")

local test = {}

---@class rizu.dlc.FakeHeadersForDlcWorker
---@field values {[string]: string}
local FakeHeaders = {}
FakeHeaders.__index = FakeHeaders

---@param name string
---@return string?
function FakeHeaders:get(name)
	return self.values[name]
end

---@return rizu.dlc.FakeHeadersForDlcWorker
local function new_headers(values)
	return setmetatable({values = values or {}}, FakeHeaders)
end

---@return table
local function new_manager()
	return {
		updates = {},
		completed = {},
		updateTask = function(self, id, updates)
			table.insert(self.updates, {id = id, updates = updates})
		end,
		onDlcCompleted = function(self, id, _type, metadata)
			table.insert(self.completed, {id = id, type = _type, metadata = metadata})
		end,
	}
end

---@param t testing.T
function test.download_uses_injected_download_func(t)
	local manager = new_manager()
	local requested_url
	local requested_options
	local processed
	local worker = DlcWorker(manager, "/game", nil, function(url, options)
		requested_url = url
		requested_options = options
		options.on_download(5, 10, "hello")
		options.on_download(10, 10, "world")
		return {
			status = 200,
			headers = new_headers({
				["Content-Length"] = "10",
				["Content-Disposition"] = "attachment; filename=\"downloaded.osz\"",
			}),
			body = "helloworld",
		}
	end, {
		install = function(_, id, _type, data, filename, metadata)
			processed = {id = id, type = _type, data = data, filename = filename, metadata = metadata}
			return true
		end,
	})

	local ok, err = worker:download(123, "set", "mino")

	t:eq(err, nil)
	t:eq(ok, true)
	t:eq(requested_url, "https://catboy.best/d/123")
	t:eq(requested_options.chunk_size, 64 * 1024)
	t:tdeq(processed, {
		id = 123,
		type = "set",
		data = "helloworld",
		filename = "downloaded.osz",
		metadata = nil,
	})
	t:eq(manager.updates[1].updates.status, "connecting")
	t:eq(manager.updates[2].updates.status, "downloading")
	t:eq(manager.updates[3].updates.progress, 0.5)
	t:eq(manager.updates[4].updates.progress, 1)
	t:eq(manager.updates[#manager.updates].updates.status, "completed")
	t:tdeq(manager.completed[1], {id = 123, type = "set", metadata = nil})
end

---@param t testing.T
function test.download_reports_http_error(t)
	local manager = new_manager()
	local worker = DlcWorker(manager, "/game", nil, function()
		return {
			status = 500,
			headers = new_headers(),
			body = "error",
		}
	end, {
		install = function()
			error("installer should not be called")
		end,
	})

	local ok, err = worker:download(123, "set", "mino")

	t:eq(ok, nil)
	t:eq(err, "HTTP 500")
	t:eq(manager.updates[#manager.updates].updates.status, "error")
	t:eq(manager.updates[#manager.updates].updates.error, "HTTP 500")
end

return test
