local OsuFileProvider = require("rizu.dlc.providers.OsuFileProvider")

local test = {}

---@param t testing.T
function test.getDownloadUrl(t)
	local provider = OsuFileProvider()
	local url = provider:getDownloadUrl(123456)
	t:eq(url, "https://osu.ppy.sh/osu/123456")
end

---@param t testing.T
function test.search_returns_empty(t)
	local provider = OsuFileProvider()
	local results, err = provider:search("test")
	t:tdeq(results, {})
	t:eq(err, nil)
end

return test
