local Screen = require("gui.Screen")
local CommandPalette = require("yi.views.CommandPalette")

---@class yi.layers.Overlay : gui.Screen
---@operator call: yi.layers.Overlay
local Overlay = Screen + {}

---@param yi yi.UserInterface
function Overlay:new(yi)
	Screen.new(self)
	self.palette = CommandPalette(yi.command_palette, function()
		self:detachPalette()
	end)
	self.palette_attached = false
	table.insert(self.hidden_views, self.palette)
end

function Overlay:load()
	Screen.load(self)
end

---@return boolean
function Overlay:attachPalette()
	if self.palette_attached then
		return false
	end
	self:showView(self.palette)
	self.palette:reset()
	self.palette_attached = true
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
		return self:detachPalette()
	end
end

return Overlay
