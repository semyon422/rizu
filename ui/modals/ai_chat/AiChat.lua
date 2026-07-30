local ModalView = require("ui.ModalView")
local brand = require("brand")
local Resources = require("ui.Resources")
local Colors = require("ui.Colors")
local json = require("web.json")
local utf8 = require("utf8")
local utf8validate = require("utf8validate")

---@class ui.modals.ai_chat.AiChat : ui.ModalView
---@operator call: ui.modals.ai_chat.AiChat
---@field model rizu.ai.ChatModel
---@field input string
---@field scroll integer
---@field cached_lines ui.ai_chat.TranscriptLine[]?
---@field cached_wrap_width number?
---@field preserve_line_count integer?
---@field expanded_tools {[string]: boolean}
---@field model_menu_open boolean
---@field model_menu_scroll integer
---@class ui.ai_chat.TranscriptLine
---@field text string
---@field color gui.Color
---@field tool_call_id string?
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
local TOOL_PREVIEW_LINES = 5
local TOOL_PREVIEW_CHARS = 1200
local TOOL_ARGUMENT_CHARS = 240
local SCROLLBAR_WIDTH = 8
local JUMP_WIDTH = 128
local JUMP_HEIGHT = 28

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
	self.preserve_line_count = nil
	self.expanded_tools = {}
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
		if self.scroll > 0 and self.cached_lines and not self.preserve_line_count then
			self.preserve_line_count = #self.cached_lines
		end
		self.cached_lines = nil
		self.cached_wrap_width = nil
	end
end

---@return integer
function AiChat:getVisibleLineCount()
	return math.max(1, math.floor((self.height - TITLE_HEIGHT - INPUT_HEIGHT - PADDING * 2) / LINE_HEIGHT))
end

