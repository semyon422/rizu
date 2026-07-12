local EtternaPackProvider = require("rizu.dlc.providers.EtternaPackProvider")

local test = {}

---@param t testing.T
function test.getDownloadUrl(t)
	local provider = EtternaPackProvider()
	local url = provider:getDownloadUrl("Test Pack")
	-- It should escape the name
	t:eq(url, "https://downloads.etternaonline.com/ranked/Test%20Pack.zip")
end

---@param t testing.T
function test.search_url_construction(t)
	local requested_url
	local provider = EtternaPackProvider({
		request = function(url)
			requested_url = url
			return {
				status = 200,
				body = [[
					{
						"data": [{
							"name": "Pack",
							"author": "Author",
							"size": 123,
							"date": "2026-01-01",
							"average_diff": 10,
							"total_songs": 20
						}]
					}
				]],
			}
		end,
	})

	local results, err = provider:search("hello world", {page = 2, limit = 12, sort = "name", key_count = 4})

	t:eq(err, nil)
	t:assert(requested_url:find("filter%5bsearch%5d=hello%20world", 1, true))
	t:assert(requested_url:find("filter%5bkey_count%5d=4", 1, true))
	t:assert(requested_url:find("limit=12", 1, true))
	t:eq(results[1].id, "Pack")
	t:eq(results[1].total_songs, 20)
end

return test
