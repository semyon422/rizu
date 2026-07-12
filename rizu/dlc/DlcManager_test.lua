local DlcManager = require("rizu.dlc.DlcManager")

local test = {}

---@param t testing.T
function test.worker_uses_network_transport(t)
	local old_love = love
	love = {
		filesystem = {
			getSource = function()
				return "/game"
			end,
		},
	}

	local calls = {}
	local network = {
		request = function(_, url)
			table.insert(calls, {"request", url})
			return {status = 200, headers = {}, body = "ok"}
		end,
		download = function(_, url, options)
			table.insert(calls, {"download", url, options})
			return {status = 200, headers = {}, body = "data"}
		end,
	}

	local ok, err = pcall(function()
		local manager = DlcManager({}, network --[[@as any]])
		local worker = manager:createAndLoadWorker("/game")

		worker.request("https://example.test/search")
		worker.download_func("https://example.test/file", {chunk_size = 1})
	end)
	love = old_love
	if not ok then
		error(err, 0)
	end

	t:tdeq(calls[1], {"request", "https://example.test/search"})
	t:eq(calls[2][1], "download")
	t:eq(calls[2][2], "https://example.test/file")
	t:tdeq(calls[2][3], {chunk_size = 1})
end

---@param t testing.T
function test.network_is_required(t)
	local old_love = love
	love = {
		filesystem = {
			getSource = function()
				return "/game"
			end,
		},
	}

	local ok, err = pcall(function()
		DlcManager({})
	end)
	love = old_love

	t:eq(ok, false)
	t:assert(tostring(err):find("network is required", 1, true))
end

---@param t testing.T
function test.download_calls_local_worker(t)
	local old_love = love
	love = {
		filesystem = {
			getSource = function()
				return "/game"
			end,
		},
	}

	local called
	local ok, err = pcall(function()
		local manager = DlcManager({}, {} --[[@as any]])
		manager.worker = {
			download = function(_, id, _type, provider_name, metadata)
				called = {id = id, type = _type, provider = provider_name, metadata = metadata}
				manager:updateTask(id, {status = "completed"})
			end,
		}

		local metadata = {mirror = "mino"}
		manager:download(123, "set", "beatconnect", metadata)

		t:tdeq(called, {
			id = 123,
			type = "set",
			provider = "beatconnect",
			metadata = metadata,
		})
		t:eq(manager.tasks[123].status, "completed")
	end)
	love = old_love
	if not ok then
		error(err, 0)
	end
end

return test
