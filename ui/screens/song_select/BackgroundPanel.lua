local View = require("gui.View")
local Resources = require("ui.Resources")
local Colors = require("ui.Colors")
local Painter = require("gui.Painter")
local ChartPreviewView = require("sphere.views.SelectView.ChartPreviewView")
local BgaRenderer = require("ui.views.BgaRenderer")
local ProgressBar = require("ui.screens.music_player.ProgressBar")
local SpringValue = require("gui.anim.SpringValue")

local lg = love.graphics

---@class ui.screens.song_select.BackgroundPanel.Details : gui.View
---@operator call: ui.screens.song_select.BackgroundPanel.Details
---@field panel ui.screens.song_select.BackgroundPanel
local Details = View + {}

---@param panel ui.screens.song_select.BackgroundPanel
function Details:new(panel)
	View.new(self)
	self.panel = panel
end

function Details:draw()
	local panel = self.panel
	Painter.setOpacity(panel.details_opacity:get())
	lg.setFont(panel.title_font)
	Painter.setColorRgb(0, 0, 0, 0.25)
	lg.print(panel.title, 22, 2)
	Painter.setColorTable(Colors.text)
	lg.print(panel.title, 20, 0)
	lg.setFont(panel.artist_font)
	Painter.setColorRgb(0, 0, 0, 0.25)
	lg.print(panel.artist, 22, panel.title_font:getHeight() + 2)
	Painter.setColorTable(Colors.accent)
	lg.print(panel.artist, 20, panel.title_font:getHeight())
end

---@class ui.screens.song_select.BackgroundPanel : gui.View
---@operator call: ui.screens.song_select.BackgroundPanel
---@field bg_model sphere.BackgroundModel
---@field chart_preview_view sphere.ChartPreviewView
---@field bga_renderer ui.views.BgaRenderer
---@field game sphere.GameController
---@field preview_canvas love.Canvas?
---@field details_container ui.screens.song_select.BackgroundPanel.Details
---@field progress_bar ui.screens.music_player.ProgressBar
---@field details_opacity gui.anim.SpringValue
---@field details_reveal gui.anim.SpringValue
---@field details_hidden_offset number
local BackgroundPanel = View + {}

-- ChartPreviewView is still a legacy renderer and uses the window dimensions as
-- its viewport.  Keep the compatibility shim local to this view while it is
-- rendered into the panel canvas.
local preview_width = 0
local preview_height = 0
local base_get_width = love.graphics.getWidth
local base_get_height = love.graphics.getHeight
local base_get_dimensions = love.graphics.getDimensions

local function getPreviewWidth()
	return preview_width
end

local function getPreviewHeight()
	return preview_height
end

local function getPreviewDimensions()
	return preview_width, preview_height
end

local function pushPreviewViewport()
	love.graphics.getWidth = getPreviewWidth
	love.graphics.getHeight = getPreviewHeight
	love.graphics.getDimensions = getPreviewDimensions
end

local function popPreviewViewport()
	love.graphics.getWidth = base_get_width
	love.graphics.getHeight = base_get_height
	love.graphics.getDimensions = base_get_dimensions
end

local shader_code = [[
	extern vec2 container_size;
	extern float corner_radius;

	float rounded_box_sdf(vec2 center_pos, vec2 size, float radius) {
		return length(max(abs(center_pos) - size + radius, 0.0)) - radius;
	}

	vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
		vec4 pixel = Texel(texture, texture_coords);
		vec2 local_center_coords = (texture_coords - 0.5) * container_size;
		float corner_dist = rounded_box_sdf(local_center_coords, container_size * 0.5, corner_radius);
		float corner_mask = smoothstep(2.0, 0.0, corner_dist);
		return pixel * color * corner_mask * color.a;
	}
]]

local DETAILS_PADDING = 20
local PROGRESS_HEIGHT = 54
local PROGRESS_BOTTOM = 10
local DETAILS_BOTTOM_PADDING = 8
local DETAILS_GAP = 12
-- Downward offset while idle. Keep it low enough for the title and artist to remain visible.
local DETAILS_IDLE_Y = 56 + DETAILS_BOTTOM_PADDING

