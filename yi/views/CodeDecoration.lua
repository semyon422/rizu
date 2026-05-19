local View = require("ui.View")
local Painter = require("yi.Painter")
local Path = require("aqua.Path")

---@class yi.CodeDecoration : ui.View
---@overload fun(resources: yi.Resources): yi.CodeDecoration
local CodeDecoration = View + {}

local skipped_directories = {
	[".git"] = true,
	bin = true,
	squashfs_root = true,
	["squashfs-root"] = true,
	temp = true,
	test = true,
	userdata = true,
}

CodeDecoration.code_font_name = "regular"
CodeDecoration.code_font_size = 16

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

---@param resources yi.Resources
function CodeDecoration:new(resources)
	View.new(self)
	self.resources = assert(resources)
	self.time = 0
	self.code_scroll_speed = 18
	self.code_padding_x = 48
	self.code_alpha = 0.22
	self.code_file_count = 5
	self.code_loop_gap = 160
	self.width_percent = 1
	self.height_percent = 1
	self.code_files = load_random_project_code(self.code_file_count)
	self:onLayoutUpdate()
end

---@private
function CodeDecoration:rebuildCodeText()
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

	self.code_text = love.graphics.newTextBatch(self.code_font, code_fragments)
end

function CodeDecoration:onLayoutUpdate()
	self.code_font = self.resources:getScaledFont(self.code_font_name, self.code_font_size, self.ui_scale)
	self:rebuildCodeText()
end

---@param dt number
function CodeDecoration:update(dt)
	self.time = self.time + dt
end

function CodeDecoration:draw()
	local lg = love.graphics
	local text_height = self.code_text:getHeight()
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

return CodeDecoration
