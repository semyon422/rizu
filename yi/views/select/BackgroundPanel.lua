local View = require("gui.View")
local Resources = require("yi.Resources")
local Colors = require("yi.Colors")

---@class yi.BackgroundPanel : gui.View
---@operator call: yi.BackgroundPanel
local BackgroundPanel = View + {}

local shader_code = [[
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

---@param bg_model sphere.BackgroundModel
function BackgroundPanel:new(bg_model)
	View.new(self)
	self.bg_model = bg_model
	self.title_font = Resources.getFont("bold", 48)
	self.artist_font = Resources.getFont("bold", 24)
	self.bg_shader = love.graphics.newShader(shader_code)
	self.title = "Title"
	self.artist = "Artist"
	self.ranked = false
end

function BackgroundPanel:load()
	self.artist_y = self.box.height - self.artist_font:getHeight() - 20
	self.title_y = self.box.height - self.artist_font:getHeight() - 20 - self.title_font:getHeight()

	local _, _, w, h = Resources.quads.select_bg_overlay:getViewport()
	self.bg_overlay_sx = self.box.width / w
	self.bg_overlay_sy = self.box.height / h
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

	love.graphics.setShader(self.bg_shader)

	for i = 1, 3 do
		if not images[i] then
			break
		end

		if i == 1 then
			love.graphics.setColor(1, 1, 1, 1)
		elseif i == 2 then
			love.graphics.setColor(1, 1, 1, alpha)
		elseif i == 3 then
			love.graphics.setColor(1, 1, 1, 0)
		end

		local img = images[i]
		local iw, ih = img:getDimensions()

		local scale = math.max(h / ih, w / iw)
		local offset_x = (w - (iw * scale)) * 0.5
		local offset_y = (h - (ih * scale)) * 0.5
		lg.draw(img, offset_x, offset_y, 0, scale, scale)
	end

	lg.setColor(1, 1, 1, 1)
	lg.draw(Resources.atlas, Resources.quads.select_bg_overlay, 0, 0, 0, self.bg_overlay_sx, self.bg_overlay_sy)
	love.graphics.setShader()
end

function BackgroundPanel:draw()
	local x, y = lg.transformPoint(0, 0)
	local sw, sh = lg.transformPoint(self.box.width, self.box.height)
	local container_screen_w = math.abs(sw - x)
	local container_screen_h = math.abs(sh - y)
	self.bg_shader:send("container_pos", {x, y})
	self.bg_shader:send("container_size", {container_screen_w, container_screen_h})
	self.bg_shader:send("corner_radius", 8)
	lg.setScissor(x, y, container_screen_w, container_screen_h)

	self:drawBackground()

	lg.setFont(self.artist_font)
	lg.setColor(Colors.accent2)
	lg.print(self.artist, 20, self.artist_y)

	lg.setFont(self.title_font)
	lg.setColor(Colors.text)
	lg.print(self.title, 20, self.title_y)

	if self.ranked then
		local _, _, w, h = Resources.quads.tag_ranked:getViewport()
		lg.draw(Resources.atlas, Resources.quads.tag_ranked, self.box.width - w - 20, self.box.height - h - 20)
	end

	lg.setScissor()
end

return BackgroundPanel
