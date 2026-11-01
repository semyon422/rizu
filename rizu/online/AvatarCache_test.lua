local AvatarCache = require("rizu.online.AvatarCache")

local test = {}

---@param t testing.T
function test.failed_download_is_not_tried_again(t)
	local downloads = 0
	local network = {download = function()
		downloads = downloads + 1
		return nil, "timeout"
	end}
	local cache = AvatarCache(network --[[@as rizu.NetworkService]])
	t:eq(cache:get("a.png"), nil)
	t:eq(cache:get("a.png"), nil)
	t:eq(downloads, 1)
	t:eq(cache.entries["a.png"].state, "failed")

	network.download = function()
		downloads = downloads + 1
		return {status = 404, body = ""}
	end
	cache:get("b.png")
	cache:get("b.png")
	t:eq(downloads, 2, "an HTTP error counts as failed too")

	cache:clear()
	cache:get("a.png")
	t:eq(downloads, 3, "clear() allows another try")
end

return test