---@param lines ui.ai_chat.TranscriptLine[]?
---@return integer
function AiChat:getMaxScroll(lines)
	lines = lines or self:getLines()
	return math.max(0, #lines - self:getVisibleLineCount())
end

---@param lines ui.ai_chat.TranscriptLine[]?
function AiChat:clampScroll(lines)
	self.scroll = math.floor(math.max(0, math.min(self:getMaxScroll(lines), self.scroll)) + 0.5)
end

---@param lines ui.ai_chat.TranscriptLine[]
---@return integer first
---@return integer last
function AiChat:getVisibleRange(lines)
	self:clampScroll(lines)
	local last = math.max(0, #lines - self.scroll)
	local first = math.max(1, last - self:getVisibleLineCount() + 1)
	return first, last
end

---@param tool_call_id string
function AiChat:toggleTool(tool_call_id)
	if self.scroll > 0 and self.cached_lines then
		self.preserve_line_count = #self.cached_lines
	end
	self.expanded_tools[tool_call_id] = not self.expanded_tools[tool_call_id]
	self.cached_lines = nil
	self.cached_wrap_width = nil
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
	if self.scroll > 0 and x >= self.width - PADDING - JUMP_WIDTH and x <= self.width - PADDING
		and y >= self.height - INPUT_HEIGHT - PADDING - JUMP_HEIGHT
		and y <= self.height - INPUT_HEIGHT - PADDING
	then
		self.scroll = 0
		return true
	end
	if y >= TITLE_HEIGHT + PADDING and y < self.height - INPUT_HEIGHT - PADDING then
		local lines = self:getLines()
		local first, last = self:getVisibleRange(lines)
		local row = math.floor((y - TITLE_HEIGHT - PADDING) / LINE_HEIGHT)
		local line = lines[first + row]
		if line and first + row <= last and line.tool_call_id then
			self:toggleTool(line.tool_call_id)
			return true
		end
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
		self.scroll = self.scroll + e.direction_y * 3
		self:clampScroll()
	end
	return true
end

function AiChat:reset()
	self.input = ""
	self.scroll = 0
	self.preserve_line_count = nil
	self.expanded_tools = {}
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
		self:clampScroll()
	elseif e.key == "pagedown" then
		self.scroll = self.scroll - 10
		self:clampScroll()
	elseif e.key == "home" then
		self.scroll = self:getMaxScroll()
	elseif e.key == "end" then
		self.scroll = 0
	end
	return true
end

---@param e gui.TextInputEvent
---@return true
function AiChat:onTextInput(e)
	self.input = utf8validate(self.input .. (e.text or e.key or ""))
	return true
end

---@param lines ui.ai_chat.TranscriptLine[]
---@param font love.Font
---@param text string
---@param wrap_width number
---@param color gui.Color
---@param tool_call_id string?
local function addWrapped(lines, font, text, wrap_width, color, tool_call_id)
	local _, wrapped = font:getWrap(utf8validate(text), wrap_width)
	for _, line in ipairs(wrapped) do
		table.insert(lines, {text = line, color = color, tool_call_id = tool_call_id})
	end
end

---@param arguments string?
---@return string
local function compactArguments(arguments)
	if type(arguments) ~= "string" or arguments == "" then return "" end
	local decoded = json.decode_safe(arguments)
	local compact = decoded and json.encode(decoded) or arguments
	compact = utf8validate(compact:gsub("%s+", " "))
	if #compact > TOOL_ARGUMENT_CHARS then
		compact = utf8validate(compact:sub(1, TOOL_ARGUMENT_CHARS)) .. "…"
	end
	return compact
end

---@param content string
---@return string preview
---@return boolean truncated
---@return integer total_lines
local function previewToolResult(content)
	local source_lines = {}
	for line in (content .. "\n"):gmatch("(.-)\n") do
		local clean_line = line:gsub("\r$", "")
		table.insert(source_lines, clean_line)
	end
	local visible = {}
	for index = 1, math.min(#source_lines, TOOL_PREVIEW_LINES) do
		table.insert(visible, source_lines[index])
	end
	local preview = table.concat(visible, "\n")
	local truncated = #visible < #source_lines or #preview > TOOL_PREVIEW_CHARS
	if #preview > TOOL_PREVIEW_CHARS then
		preview = utf8validate(preview:sub(1, TOOL_PREVIEW_CHARS))
	end
	return preview, truncated, #source_lines
end

---@param entry rizu.ai.ChatEntry
---@return string
local function toolStatusLabel(entry)
	if entry.status == "running" then return "running" end
	if entry.status == "error" then return "error" end
	if entry.status == "canceled" then return "canceled" end
	return "ok"
end

---@return ui.ai_chat.TranscriptLine[]
function AiChat:getLines()
	local font = Resources.getFont("regular", 20)
	local wrap_width = self.width - PADDING * 2 - SCROLLBAR_WIDTH - 4
	if self.cached_lines and self.cached_wrap_width == wrap_width then
		return self.cached_lines
	end
	---@type ui.ai_chat.TranscriptLine[]
	local lines = {}
	local role_colors = {
		user = Colors.accent,
		assistant = Colors.text,
		tool = Colors.text_muted,
		error = Colors.back_button,
	}
	for _, entry in ipairs(self.model.entries) do
		if entry.role == "tool" and entry.tool_call_id then
			local arguments = compactArguments(entry.arguments)
			local header = ("[%s] %s"):format(toolStatusLabel(entry), entry.name or "tool")
			if arguments ~= "" then header = header .. "  " .. arguments end
			local status_color = entry.status == "error" and Colors.back_button
				or entry.status == "running" and Colors.accent or Colors.play_button
			addWrapped(lines, font, header, wrap_width, status_color, entry.tool_call_id)
			if entry.content ~= "" then
				local expanded = self.expanded_tools[entry.tool_call_id]
				local output, truncated, total_lines = previewToolResult(entry.content)
				if expanded then
					output = entry.content
				end
				addWrapped(lines, font, output, wrap_width, Colors.text_muted, entry.tool_call_id)
				if expanded then
					table.insert(lines, {
						text = "Click to collapse",
						color = Colors.accent,
						tool_call_id = entry.tool_call_id,
					})
				elseif truncated then
					table.insert(lines, {
						text = ("… %d lines, %d bytes total — click to expand"):format(total_lines, #entry.content),
						color = Colors.accent,
						tool_call_id = entry.tool_call_id,
					})
				end
			end
		else
			local label = entry.name and (entry.role .. " " .. entry.name) or entry.role
			local text = ("[%s] %s"):format(label, entry.content)
			addWrapped(lines, font, text, wrap_width, role_colors[entry.role] or Colors.text)
		end
		table.insert(lines, {text = "", color = Colors.text})
	end
	if self.preserve_line_count then
		self.scroll = self.scroll + #lines - self.preserve_line_count
		self.preserve_line_count = nil
	end
	self:clampScroll(lines)
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
	local first, last = self:getVisibleRange(lines)
	love.graphics.setFont(font)
	local y = TITLE_HEIGHT + PADDING
	for i = first, last do
		love.graphics.setColor(lines[i].color)
		love.graphics.print(lines[i].text, PADDING, y)
		y = y + LINE_HEIGHT
	end
	local max_scroll = self:getMaxScroll(lines)
	if max_scroll > 0 then
		local track_y = TITLE_HEIGHT + PADDING
		local track_height = self.height - TITLE_HEIGHT - INPUT_HEIGHT - PADDING * 2
		local thumb_height = math.max(28, track_height * self:getVisibleLineCount() / #lines)
		local scroll_from_top = max_scroll - self.scroll
		local thumb_y = track_y + (track_height - thumb_height) * scroll_from_top / max_scroll
		love.graphics.setColor(Colors.outline)
		love.graphics.rectangle("fill", self.width - PADDING - SCROLLBAR_WIDTH, track_y, SCROLLBAR_WIDTH, track_height)
		love.graphics.setColor(Colors.text_muted)
		love.graphics.rectangle("fill", self.width - PADDING - SCROLLBAR_WIDTH, thumb_y, SCROLLBAR_WIDTH, thumb_height)
	end
	if self.scroll > 0 then
		local jump_x = self.width - PADDING - JUMP_WIDTH
		local jump_y = self.height - INPUT_HEIGHT - PADDING - JUMP_HEIGHT
		love.graphics.setColor(Colors.hover)
		love.graphics.rectangle("fill", jump_x, jump_y, JUMP_WIDTH, JUMP_HEIGHT)
		love.graphics.setFont(small_font)
		love.graphics.setColor(Colors.text)
		love.graphics.printf("Jump to latest", jump_x, jump_y + 6, JUMP_WIDTH, "center")
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
