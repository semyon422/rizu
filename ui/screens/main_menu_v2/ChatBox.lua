local View = require("gui.View")
local Painter = require("gui.Painter")
local Colors = require("ui.Colors")
local Resources = require("ui.Resources")
local Textbox = require("ui.views.Textbox")
local UiActions = require("ui.UiActions")

local lg = love.graphics

local INPUT_HEIGHT = 36
local GAP = 6
local PADDING_X = 10
-- Idle, only the newest messages show over the background, fading out upward.
local MINIMIZED_MESSAGES = 5
local FADE_HEIGHT = 48
---@type {[string]: gui.Color}
local ROLE_COLORS = {admin = Colors.danger, donator = Colors.yellow}
local ROLE_LABELS = {admin = "main_menu.chat_admin", donator = "main_menu.chat_supporter"}

-- Fades out what it draws above u_bottom, to nothing at u_top. In pixels of the current target.
local fade_code = [[
extern float u_top;
extern float u_bottom;

vec4 effect(vec4 color, Image tex, vec2 uv, vec2 screen_coords) {
	vec4 c = Texel(tex, uv) * color;
	c.a *= clamp((screen_coords.y - u_top) / (u_bottom - u_top), 0.0, 1.0);
	return c;
}
]]

---@type love.Shader?
local fade_shader

---The textbox with the newest messages above it. Focused, it shows as many messages as fit on a panel.
---@class ui.screens.main_menu_v2.ChatBox : gui.View
---@operator call: ui.screens.main_menu_v2.ChatBox
---@field online rizu.api.Online
---@field notifications rizu.api.Notifications
---@field localization ui.localization.Localization
---@field input ui.views.Textbox
---@field font love.Font
---@field unsubscribe fun()?
local ChatBox = View + {}

---@param online rizu.api.Online
---@param notifications rizu.api.Notifications
---@param localization ui.localization.Localization
function ChatBox:new(online, notifications, localization)
	View.new(self)
	self.online = online
	self.notifications = notifications
	self.localization = localization
	self.font = Resources.getFont("medium", 17)
	self.input = self:add(Textbox({blur_on_accept = false}))
	self.input:setSize(0, INPUT_HEIGHT):setAlignment(0, 1):fillWidth(0, 0)
end

function ChatBox:load()
	self.unsubscribe = self.online:on("account_changed", function() self:updateInput() end)
	self:updateInput()
end

function ChatBox:unload()
	if self.unsubscribe then
		self.unsubscribe()
		self.unsubscribe = nil
	end
end

---Only a logged in player on a connection can send; otherwise the textbox says why it is off.
---@private
function ChatBox:updateInput()
	local key = "main_menu.chat_placeholder"
	if not self.online:isConnected() then
		key = "main_menu.chat_offline"
	elseif not self.online:isLoggedIn() then
		key = "main_menu.chat_log_in"
	end
	local can_send = key == "main_menu.chat_placeholder"
	self.input.placeholder = self.localization:get(key)
	self.input:setEnabled(can_send):setOpacity(can_send and 1 or 0.5)
end

---@param inputs gui.Inputs
function ChatBox:onHandleInputs(inputs)
	if not self.input.focused then return end
	if inputs:consumeActionJustPressed(UiActions.accept) then
		local text = self.input:getText()
		if text ~= "" then
			self.input:setText("")
			self.online:sendChatMessage(text, function(ok, err)
				if ok then return end
				self.notifications:post("error", "chat_send_failed", self.localization:get("main_menu.chat_send_failed"), err)
				-- Gives the message back unless something new was typed meanwhile.
				if self.input:getText() == "" then self.input:setText(text) end
			end)
		end
	end
end

---@private
---@param msg sea.chat.ChatMessage
---@return table colored_text
---@return string plain the same text, to measure
function ChatBox:formatMessage(msg)
	local role = msg.role
	local name = msg.user_name .. ": "
	local color = Colors.text
	if role then
		name = self.localization:get(ROLE_LABELS[role]) .. " " .. name
		color = ROLE_COLORS[role]
	end
	return {color, name, Colors.text, msg.text}, name .. msg.text
end

---Newest at the bottom, wrapped, up to the top of the box: MINIMIZED_MESSAGES of them unless focused.
---@return {text: table, y: number}[] lines newest first
function ChatBox:layoutLines()
	local bottom = self.height - INPUT_HEIGHT - GAP
	local wrap_width = self.width - PADDING_X * 2
	local line_height = self.font:getHeight()
	local messages = self.online:getChatMessages()
	local count = self.input.focused and #messages or math.min(#messages, MINIMIZED_MESSAGES)
	local y = bottom
	local lines = {} ---@type {text: table, y: number}[]
	for i = #messages, #messages - count + 1, -1 do
		local text, plain = self:formatMessage(messages[i])
		local _, wrapped = self.font:getWrap(plain, wrap_width)
		y = y - #wrapped * line_height
		if y < 0 then break end
		lines[#lines + 1] = {text = text, y = y}
	end
	return lines
end

function ChatBox:draw()
	local focused = self.input.focused
	local bottom = self.height - INPUT_HEIGHT - GAP
	local wrap_width = self.width - PADDING_X * 2
	local lines = self:layoutLines()
	if #lines == 0 and not focused then return end

	-- Focused, the messages sit on a solid panel; idle, they fade out upward over the background.
	local previous = lg.getShader()
	if focused then
		Painter.setColorRgb(0, 0, 0, 0.55)
		lg.rectangle("fill", 0, 0, self.width, bottom + GAP / 2, 8, 8)
	else
		fade_shader = fade_shader or lg.newShader(fade_code)
		local top = lines[#lines].y
		local _, fade_top = lg.transformPoint(0, top)
		local _, fade_bottom = lg.transformPoint(0, top + FADE_HEIGHT)
		fade_shader:send("u_top", fade_top)
		fade_shader:send("u_bottom", fade_bottom)
		lg.setShader(fade_shader)
	end
	lg.setFont(self.font)
	Painter.setColorRgb(1, 1, 1, 1)
	for _, line in ipairs(lines) do
		lg.printf(line.text, PADDING_X, line.y, wrap_width)
	end

	lg.setShader(previous)
end

return ChatBox