---@param bg_model sphere.BackgroundModel
---@param game sphere.GameController
function BackgroundPanel:new(bg_model, game)
	View.new(self)
	self.bg_model = bg_model
	self.game = game
	self.bga_renderer = BgaRenderer()
	self.title_font = Resources.getFont("cjk_bold", 48)
	self.artist_font = Resources.getFont("cjk_bold", 24)
	self.bg_shader = lg.newShader(shader_code)
	self.title = "Title"
	self.artist = "Artist"
	self.details_opacity = SpringValue({
		value = 0,
		stiffness = 120,
		damping = 22,
	})
	self.details_reveal = SpringValue({
		value = 0,
		stiffness = 220,
		damping = 26,
	})
	self.details_hidden_offset = 0
	self.handles_mouse_input = true
	self:setClip(true)
	self.chart_preview_view = ChartPreviewView(game)
	self.details_container = self:add(Details(self))
	self.progress_bar = self.details_container:add(ProgressBar(game.previewModel))
end

function BackgroundPanel:load()
	self.chart_preview_view:load()
end

function BackgroundPanel:unload()
	if self.preview_canvas then
		self.preview_canvas:release()
		self.preview_canvas = nil
	end
	self.chart_preview_view:unload()
end

---@param old_x number
---@param old_y number
---@param old_width number
---@param old_height number
function BackgroundPanel:onLayoutChanged(old_x, old_y, old_width, old_height)
	local title_height = self.title_font:getHeight()
	local artist_height = self.artist_font:getHeight()
	local details_height = title_height + artist_height + DETAILS_GAP
		+ PROGRESS_HEIGHT + DETAILS_BOTTOM_PADDING
	local details_y = self.height - details_height - PROGRESS_BOTTOM
	self.details_container:anchorFixed(0, details_y, self.width, details_height)
	self.progress_bar:anchorFixed(
		DETAILS_PADDING,
		title_height + artist_height + DETAILS_GAP,
		math.max(0, self.width - DETAILS_PADDING * 2),
		PROGRESS_HEIGHT
	)
	self.details_hidden_offset = DETAILS_IDLE_Y
	self.details_container:setOffset(0, self.details_hidden_offset * (1 - self.details_reveal:get()))

	local overlay_width, overlay_height = Resources.sprites.select_bg_overlay:getDimensions()
	self.bg_overlay_sx = self.width / overlay_width
	self.bg_overlay_sy = self.height / overlay_height

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
	preview_width, preview_height = canvas_width, canvas_height
	self.bg_shader:send("container_size", {canvas_width, canvas_height})
	self.bg_shader:send("corner_radius", 8)
end

---@param dt number
function BackgroundPanel:update(dt)
	self.chart_preview_view:update(dt)
	self.details_opacity:update(dt)
	local inputs = self.screen and self.screen.inputs
	local hovered = inputs and self:isMouseOver(inputs.mouse_x, inputs.mouse_y) or false
	self.details_reveal:set(hovered and 1 or 0):update(dt)
	self.details_container:setOffset(0, self.details_hidden_offset * (1 - self.details_reveal:get()))
end

---@param cvf ui.formatters.ChartviewFormatter
function BackgroundPanel:bind(cvf)
	self.details_opacity:snap(0):set(1)
	self.title = cvf:getTitle()
	self.artist = cvf:getArtist()
end

function BackgroundPanel:drawBackground()
	local images = self.bg_model.images
	local alpha = self.bg_model.alpha
	local w, h = self.preview_canvas:getDimensions()

	lg.push("all")
	lg.setCanvas(self.preview_canvas)
	lg.clear(0, 0, 0, 0)
	lg.origin()
	-- The panel's screen-space clip does not apply to its local preview canvas.
	-- Keeping it here offsets/clips the background, BGA, and legacy chart preview.
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

	pushPreviewViewport()
	self.chart_preview_view:draw()
	popPreviewViewport()
	lg.pop()

	lg.setShader(self.bg_shader)
	lg.draw(self.preview_canvas)
	lg.setShader()
	Resources.sprites.select_bg_overlay:draw(0, 0, 0, self.bg_overlay_sx, self.bg_overlay_sy)
end

function BackgroundPanel:draw()
	if not self.preview_canvas then return end
	self:drawBackground()
end

---@param event table
function BackgroundPanel:receive(event)
	self.chart_preview_view:receive(event)
end

return BackgroundPanel
