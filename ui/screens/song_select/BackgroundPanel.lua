local View = require("gui.View")
local Resources = require("ui.Resources")
local Colors = require("ui.Colors")
local Painter = require("gui.Painter")
local ChartPreviewView = require("sphere.views.SelectView.ChartPreviewView")
local SpringValue = require("gui.anim.SpringValue")

---@class ui.screens.song_select.BackgroundPanel : gui.View
---@operator call: ui.screens.song_select.BackgroundPanel
---@field bg_model sphere.BackgroundModel
---@field chart_preview_view sphere.ChartPreviewView
---@field preview_canvas love.Canvas?
---@field details_opacity gui.anim.SpringValue
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
		return pixel * color * corner_mask;
	}
]]

local lg = love.graphics

---@param bg_model sphere.BackgroundModel
---@param game sphere.GameController
function BackgroundPanel:new(bg_model, game)
	View.new(self)
	self.bg_model = bg_model
	self.title_font = Resources.getFont("cjk_bold", 48)
	self.artist_font = Resources.getFont("cjk_bold", 24)
	self.bg_shader = lg.newShader(shader_code)
	self.title = "Title"
	self.artist = "Artist"
	self.ranked = false
	self.details_opacity = SpringValue({value = 0})
	self.chart_preview_view = ChartPreviewView(game)
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
	self.artist_y = self.height - self.artist_font:getHeight() - 20
	self.title_y = self.artist_y - self.title_font:getHeight()

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
end

---@param chartview rizu.library.LocatedChartview
function BackgroundPanel:bind(chartview)
	self.details_opacity:snap(0):set(1)
	self.title = chartview.title and not chartview.title:match("^%s*$")
		and chartview.title or "Unknown title"
	self.artist = chartview.artist and not chartview.artist:match("^%s*$")
		and chartview.artist or "Unknown artist"
	self.ranked = chartview.difftable_chartmetas and #chartview.difftable_chartmetas > 0 or false
end

function BackgroundPanel:drawBackground()
	local images = self.bg_model.images
	local alpha = self.bg_model.alpha
	local w, h = self.preview_canvas:getDimensions()

	lg.push("all")
	lg.setCanvas(self.preview_canvas)
	lg.clear()
	lg.origin()

	for i = 1, 2 do
		if not images[i] then break end
		love.graphics.setColor(1, 1, 1, i == 1 and 1 or alpha)
		local image = images[i]
		local image_width, image_height = image:getDimensions()
		local scale = math.max(h / image_height, w / image_width)
		lg.draw(image, (w - image_width * scale) * 0.5, (h - image_height * scale) * 0.5, 0, scale, scale)
	end

	Painter.setOpacity(1)
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
	Painter.begin(self.render_opacity)
	Painter.setOpacity(self.details_opacity:get())

	local screen_x, screen_y = self.world_transform:transformPoint(0, 0)
	local screen_right, screen_bottom = self.world_transform:transformPoint(self.width, self.height)
	lg.setScissor(screen_x, screen_y, math.abs(screen_right - screen_x), math.abs(screen_bottom - screen_y))
	lg.setFont(self.artist_font)
	Painter.setColorTable(Colors.accent2)
	lg.print(self.artist, 20, self.artist_y)
	lg.setFont(self.title_font)
	Painter.setColorTable(Colors.text)
	lg.print(self.title, 20, self.title_y)
	lg.setScissor()

	if self.ranked then
		local tag_width, tag_height = Resources.sprites.tag_ranked:getDimensions()
		Resources.sprites.tag_ranked:draw(self.width - tag_width - 20, self.height - tag_height - 20)
	end
end

---@param event table
function BackgroundPanel:receive(event)
	self.chart_preview_view:receive(event)
end

return BackgroundPanel
