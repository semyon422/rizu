local View = require("gui.View")
local Resources = require("ui.Resources")
local Painter = require("gui.Painter")
local BgaRenderer = require("ui.views.BgaRenderer")

local lg = love.graphics

---@class ui.screens.song_select.ChartPreviewView : gui.View
---@operator call: ui.screens.song_select.ChartPreviewView
---@field bg_model sphere.BackgroundModel
---@field game sphere.GameController
---@field preview_canvas love.Canvas?
---@field bga_renderer ui.views.BgaRenderer
local ChartPreviewView = View + {}

---@param bg_model sphere.BackgroundModel
---@param game sphere.GameController
function ChartPreviewView:new(bg_model, game)
	View.new(self)
	self.bg_model = bg_model
	self.game = game
	self.bga_renderer = BgaRenderer()
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

---Presentation-only compatibility hook; selection is owned by PreviewModel/PreviewLoader.
---@param cvf ui.formatters.ChartviewFormatter
function ChartPreviewView:bind(cvf) end

function ChartPreviewView:unload()
	if self.preview_canvas then self.preview_canvas:release(); self.preview_canvas = nil end
end

function ChartPreviewView:draw()
	local canvas = self.preview_canvas
	if not canvas then return end
	local images = self.bg_model.images
	local alpha = self.bg_model.alpha
	local w, h = canvas:getDimensions()

	lg.push("all")
	lg.setCanvas(canvas)
	lg.clear(0, 0, 0, 0)
	lg.origin()
	-- The view's screen-space clip does not apply while drawing to this canvas.
	lg.setScissor()

	for i = 1, 2 do
		if not images[i] then break end
		love.graphics.setColor(1, 1, 1, i == 1 and 1 or alpha)
		local image = images[i]
		local image_width, image_height = image:getDimensions()
		local scale = math.max(h / image_height, w / image_width)
		lg.draw(image, (w - image_width * scale) * 0.5, (h - image_height * scale) * 0.5, 0, scale, scale)
	end

	Painter.setColorRgb(1, 1, 1)
	Painter.setOpacity(1)
	local preview_model = self.game.previewModel
	local bga_engine = preview_model and preview_model.bgaPreviewPlayer
	if bga_engine then
		self.bga_renderer:draw(bga_engine, preview_model:getTime(), w, h)
	end
	local renderer = preview_model and preview_model:getPlayfield()
	if renderer then renderer:drawPreview(preview_model.chartPreview, w, h) end
	lg.pop()

	lg.draw(canvas)
	Resources.sprites.select_bg_overlay:draw(0, 0, 0, self.width / Resources.sprites.select_bg_overlay:getWidth(),
		self.height / Resources.sprites.select_bg_overlay:getHeight())
end

return ChartPreviewView
