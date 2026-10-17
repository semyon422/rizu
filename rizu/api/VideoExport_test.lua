local VideoExport = require("rizu.api.VideoExport")

local test = {}
local lg = love.graphics
local has_graphics = lg and lg.isActive ~= nil -- plain `./test` has no real love.graphics

---@param t testing.T
function test.exports_drawn_frames_to_an_animated_webp(t)
	if not has_graphics then return end
	local export = VideoExport()
	if not export:isAvailable() then return end -- needs ffmpeg on PATH
	local was_active = lg.isActive()
	if not was_active then assert(love.window.setMode(320, 180)) end

	local path = os.tmpname() .. ".webp"
	local times = {}
	local ok, err = export:start({
		width = 64, height = 48, fps = 10, duration = 1, start_time = 2, path = path,
		draw = function(time, _, width, height)
			times[#times + 1] = time
			lg.setColor(1, 0, 0, 1)
			lg.rectangle("fill", 0, 0, width * (time - 2), height)
		end,
	})
	t:eq(ok, true, err)
	t:eq(export:isRunning(), true)

	local guard = 0
	while export:isRunning() do
		export:update(0.002)
		lg.present() -- an unpresented frame queues driver memory
		guard = guard + 1
		assert(guard < 1000, "export never finished")
	end

	t:eq(export:getState(), "done", export:getError())
	t:eq(#times, 10)
	t:eq(export:getProgress(), 1)
	local file = assert(io.open(path, "rb"))
	local head = file:read(12)
	file:close()
	os.remove(path)
	t:eq(head:sub(9, 12), "WEBP")
end

---@param t testing.T
function test.refuses_a_second_export_and_cancel_removes_the_file(t)
	if not has_graphics then return end
	local export = VideoExport()
	if not export:isAvailable() then return end
	if not lg.isActive() then assert(love.window.setMode(320, 180)) end

	local path = os.tmpname() .. ".webp"
	local options = {width = 16, height = 16, fps = 10, duration = 5, path = path, draw = function() end}
	t:eq(export:start(options), true)
	t:eq(export:start(options), false)
	export:update(0.001)
	export:cancel()
	t:eq(export:getState(), "cancelled")
	t:eq(io.open(path, "rb"), nil)
end

return test
