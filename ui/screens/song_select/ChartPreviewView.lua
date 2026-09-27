local View = require("gui.View")
local Resources = require("ui.Resources")
local Painter = require("gui.Painter")
local BgaRenderer = require("ui.views.BgaRenderer")
local Settings = require("rizu.config.Settings")

local lg = love.graphics

---@class ui.screens.song_select.ChartPreviewView : gui.View
---@operator call: ui.screens.song_select.ChartPreviewView
---@field bg_model sphere.BackgroundModel
---@field game sphere.GameController
---@field preview_canvas love.Canvas?
---@field bga_renderer ui.views.BgaRenderer
---@field playfield_renderer rizu.gameplay.views.PlayfieldRenderer?
---@field preview_renderer_cache {[string]: {[string]: {skin: rizu.skin.SkinInfo|rizu.skin.OsuSkinDiscovery, renderer: rizu.gameplay.views.PlayfieldRenderer}}}
---@field chartview_formatter ui.formatters.ChartviewFormatter?
---@field unsubscribe_skins fun()
local ChartPreviewView = View + {}

---@param bg_model sphere.BackgroundModel
---@param game sphere.GameController
function ChartPreviewView:new(bg_model, game)
	View.new(self)
	self.bg_model = bg_model
	self.game = game
	self.bga_renderer = BgaRenderer()
	self.preview_renderer_cache = {mania = {}}
	self.unsubscribe_skins = game.settings:subscribeStringMap(Settings.keys.gameplay.skins, function(value, old_value)
		self:invalidateChangedPreviewRenderers(value, old_value)
		if self.chartview_formatter then self:bind(self.chartview_formatter) end
	end)
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

---@param input_mode string
---@param skin_paths rizu.config.StringMap
---@return rizu.skin.SkinInfo|rizu.skin.OsuSkinDiscovery?
function ChartPreviewView:getPreviewSkin(input_mode, skin_paths)
	local registry = self.game.skinRegistry
	if not registry then return nil end
	local selected_path = skin_paths["mania/" .. input_mode]
	return registry:getSkinForInputMode("mania", input_mode, selected_path)
end

---@param skin_paths rizu.config.StringMap
---@param old_skin_paths rizu.config.StringMap
function ChartPreviewView:invalidateChangedPreviewRenderers(skin_paths, old_skin_paths)
	local mode_cache = self.preview_renderer_cache.mania
	for input_mode, cached in pairs(mode_cache) do
		local old_skin = self:getPreviewSkin(input_mode, old_skin_paths)
		local new_skin = self:getPreviewSkin(input_mode, skin_paths)
		if old_skin ~= new_skin then
			if cached.renderer.unload then
				cached.renderer:unload()
			end
			mode_cache[input_mode] = nil
		end
	end
end

---@param input_mode string
---@param skin rizu.skin.SkinInfo|rizu.skin.OsuSkinDiscovery
---@return rizu.gameplay.views.PlayfieldRenderer?
function ChartPreviewView:getPreviewRenderer(input_mode, skin)
	local mode_cache = self.preview_renderer_cache.mania
	local cached = mode_cache[input_mode]
	if cached and cached.skin == skin then
		return cached.renderer
	end
	if cached and cached.renderer.unload then
		cached.renderer:unload()
	end

	local renderer = self.game.skinRegistry:loadSkin(skin, self.game, input_mode, "preview") --[[@as rizu.gameplay.views.PlayfieldRenderer?]]
	if renderer then
		mode_cache[input_mode] = {skin = skin, renderer = renderer}
	else
		mode_cache[input_mode] = nil
	end
	return renderer
end

function ChartPreviewView:clearPreviewRendererCache()
	for _, mode_cache in pairs(self.preview_renderer_cache) do
		for _, cached in pairs(mode_cache) do
			if cached.renderer.unload then
				cached.renderer:unload()
			end
		end
	end
	self.preview_renderer_cache = {mania = {}}
	self.playfield_renderer = nil
end

---@param cvf ui.formatters.ChartviewFormatter
function ChartPreviewView:bind(cvf)
	self.chartview_formatter = cvf
	self.playfield_renderer = nil
	local input_mode = cvf.chartview.chartdiff_inputmode
	if input_mode and cvf.chartview.chartmeta_mode == "mania" then
		local skin_paths = self.game.settings:getStringMap(Settings.keys.gameplay.skins)
		local skin = self:getPreviewSkin(input_mode, skin_paths)
		if skin then
			self.playfield_renderer = self:getPreviewRenderer(input_mode, skin)
		end
	end
end

function ChartPreviewView:unload()
	self.unsubscribe_skins()
	self:clearPreviewRendererCache()
	if self.preview_canvas then
		self.preview_canvas:release()
		self.preview_canvas = nil
	end
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
	local player = self.game.previewModel.chartPreview
	if self.playfield_renderer then
		self.playfield_renderer:drawPreview(player, w, h)
	end
	lg.pop()

	lg.draw(canvas)
	Resources.sprites.select_bg_overlay:draw(0, 0, 0, self.width / Resources.sprites.select_bg_overlay:getWidth(),
		self.height / Resources.sprites.select_bg_overlay:getHeight())
end

return ChartPreviewView
