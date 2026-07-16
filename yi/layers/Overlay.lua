local Screen = require("gui.Screen")
local CommandPalette = require("yi.views.CommandPalette")
local AiChatView = require("yi.views.AiChatView")

---@class yi.layers.Overlay : gui.Screen
---@operator call: yi.layers.Overlay
local Overlay = Screen + {}

---@param yi yi.UserInterface
function Overlay:new(yi)
	Screen.new(self)
	self.palette = CommandPalette(yi.command_palette, function()
		self:detachPalette()
	end)
	self.ai_chat = AiChatView(yi.game.aiChatModel, function()
		self:detachChat()
	end)
	self.palette_attached = false
	self.chat_attached = false
	table.insert(self.hidden_views, self.palette)
	table.insert(self.hidden_views, self.ai_chat)
end

function Overlay:load()
	Screen.load(self)
end

---@return boolean
function Overlay:attachPalette()
	if self.palette_attached then
		return false
	end
	self:detachChat()
	self:showView(self.palette)
	self.palette:reset()
	self.palette_attached = true
	return true
end

---@return boolean
function Overlay:attachChat()
	if self.chat_attached then
		return false
	end
	self:detachPalette()
	self:showView(self.ai_chat)
	self.ai_chat:reset()
	self.chat_attached = true
	return true
end

---@return boolean
function Overlay:detachChat()
	if not self.chat_attached then
		return false
	end
	self.ai_chat.model:cancel()
	self:hideView(self.ai_chat)
	self.chat_attached = false
	return true
end

---@return boolean
function Overlay:detachPalette()
	if not self.palette_attached then
		return false
	end
	self:hideView(self.palette)
	self.palette_attached = false
	return true
end

function Overlay:handleKeyDown(key)
	if key == ";" and love.keyboard.isDown("rshift", "lshift") then
		return self:attachPalette()
	end

	if key == "escape" then
		if self.chat_attached and self.ai_chat.model.busy then
			return self.ai_chat.model:cancel()
		end
		return self:detachPalette() or self:detachChat()
	end
end

return Overlay
