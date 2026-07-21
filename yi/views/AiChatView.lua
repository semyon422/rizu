local View = require("gui.View")
local brand = require("brand")
local Resources = require("yi.Resources")
local Colors = require("yi.Colors")
local utf8 = require("utf8")
local utf8validate = require("utf8validate")

---@class yi.views.AiChatView : gui.View
---@operator call: yi.views.AiChatView
---@field model rizu.ai.ChatModel
---@field input string
---@field scroll integer
---@field cached_lines {text: string, color: gui.Color}[]?
---@field cached_wrap_width number?
local AiChatView = View + {}

local PADDING = 18
local TITLE_HEIGHT = 48
local INPUT_HEIGHT = 120
local LINE_HEIGHT = 24
local STOP_WIDTH = 72
local STOP_HEIGHT = 32

---@param model rizu.ai.ChatModel
---@param on_close fun()
function AiChatView:new(model, on_close)
	View.new(self)
	self.model = model
	self.on_close = on_close
	self:setSize(1000, 780)
	self:setPivot(0.5, 0.5)
	self.handles_keyboard_input = true
	self.handles_mouse_input = true
	self.input = ""
	self.scroll = 0
	self.cached_lines = nil
	self.cached_wrap_width = nil
	self.model:onChanged(self)
end

---@param event table
function AiChatView:receive(event)
	if event.type == "chat_changed" then
		self.cached_lines = nil
		self.cached_wrap_width = nil
	end
end

---@param e gui.MouseClickEvent
---@return true
function AiChatView:onMouseClick(e)
	local x, y = self.transform:inverseTransformPoint(e.x, e.y)
	if self.model.busy and x >= self.width - PADDING - STOP_WIDTH and x <= self.width - PADDING
		and y >= 8 and y <= 8 + STOP_HEIGHT
	then
		self.model:cancel()
	end
	return true
end

function AiChatView:reset()
	self.input = ""
	self.scroll = 0
end

---@param e gui.KeyDownEvent
---@return true
function AiChatView:onKeyDown(e)
	if e.key == "backspace" then
		local byte_offset = utf8.offset(self.input, -1)
		if byte_offset then
			self.input = self.input:sub(1, byte_offset - 1)
		end
	elseif e.key == "return" or e.key == "kpenter" then
		if e.shift_pressed then
			self.input = self.input .. "\n"
		else
			local sent = self.model:send(self.input)
			if sent then
				self.input = ""
				self.scroll = 0
			end
		end
	elseif e.control_pressed and e.key == "l" then
		self.model:clear()
		self.scroll = 0
	elseif e.control_pressed and e.key == "v" then
		self.input = utf8validate(self.input .. love.system.getClipboardText())
	elseif e.key == "pageup" then
		self.scroll = self.scroll + 10
	elseif e.key == "pagedown" then
		self.scroll = math.max(0, self.scroll - 10)
	end
	return true
end

---@param e gui.TextInputEvent
---@return true
function AiChatView:onTextInput(e)
	self.input = utf8validate(self.input .. e.key)
	return true
end

---@return {text: string, color: gui.Color}[]
function AiChatView:getLines()
	local font = Resources.getFont("regular", 20)
	local wrap_width = self.width - PADDING * 2
	if self.cached_lines and self.cached_wrap_width == wrap_width then
		return self.cached_lines
	end
	local lines = {}
	local role_colors = {
		user = Colors.accent,
		assistant = Colors.text,
		tool = Colors.text_muted,
		error = Colors.back_button,
	}
	for _, entry in ipairs(self.model.entries) do
		local label = entry.name and (entry.role .. " " .. entry.name) or entry.role
		local text = utf8validate(("[%s] %s"):format(label, entry.content))
		local _, wrapped = font:getWrap(text, wrap_width)
		for _, line in ipairs(wrapped) do
			table.insert(lines, {text = line, color = role_colors[entry.role] or Colors.text})
		end
		table.insert(lines, {text = "", color = Colors.text})
	end
	self.cached_lines = lines
	self.cached_wrap_width = wrap_width
	return lines
end

function AiChatView:draw()
	local font = Resources.getFont("regular", 20)
	local small_font = Resources.getFont("regular", 16)
	love.graphics.setColor(Colors.panel)
	love.graphics.rectangle("fill", 0, 0, self.width, self.height)
	love.graphics.setColor(Colors.outline)
	love.graphics.setLineWidth(2)
	love.graphics.rectangle("line", 0, 0, self.width, self.height)
	love.graphics.rectangle("line", 0, TITLE_HEIGHT, self.width, self.height - TITLE_HEIGHT - INPUT_HEIGHT)

	love.graphics.setFont(font)
	love.graphics.setColor(Colors.text)
	love.graphics.print(brand.name .. " AI", PADDING, 12)
	love.graphics.setFont(small_font)
	love.graphics.setColor(Colors.text_muted)
	local help = self.model.busy and "Esc stop  •  Ctrl+L clear  •  Shift+Enter newline"
		or "Esc close  •  Ctrl+L clear  •  Shift+Enter newline"
	local help_right = self.model.busy and (PADDING * 2 + STOP_WIDTH) or PADDING
	love.graphics.printf(help, 0, 15, self.width - help_right, "right")
	if self.model.busy then
		local stop_x = self.width - PADDING - STOP_WIDTH
		love.graphics.setColor(Colors.back_button)
		love.graphics.rectangle("fill", stop_x, 8, STOP_WIDTH, STOP_HEIGHT)
		love.graphics.setColor(Colors.text)
		love.graphics.printf("Stop", stop_x, 15, STOP_WIDTH, "center")
	end

	local lines = self:getLines()
	local visible_count = math.floor((self.height - TITLE_HEIGHT - INPUT_HEIGHT - PADDING * 2) / LINE_HEIGHT)
	local last = math.max(0, #lines - self.scroll)
	local first = math.max(1, last - visible_count + 1)
	love.graphics.setFont(font)
	local y = TITLE_HEIGHT + PADDING
	for i = first, last do
		love.graphics.setColor(lines[i].color)
		love.graphics.print(lines[i].text, PADDING, y)
		y = y + LINE_HEIGHT
	end

	local input_y = self.height - INPUT_HEIGHT
	love.graphics.setColor(Colors.panel_alt)
	love.graphics.rectangle("fill", 0, input_y, self.width, INPUT_HEIGHT)
	love.graphics.setFont(font)
	love.graphics.setColor(Colors.text)
	local prompt = utf8validate(self.input)
	if prompt == "" then
		love.graphics.setColor(Colors.text_muted)
		prompt = "Type a message and press Enter..."
	end
	love.graphics.printf(prompt, PADDING, input_y + PADDING, self.width - PADDING * 2, "left")
	if self.model.busy then
		love.graphics.setFont(small_font)
		love.graphics.setColor(Colors.accent)
		love.graphics.printf("Streaming...", 0, self.height - 24, self.width - PADDING, "right")
	end
end

return AiChatView
