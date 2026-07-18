local class = require("class")

---@class rizu.ai.ScreenshotToolOptions
---@field capture (fun(callback: fun(image_data: love.ImageData)))?
---@field encode (fun(image_data: love.ImageData): string)?

---@class rizu.ai.ScreenshotTool
---@operator call: rizu.ai.ScreenshotTool
---@field name string
---@field description string
---@field input_schema table
---@field annotations mcp.ToolAnnotations
---@field scheduler web.CosocketScheduler
---@field capture fun(callback: fun(image_data: love.ImageData))
---@field encode fun(image_data: love.ImageData): string
local ScreenshotTool = class()

ScreenshotTool.name = "capture_screenshot"
ScreenshotTool.description = "Capture the current game frame and return it as a PNG image."
ScreenshotTool.input_schema = {
	type = "object",
	properties = {},
	additionalProperties = false,
}
ScreenshotTool.annotations = {
	readOnlyHint = true,
	destructiveHint = false,
	idempotentHint = false,
	openWorldHint = false,
}

---@param game sphere.GameController
---@param options rizu.ai.ScreenshotToolOptions?
function ScreenshotTool:new(game, options)
	options = options or {}
	self.scheduler = game.network.scheduler
	self.capture = options.capture or function(callback)
		love.graphics.captureScreenshot(callback)
	end
	self.encode = options.encode or function(image_data)
		local file_data = image_data:encode("png")
		return love.data.encode("string", "base64", file_data:getString())
	end
end

---@param message string
---@return mcp.ToolResult
local function error_result(message)
	return {
		content = {{type = "text", text = message}},
		is_error = true,
	}
end

---@param args {[string]: any}
---@param context mcp.RequestContext
---@return mcp.ToolResult
function ScreenshotTool:execute(args, context)
	local co = assert(coroutine.running(), "capture_screenshot must run in a coroutine")
	local waiting = false
	local ready = false
	local encoded
	local capture_error

	local function complete(data, err)
		if ready then
			return
		end
		ready = true
		encoded = data
		capture_error = err
		if waiting then
			self.scheduler:resume(co, data, err)
		end
	end

	context:onCancel(function(reason)
		complete(nil, reason)
	end)
	if ready then
		return error_result(assert(capture_error))
	end
	local ok, err = xpcall(self.capture, debug.traceback, function(image_data)
		local encode_ok, data = xpcall(self.encode, debug.traceback, image_data)
		if encode_ok then
			complete(data)
		else
			complete(nil, tostring(data))
		end
	end)
	if not ok then
		return error_result(tostring(err))
	end

	if not ready then
		waiting = true
		encoded, capture_error = coroutine.yield()
	end
	if not encoded then
		return error_result(capture_error or "screenshot capture failed")
	end
	return {
		content = {{type = "image", data = encoded, mimeType = "image/png"}},
	}
end

return ScreenshotTool
