local BeatconnectProvider = require("rizu.dlc.providers.BeatconnectProvider")

local test = {}

local function noop_request() end

---@param t testing.T
function test.initialization(t)
	local provider = BeatconnectProvider({request = noop_request})
	t:eq(provider.apiUrl, "https://beatconnect.io/api/search/")
	t:eq(provider.downloadUrlPattern, "https://beatconnect.io/b/%s")
end

---@param t testing.T
function test.getDownloadUrl(t)
	local provider = BeatconnectProvider({request = noop_request})
	t:eq(provider:getDownloadUrl(12345), "https://beatconnect.io/b/12345")
end

---@param t testing.T
function test.search_uses_injected_request(t)
	local requested_url
	local provider = BeatconnectProvider({
		request = function(url)
			requested_url = url
			return {
				status = 200,
				body = [[
					[{
						"id": 12345,
						"title": "Title",
						"artist": "Artist",
						"creator": "Creator",
						"status": "ranked",
						"beatmaps": [{"id": 1}]
					}]
				]],
			}
		end,
	})

	local results, err = provider:search("hello world", {page = 3, status = "loved"})

	t:eq(err, nil)
	t:assert(requested_url:find("q=hello%20world", 1, true))
	t:assert(requested_url:find("p=2", 1, true))
	t:assert(requested_url:find("s=loved", 1, true))
	t:eq(results[1].id, 12345)
	t:eq(results[1].thumbnail_url, "https://assets.ppy.sh/beatmaps/12345/covers/card.jpg")
end

---@param t testing.T
function test.request_is_required(t)
	local ok, err = pcall(function()
		BeatconnectProvider({} --[[@as any]])
	end)

	t:eq(ok, false)
	t:assert(tostring(err):find("request is required", 1, true))
end

return test
