local ModalView = require("ui.ModalView")
local brand = require("brand")
local Resources = require("ui.Resources")
local Colors = require("ui.Colors")
local utf8 = require("utf8")
local utf8validate = require("utf8validate")

---@class ui.modals.ai_chat.AiChat : ui.ModalView
---@operator call: ui.modals.ai_chat.AiChat
---@field model rizu.ai.ChatModel
---@field input string
---@field scroll integer
---@field cached_lines {text: string, color: gui.Color}[]?
---@field cached_wrap_width number?
---@field model_menu_open boolean
---@field model_menu_scroll integer
local AiChat = ModalView + {}

local PADDING = 18
local TITLE_HEIGHT = 48
local INPUT_HEIGHT = 120
local LINE_HEIGHT = 24
local STOP_WIDTH = 72
local STOP_HEIGHT = 32
local LOGIN_WIDTH = 142
local MODEL_X = 170
local MODEL_WIDTH = 300
local MODEL_ROW_HEIGHT = 30

---@param model rizu.ai.ChatModel
---@param on_close fun()
function AiChat:new(model, on_close)
	ModalView.new(self)
	self.model = model
	self.on_close = on_close
	self:setSize(1000, 780)
	self:setAlignment(0.5, 0.5)
	self:setPivot(0.5, 0.5)
	self:setScale(0.95, 0.95)
	self:setOpacity(0)
	self:setVisible(false)
	self:setClip(true)
	self.handles_keyboard_input = true
	self.handles_mouse_input = true
	self.input = ""
	self.scroll = 0
	self.cached_lines = nil
	self.cached_wrap_width = nil
	self.model_menu_open = false
	self.model_menu_scroll = 0
	self.model:onChanged(self)
end

function AiChat:unload()
	self.model:offChanged(self)
end

function AiChat:show()
	self:reset()
	self:setVisible(true)
	self:fadeIn(0.2, "OutCubic")
	self:scaleTo(1, 1, 0.25, "OutQuint")
end

function AiChat:hide()
	self.model:cancel()
	self:scaleTo(0.95, 0.95, 0.18, "InCubic")
	self:transformTo("opacity", 0, 0.15, "InCubic", function()
		self:setVisible(false)
	end)
end

---@param event table
function AiChat:receive(event)
	if event.type == "chat_changed" then
		self.cached_lines = nil
		self.cached_wrap_width = nil
	end
end

---@param e gui.MouseClickEvent
---@return true
function AiChat:onMouseClick(e)
	local x, y = self.world_transform:inverseTransformPoint(e.x, e.y)
	if self.model_menu_open and x >= MODEL_X and x <= MODEL_X + MODEL_WIDTH and y >= TITLE_HEIGHT then
		local index = self.model_menu_scroll + math.floor((y - TITLE_HEIGHT) / MODEL_ROW_HEIGHT) + 1
		if self.model:getModelOptions()[index] then self.model:selectModel(index) end
		self.model_menu_open = false
		return true
	end
	if self.model.busy and x >= self.width - PADDING - STOP_WIDTH and x <= self.width - PADDING
		and y >= 8 and y <= 8 + STOP_HEIGHT
	then
		self.model:cancel()
	elseif self.model:hasAuth() and x >= self.width - PADDING - LOGIN_WIDTH and x <= self.width - PADDING
		and y >= 8 and y <= 8 + STOP_HEIGHT
	then
		local status = self.model:getAuthStatus()
		if status ~= "logging_in" and status ~= "authenticated" then
			self.model:startLogin()
		end
	elseif not self.model.busy and #self.model:getModelOptions() > 0
		and x >= MODEL_X and x <= MODEL_X + MODEL_WIDTH and y >= 8 and y <= 8 + STOP_HEIGHT
	then
		self.model_menu_open = not self.model_menu_open
		self.model_menu_scroll = 0
	else
		self.model_menu_open = false
	end
	return true
end

