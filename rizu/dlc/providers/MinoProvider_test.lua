local MinoProvider = require("rizu.dlc.providers.MinoProvider")

local test = {}

local function noop_request() end

---@param t testing.T
function test.search(t)
	local requested_url
	local provider = MinoProvider({
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
						"source": "Source",
						"tags": "tag",
						"status": "ranked",
						"beatmaps": [{"id": 1}],
						"video": false,
						"storyboard": true
					}]
				]],
			}
		end,
	})

	local results, err = provider:search("hello world", {page = 2, status = "loved"})

	t:eq(err, nil)
	t:assert(requested_url:find("query=hello%20world", 1, true))
	t:assert(requested_url:find("offset=100", 1, true))
	t:assert(requested_url:find("status=4", 1, true))
	t:eq(results[1].id, 12345)
	t:eq(results[1].thumbnail_url, "https://assets.ppy.sh/beatmaps/12345/covers/card.jpg")
end

---@param t testing.T
function test.getDownloadUrl(t)
	local provider = MinoProvider({request = noop_request})
	local url = provider:getDownloadUrl(12345)
	t:eq(url, "https://catboy.best/d/12345")
end

---@param t testing.T
function test.request_is_required(t)
	local ok, err = pcall(function()
		MinoProvider({} --[[@as any]])
	end)

	t:eq(ok, false)
	t:assert(tostring(err):find("request is required", 1, true))
end

return test
