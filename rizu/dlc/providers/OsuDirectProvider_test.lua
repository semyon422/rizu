local OsuDirectProvider = require("rizu.dlc.providers.OsuDirectProvider")

local test = {}

local function noop_request() end

---@param t testing.T
function test.initialization(t)
	local provider = OsuDirectProvider({
		baseUrl = "https://example.com",
		downloadUrl = "https://example.com/d/%s",
		request = noop_request,
	})
	t:eq(provider.baseUrl, "https://example.com")
	t:eq(provider.downloadUrl, "https://example.com/d/%s")
end

---@param t testing.T
function test.getDownloadUrl(t)
	local provider = OsuDirectProvider({
		baseUrl = "https://example.com",
		downloadUrl = "https://example.com/d/%s",
		request = noop_request,
	})
	t:eq(provider:getDownloadUrl(12345), "https://example.com/d/12345")
end

---@param t testing.T
function test.request_is_required(t)
	local ok, err = pcall(function()
		OsuDirectProvider({
			baseUrl = "https://example.com",
			downloadUrl = "https://example.com/d/%s",
		} --[[@as any]])
	end)

	t:eq(ok, false)
	t:assert(tostring(err):find("request is required", 1, true))
end

return test
