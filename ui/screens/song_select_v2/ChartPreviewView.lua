local View = require("gui.View")
local Resources = require("ui.Resources")
local Painter = require("gui.Painter")
local BgaRenderer = require("ui.views.BgaRenderer")

local lg = love.graphics

---@class ui.screens.song_select_v2.ChartPreviewView : gui.View
---@operator call: ui.screens.song_select_v2.ChartPreviewView
---@field media rizu.api.Media
---@field preview_canvas love.Canvas?
---@field bga_renderer ui.views.BgaRenderer
---@field brightness number 0..1, of the background and BGA but not the notes
local ChartPreviewView = View + {}

---@param media rizu.api.Media
function ChartPreviewView:new(media)
	View.new(self)
	self.media = media
	self.bga_renderer = BgaRenderer()
	self.brightness = 1
end

---@param old_x number
---@param old_y number
---@param old_width number
---@param old_height number
function ChartPreviewView:onLayoutChanged(old_x, old_y, old_width, old_height)
	local canvas_width = math.max(1, math.floor(self.width))
	local canvas_height = math.max(1, math.floor(self.height))
	if self.preview_canvas then
		local old_canvas_width, old_canvas_height = self.preview_canvas:getDimensions()
		if old_canvas_width == canvas_width and old_canvas_height == canvas_height then
			return
		end
		self.preview_canvas:release()
	end
	self.preview_canvas = lg.newCanvas(canvas_width, canvas_height)
end

---Presentation-only compatibility hook; the game picks what is previewed.
---@param cvf ui.formatters.ChartviewFormatter
function ChartPreviewView:bind(cvf) end

function ChartPreviewView:unload()
	if self.preview_canvas then self.preview_canvas:release(); self.preview_canvas = nil end
end

function ChartPreviewView:draw()
	local canvas = self.preview_canvas
	if not canvas then return end
	local media = self.media
	local images, alpha = media:getBackgroundImages()
	local w, h = canvas:getDimensions()

	lg.push("all")
	lg.setCanvas(canvas)
	lg.clear(0, 0, 0, 0)
	lg.origin()
	-- The view's screen-space clip does not apply while drawing to this canvas.
	lg.setScissor()

	local b = self.brightness
	for i = 1, 2 do
		if not images[i] then break end
		love.graphics.setColor(b, b, b, i == 1 and 1 or alpha)
		local image = images[i]
		local image_width, image_height = image:getDimensions()
		local scale = math.max(h / image_height, w / image_width)
		lg.draw(image, (w - image_width * scale) * 0.5, (h - image_height * scale) * 0.5, 0, scale, scale)
	end

	Painter.setColorRgb(b, b, b)
	Painter.setOpacity(1)
	local animation, time = media:getBackgroundAnimation()
	if animation then
		self.bga_renderer:draw(animation, time, w, h)
	end
	Painter.setColorRgb(1, 1, 1)
	media:drawNotesPreview(w, h)
	lg.pop()

	lg.draw(canvas)
	Resources.sprites.select_bg_overlay:draw(0, 0, 0, self.width / Resources.sprites.select_bg_overlay:getWidth(),
		self.height / Resources.sprites.select_bg_overlay:getHeight())
end

return ChartPreviewView