---@param e gui.ScrollEvent
---@return true
function AiChat:onScroll(e)
	if self.model_menu_open then
		local max_rows = math.floor((self.height - TITLE_HEIGHT) / MODEL_ROW_HEIGHT)
		local max_scroll = math.max(0, #self.model:getModelOptions() - max_rows)
		self.model_menu_scroll = math.max(0, math.min(max_scroll, self.model_menu_scroll - e.direction_y))
	else
		self.scroll = math.max(0, self.scroll + e.direction_y * 3)
	end
	return true
end

function AiChat:reset()
	self.input = ""
	self.scroll = 0
	self.model_menu_open = false
	self.model_menu_scroll = 0
end

---@param e gui.KeyDownEvent
---@return true
function AiChat:onKeyDown(e)
	if e.key == "escape" then
		if self.model.busy then
			self.model:cancel()
		else
			self.on_close()
		end
	elseif e.key == "backspace" then
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
function AiChat:onTextInput(e)
	self.input = utf8validate(self.input .. (e.text or e.key or ""))
	return true
end

---@return {text: string, color: gui.Color}[]
function AiChat:getLines()
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

function AiChat:draw()
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
	local model_options = self.model:getModelOptions()
	if #model_options > 0 then
		love.graphics.setColor(Colors.panel_alt)
		love.graphics.rectangle("fill", MODEL_X, 8, MODEL_WIDTH, STOP_HEIGHT)
		love.graphics.setColor(Colors.text)
		love.graphics.printf(utf8validate(self.model:getSelectedModelLabel()), MODEL_X + 8, 15, MODEL_WIDTH - 16, "left")
		love.graphics.setColor(Colors.text_muted)
	end
	local help = self.model.busy and "Esc stop  •  Ctrl+L clear  •  Shift+Enter newline"
		or "Esc close  •  Ctrl+L clear  •  Shift+Enter newline"
	local auth_status, auth_error = self.model:getAuthStatus()
	local show_auth = self.model:hasAuth() and not self.model.busy
	local help_right = self.model.busy and (PADDING * 2 + STOP_WIDTH)
		or show_auth and (PADDING * 2 + LOGIN_WIDTH) or PADDING
	love.graphics.printf(help, 0, 15, self.width - help_right, "right")
	if self.model.busy then
		local stop_x = self.width - PADDING - STOP_WIDTH
		love.graphics.setColor(Colors.back_button)
		love.graphics.rectangle("fill", stop_x, 8, STOP_WIDTH, STOP_HEIGHT)
		love.graphics.setColor(Colors.text)
		love.graphics.printf("Stop", stop_x, 15, STOP_WIDTH, "center")
	elseif show_auth then
		local login_x = self.width - PADDING - LOGIN_WIDTH
		local login_text = "Login OpenAI"
		local login_color = Colors.accent
		if auth_status == "logging_in" then
			login_text = "Waiting for login"
			login_color = Colors.text_muted
		elseif auth_status == "authenticated" then
			login_text = "OpenAI connected"
			login_color = Colors.accent
		elseif auth_status == "error" then
			login_text = "Retry OpenAI login"
			login_color = Colors.back_button
		end
		love.graphics.setColor(login_color)
		love.graphics.rectangle("fill", login_x, 8, LOGIN_WIDTH, STOP_HEIGHT)
		love.graphics.setColor(Colors.text)
		love.graphics.printf(login_text, login_x, 15, LOGIN_WIDTH, "center")
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
	elseif auth_status == "error" and auth_error then
		love.graphics.setFont(small_font)
		love.graphics.setColor(Colors.back_button)
		love.graphics.printf(utf8validate(auth_error), PADDING, self.height - 24, self.width - PADDING * 2, "right")
	end

	if self.model_menu_open then
		love.graphics.setFont(small_font)
		local max_rows = math.floor((self.height - TITLE_HEIGHT) / MODEL_ROW_HEIGHT)
		local last_index = math.min(#model_options, self.model_menu_scroll + max_rows)
		for index = self.model_menu_scroll + 1, last_index do
			local model_option = model_options[index]
			local y = TITLE_HEIGHT + (index - self.model_menu_scroll - 1) * MODEL_ROW_HEIGHT
			love.graphics.setColor(index == self.model:getSelectedModelIndex() and Colors.accent or Colors.panel_alt)
			love.graphics.rectangle("fill", MODEL_X, y, MODEL_WIDTH, MODEL_ROW_HEIGHT)
			love.graphics.setColor(Colors.text)
			love.graphics.printf(utf8validate(model_option.label), MODEL_X + 8, y + 7, MODEL_WIDTH - 16, "left")
		end
	end
end

return AiChat
