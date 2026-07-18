local CosocketScheduler = require("web.luasocket.CosocketScheduler")
local RequestContext = require("mcp.RequestContext")
local ScreenshotTool = require("rizu.ai.ScreenshotTool")

local test = {}

---@param t testing.T
function test.captures_png_content(t)
	local scheduler = CosocketScheduler()
	local capture_callback
	local tool = ScreenshotTool({network = {scheduler = scheduler}} --[[@as sphere.GameController]], {
		capture = function(callback)
			capture_callback = callback
		end,
		encode = function(image_data)
			t:eq(image_data, "image-data")
			return "aGVsbG8="
		end,
	})
	local result
	local co = coroutine.create(function()
		result = tool:execute({}, RequestContext(1))
	end)
	t:assert(coroutine.resume(co))
	t:eq(coroutine.status(co), "suspended")

	capture_callback("image-data")
	t:eq(coroutine.status(co), "dead")
	t:eq(result.is_error, nil)
	t:tdeq(result.content, {{type = "image", data = "aGVsbG8=", mimeType = "image/png"}})
end

---@param t testing.T
function test.cancels_capture(t)
	local scheduler = CosocketScheduler()
	local capture_callback
	local tool = ScreenshotTool({network = {scheduler = scheduler}} --[[@as sphere.GameController]], {
		capture = function(callback)
			capture_callback = callback
		end,
		encode = function()
			return "aGVsbG8="
		end,
	})
	local context = RequestContext(1)
	local result
	local co = coroutine.create(function()
		result = tool:execute({}, context)
	end)
	t:assert(coroutine.resume(co))
	context:cancel("stopped")

	t:eq(coroutine.status(co), "dead")
	t:eq(result.is_error, true)
	t:eq(result.content[1].text, "stopped")
	capture_callback("late-image")
end

return test
