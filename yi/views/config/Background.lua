local View = require("ui.View")
local Painter = require("yi.Painter")

---@class yi.config.Background : ui.View
---@operator call: yi.config.Background
local Background = View + {}

local Path = require("aqua.Path")

local crt_shader_code = [[
	extern float time;

	vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
		vec4 tex = Texel(texture, texture_coords) * color;

		float scanline = 0.992 + 0.008 * sin(screen_coords.y * 1.05);
		float moving_pos = mod(time * 140.0, 1400.0) - 120.0;
		float moving_line = exp(-pow((screen_coords.y - moving_pos) / 70.0, 2.0)) * 0.08;

		tex.rgb *= scanline;
		tex.rgb += moving_line;
		tex.rgb *= 1.01;
		return tex;
	}
]]

local skipped_directories = {
	[".git"] = true,
	bin = true,
	squashfs_root = true,
	["squashfs-root"] = true,
	temp = true,
	test = true,
	userdata = true,
}

Background.code_font_name = "regular"
Background.code_font_size = 16

---@param t number
---@param length number
---@return number
local function ping_pong(t, length)
	if length <= 0 then
		return 0
	end
	local cycle = t % (length * 2)
	if cycle > length then
		return length * 2 - cycle
	end
	return cycle
end

---@param t number
---@param length number
---@return number
local function smooth_ping_pong(t, length)
	if length <= 0 then
		return 0
	end
	local p = ping_pong(t, length) / length
	local eased = p * p * (3 - 2 * p)
	return eased * length
end

---@param path string
---@return boolean
local function is_allowed_text_file(path)
	local extension = Path(path):getExtension()
	return extension == "lua"
end

---@param content string
---@return boolean
local function is_probably_text(content)
	return not content:find("\0", 1, true)
end

---@param path string
---@param out string[]
local function collect_project_files(path, out)
	for _, item in ipairs(love.filesystem.getDirectoryItems(path)) do
		local child_path = path == "" and item or (path .. "/" .. item)
		local info = love.filesystem.getInfo(child_path)
		if info then
			if info.type == "directory" then
				if not skipped_directories[item] then
					collect_project_files(child_path, out)
				end
			elseif info.type == "file" and info.size and info.size <= 128 * 1024 and is_allowed_text_file(child_path) then
				out[#out + 1] = child_path
			end
		end
	end
end

---@param count integer?
---@return {path: string, content: string}[]
local function load_random_project_code(count)
	count = count or 5
	local candidates = {}
	collect_project_files("rizu", candidates)

	for i = #candidates, 2, -1 do
		local j = love.math.random(i)
		candidates[i], candidates[j] = candidates[j], candidates[i]
	end

	local files = {}
	for _, path in ipairs(candidates) do
		local content = love.filesystem.read(path)
		if content and is_probably_text(content) then
			files[#files + 1] = {path = path, content = content}
			if #files >= count then
				break
			end
		end
	end

	if #files == 0 then
		files[1] = {
			path = "rizu",
			content = "-- No readable project source file found."
		}
	end

	return files
end

---@private
function Background:rebuildCodeText()
	local code_fragments = {}
	for i, file in ipairs(self.code_files) do
		code_fragments[#code_fragments + 1] = {0.65, 0.95, 1, 0.5}
		code_fragments[#code_fragments + 1] = file.path .. "\n\n"
		code_fragments[#code_fragments + 1] = {0.9, 0.98, 1, 1}
		code_fragments[#code_fragments + 1] = file.content
		if i < #self.code_files then
			code_fragments[#code_fragments + 1] = {0.65, 0.95, 1, 0.35}
			code_fragments[#code_fragments + 1] = "\n\n--------------------------------\n\n"
		end
	end

	self.code_text = love.graphics.newText(self.code_font, code_fragments)
end

---@param image love.Image
---@param resources yi.Resources
function Background:new(image, resources)
	View.new(self)
	self.image = assert(image)
	self.resources = assert(resources)
	self.image:setFilter("linear", "linear")
	self.scale_factor = 1.35
	self.speed_x = 18
	self.speed_y = 12
	self.time = 0
	self.code_scroll_speed = 18
	self.code_padding_x = 48
	self.code_alpha = 0.22
	self.code_file_count = 5
	self.code_loop_gap = 160
	self.shader = love.graphics.newShader(crt_shader_code)
	self.width_percent = 1
	self.height_percent = 1
	self.code_files = load_random_project_code(self.code_file_count)
	self:onResolutionChanged()
end

function Background:onResolutionChanged()
	self.code_font = self.resources:getScaledFont(self.code_font_name, self.code_font_size, self.ui_scale)
	self:rebuildCodeText()
end

---@param dt number
function Background:update(dt)
	self.time = self.time + dt
end

function Background:draw()
	local lg = love.graphics
	local ww, wh = self.width, self.height
	local iw, ih = self.image:getDimensions()
	local cover_scale = math.max(ww / iw, wh / ih) * self.scale_factor
	local scaled_w = iw * cover_scale
	local scaled_h = ih * cover_scale
	local overflow_x = math.max(0, scaled_w - ww)
	local overflow_y = math.max(0, scaled_h - wh)
	local x = -smooth_ping_pong(self.time * self.speed_x, overflow_x)
	local y = -smooth_ping_pong(self.time * self.speed_y, overflow_y)

	lg.push("all")
	self.shader:send("time", self.time)
	lg.setShader(self.shader)
	lg.setColor(1, 1, 1, 1)
	lg.draw(self.image, x, y, 0, cover_scale, cover_scale)
	lg.pop()

	local text_height = self:toLogicalSize(self.code_text:getHeight())
	local loop_height = text_height + self.code_loop_gap
	local scroll_offset = (self.time * self.code_scroll_speed) % loop_height
	local first_text_y = 32 - scroll_offset

	lg.push("all")
	lg.setBlendMode("add")
	lg.setColor(1, 1, 1, self.code_alpha)
	-- Should be drawn unsnapped because it's always animated
	Painter.draw(self.code_text, self.code_padding_x, first_text_y)
	Painter.draw(self.code_text, self.code_padding_x, first_text_y + loop_height)
	lg.pop()
end

return Background
