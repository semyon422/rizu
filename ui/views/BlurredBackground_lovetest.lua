local BlurredBackground = require("ui.views.BlurredBackground")
local Events = require("rizu.api.Events")

local test = {}
local lg = love.graphics

---@param r number
---@param g number
---@param b number
---@return love.Image
local function checker(r, g, b)
	local data = love.image.newImageData(480, 270)
	data:mapPixel(function(x, y)
		local on = (math.floor(x / 2) + math.floor(y / 2)) % 2 == 0
		return on and r or 0, on and g or 0, on and b or 0, 1
	end)
	return lg.newImage(data)
end

---@param t testing.T
function test.blurs_over_frames_and_crossfades(t)
	local was_active = lg.isActive()
	if not was_active then assert(love.window.setMode(1000, 720)) end

	local media = Events()
	local images = {checker(1, 0, 0)}
	function media:getBackgroundImages() return images, 0 end
	local view = BlurredBackground(media --[[@as any]])
	view:load()

	local frames = 0
	while not view.fade do
		view:update(1 / 60)
		frames = frames + 1
		assert(frames < 100, "blur never finished")
	end
	t:eq(frames, 11, "one pass per frame: cover, 5 down, 5 up")

	-- A 2px checker must come out flat: every pixel near the 50% mean.
	local pixels = lg.readbackTexture(view.incoming)
	for _, point in ipairs({{0, 0}, {240, 135}, {244, 135}, {479, 269}}) do
		local r, g, b = pixels:getPixel(point[1], point[2])
		t:assert(math.abs(r - 0.5) < 0.03, ("pixel %d,%d is not flat: %f"):format(point[1], point[2], r))
		t:eq(g + b, 0)
	end

	-- A change during the fade waits: only two blurred images exist.
	local red = view.incoming
	media:emit("background_changed", checker(0, 1, 0))
	view:update(0.1)
	t:eq(view.incoming, red)
	t:eq(view.source, nil)

	view:update(1)
	t:eq(view.shown, red)
	t:eq(view.has_shown, true)
	t:assert(view.source ~= nil, "the queued image must start blurring after the fade")

	view:unload()
	t:eq(#media.listeners.background_changed, 0)
	if not was_active then love.window.close() end
end

return test
