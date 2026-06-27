local View = require("gui.View")
local Resources = require("yi.Resources")
local Colors = require("yi.Colors")
local ChartPreviewView = require("sphere.views.SelectView.ChartPreviewView")

---@class yi.BackgroundPanel : gui.View
---@operator call: yi.BackgroundPanel
local BackgroundPanel = View + {}

local base_lg_getWidth = love.graphics.getWidth
local base_lg_getHeight = love.graphics.getHeight
local base_lg_getDimensions = love.graphics.getDimensions

local preview_width = 0
local preview_height = 0

local function cancer_lg_getWidth()
	return preview_width
end

local function cancer_lg_getHeight()
	return preview_height
end

local function cancer_lg_getDimensions()
	return preview_width, preview_height
end

local function pushCancer()
	love.graphics.getWidth = cancer_lg_getWidth
	love.graphics.getHeight = cancer_lg_getHeight
	love.graphics.getDimensions = cancer_lg_getDimensions
end

local function popCancer()
	love.graphics.getWidth = base_lg_getWidth
	love.graphics.getHeight = base_lg_getHeight
	love.graphics.getDimensions = base_lg_getDimensions
end

local bg_shader_code = [[
	extern vec2 container_size;
    extern vec2 container_pos;
    extern float corner_radius;

    float rounded_box_sdf(vec2 center_pos, vec2 size, float radius) {
        return length(max(abs(center_pos) - size + radius, 0.0)) - radius;
    }

    vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
        vec4 pixel = Texel(texture, texture_coords);
        vec2 center = container_pos + (container_size * 0.5);
        float corner_dist = rounded_box_sdf(screen_coords - center, container_size * 0.5, corner_radius);
        float corner_mask = smoothstep(2.0, 0.0, corner_dist);
        return pixel * color * corner_mask;
    }
]]

local preview_shader_code = [[
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

---@param bg_model sphere.BackgroundModel
---@param game sphere.GameController
function BackgroundPanel:new(bg_model, game)
	self.bg_model = bg_model
	self.title_font = Resources.getFont("cjk_bold", 48)
	self.artist_font = Resources.getFont("cjk_bold", 24)
	self.bg_shader = love.graphics.newShader(bg_shader_code)
	self.preview_shader = love.graphics.newShader(preview_shader_code)
	self.title = "Title"
	self.artist = "Artist"
	self.ranked = false
	self.chart_preview_view = ChartPreviewView(game)
	View.new(self)
end

function BackgroundPanel:load()
	self.artist_y = self.box.height - self.artist_font:getHeight() - 20
	self.title_y = self.box.height - self.artist_font:getHeight() - 20 - self.title_font:getHeight()

	local _, _, w, h = Resources.quads.select_bg_overlay:getViewport()
	self.bg_overlay_sx = self.box.width / w
	self.bg_overlay_sy = self.box.height / h
	self.chart_preview_view:load()
	preview_width, preview_height = self.box:getDimensions()
	self.preview_canvas = love.graphics.newCanvas(preview_width, preview_height)
end

function BackgroundPanel:updateTransform()
	View.updateTransform(self)
	local x, y = self.transform:transformPoint(0, 0)
	local sw, sh = self.transform:transformPoint(self.box.width, self.box.height)
	self.container_screen_x = x
	self.container_screen_y = y
	self.container_screen_w = math.abs(sw - x)
	self.container_screen_h = math.abs(sh - y)
	self.bg_shader:send("container_pos", {self.container_screen_x, self.container_screen_y})
	self.bg_shader:send("container_size", {self.container_screen_w, self.container_screen_h})
	self.bg_shader:send("corner_radius", 8)
	self.preview_shader:send("container_size", {self.container_screen_w, self.container_screen_h})
	self.preview_shader:send("corner_radius", 8)
end

function BackgroundPanel:update(dt)
	self.chart_preview_view:update(dt)
end

---@param chartview rizu.library.LocatedChartview
function BackgroundPanel:bind(chartview)
	local title = chartview.title
	local artist = chartview.artist

	if not title or title:match("^%s*$") then
		self.title = "Unknown title"
	else
		self.title = title
	end

	if not artist or artist:match("^%s*$") then
		self.artist = "Unknown artist"
	else
		self.artist = artist
	end

	if chartview.difftable_chartmetas and #chartview.difftable_chartmetas > 0 then
		self.ranked = true
	end
end

local lg = love.graphics

function BackgroundPanel:drawBackground()
	local images = self.bg_model.images
	local alpha = self.bg_model.alpha
	local w, h = self.box:getDimensions()

	lg.setShader(self.bg_shader)
	lg.setScissor(self.container_screen_x, self.container_screen_y, self.container_screen_w, self.container_screen_h)

	for i = 1, 3 do
		if not images[i] then
			break
		end

		if i == 1 then
			lg.setColor(1, 1, 1, 1)
		elseif i == 2 then
			lg.setColor(1, 1, 1, alpha)
		elseif i == 3 then
			lg.setColor(1, 1, 1, 0)
		end

		local img = images[i]
		local iw, ih = img:getDimensions()

		local scale = math.max(h / ih, w / iw)
		local offset_x = (w - (iw * scale)) * 0.5
		local offset_y = (h - (ih * scale)) * 0.5
		lg.draw(img, offset_x, offset_y, 0, scale, scale)
	end

	lg.setShader()
	lg.setScissor()
	lg.setColor(1, 1, 1, 1)

	-- TODO: don't do this if chart preview is disabled
	lg.push("all")
	pushCancer()
	lg.setCanvas(self.preview_canvas)
	lg.clear()
	lg.origin()
	self.chart_preview_view:draw()
	lg.setCanvas()
	popCancer()
	lg.pop()

	lg.setShader(self.preview_shader)
	lg.draw(self.preview_canvas)
	lg.draw(Resources.atlas, Resources.quads.select_bg_overlay, 0, 0, 0, self.bg_overlay_sx, self.bg_overlay_sy)
	lg.setShader()
end

function BackgroundPanel:draw()
	self:drawBackground()

	lg.setScissor(self.container_screen_x, self.container_screen_y, self.container_screen_w, self.container_screen_h)
	lg.setFont(self.artist_font)
	lg.setColor(Colors.accent2)
	lg.print(self.artist, 20, self.artist_y)

	lg.setFont(self.title_font)
	lg.setColor(Colors.text)
	lg.print(self.title, 20, self.title_y)
	lg.setScissor()

	if self.ranked then
		local _, _, w, h = Resources.quads.tag_ranked:getViewport()
		lg.draw(Resources.atlas, Resources.quads.tag_ranked, self.box.width - w - 20, self.box.height - h - 20)
	end
end

function BackgroundPanel:receive(event)
	self.chart_preview_view:receive(event)
end

return BackgroundPanel
