local DlcManager = require("rizu.dlc.DlcManager")

local test = {}

---@param t testing.T
function test.sync_worker_uses_network_transport(t)
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
		manager:setSync(true)
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

return test
