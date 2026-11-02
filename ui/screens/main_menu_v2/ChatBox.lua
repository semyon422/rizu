local View = require("gui.View")
local Painter = require("gui.Painter")
local Colors = require("ui.Colors")
local Resources = require("ui.Resources")
local Textbox = require("ui.views.Textbox")
local UiActions = require("ui.UiActions")

local lg = love.graphics

local INPUT_HEIGHT = 36
local LINE_HEIGHT = 20

---A bare chat to try the server with: the last messages and a textbox, Enter sends.
---@class ui.screens.main_menu_v2.ChatBox : gui.View
---@operator call: ui.screens.main_menu_v2.ChatBox
---@field online rizu.api.Online
---@field notifications rizu.api.Notifications
---@field localization ui.localization.Localization
---@field input ui.views.Textbox
local ChatBox = View + {}

---@param online rizu.api.Online
---@param notifications rizu.api.Notifications
---@param localization ui.localization.Localization
function ChatBox:new(online, notifications, localization)
	View.new(self)
	self.online = online
	self.notifications = notifications
	self.localization = localization
	self.font = Resources.getFont("regular", 14)
	self.input = self:add(Textbox({placeholder = "Message", blur_on_accept = false}))
	self.input:setSize(0, INPUT_HEIGHT):setAlignment(0, 1):fillWidth(0, 0)
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

function ChatBox:draw()
	Painter.setColorRgb(0, 0, 0, 0.5)
	lg.rectangle("fill", 0, 0, self.width, self.height - INPUT_HEIGHT)
	Painter.setColorTable(Colors.text)
	lg.setFont(self.font)
	local messages = self.online:getChatMessages()
	local lines = math.floor((self.height - INPUT_HEIGHT) / LINE_HEIGHT)
	for row = 0, math.min(lines, #messages) - 1 do
		local msg = messages[#messages - row]
		lg.print(msg.user_name .. ": " .. msg.text, 6, self.height - INPUT_HEIGHT - (row + 1) * LINE_HEIGHT)
	end
end

return ChatBox
