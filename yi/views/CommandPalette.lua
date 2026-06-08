local View = require("gui.View")
local Resources = require("yi.Resources")
local Colors = require("yi.Colors")
local utf8 = require("utf8")

---@class yi.views.CommandPalette : gui.View
---@operator call: yi.views.CommandPalette
---@field prompt string?
local CommandPalette = View + {}

local CELL_HEIGHT = 40

---@param state yi.command_palette.PaletteState
---@param on_close function
function CommandPalette:new(state, on_close)
	View.new(self)
	self.state = state
	self.on_close = on_close
	self:setSize(800, 600)
	self:setPivot(0.5, 0.5)
	self.names = love.graphics.newTextBatch(Resources.getFont("regular", 24))
	self.descriptions = love.graphics.newTextBatch(Resources.getFont("regular", 16))
	self.handles_keyboard_input = true
	self.query = ""
	self.state:setQuery(self.query)
	self:updateText()
end

function CommandPalette:reset()
	self.query = ""
	self.prompt = nil
	self.state:reset()
	self:updateText()
end

function CommandPalette:onKeyDown(e)
	if e.key == "backspace" then
		if #self.query > 0 then
			local byte_offset = utf8.offset(self.query, -1)
			if byte_offset then
				self.query = self.query:sub(1, byte_offset - 1)
			end
			self.state:setQuery(self.query)
			self:updateText()
		end
	elseif e.key == "return" then
		local c = self.state:getCandidates()
		local success, err, executed = self.state:confirmSelection(c[1])

		if not success then
			print(err)
			return true
		end

		if executed then
			self.on_close()
			return true
		end

		if self.state:isArgumentMode() then
			self.query = ""
			self.prompt	= self.state:getPromptText()
			self:updateText()
		end
	end
	return true
end

function CommandPalette:onTextInput(e)
	self.query = self.query .. e.key
	self.state:setQuery(self.query)
	self:updateText()
	return true
end

function CommandPalette:updateText()
	local c = self.state:getCandidates()

	self.names:clear()
	self.descriptions:clear()

	if self.prompt then
		self.names:add(("%s %s"):format(self.prompt, self.query))
	else
		self.names:add(self.query)
	end

	for i, v in ipairs(c) do
		self.names:add(v.title, 0, i * CELL_HEIGHT)
	end
end

function CommandPalette:draw()
	love.graphics.setColor(Colors.background)
	love.graphics.draw(Resources.atlas, Resources.quads.pixel, 0, 0, 0, self.width, self.height)
	love.graphics.setColor(Colors.line)
	love.graphics.draw(Resources.atlas, Resources.quads.pixel, 0, 0, 0, self.width, CELL_HEIGHT)

	love.graphics.setBlendMode("add")
	love.graphics.setColor(Colors.line)
	love.graphics.draw(Resources.atlas, Resources.quads.pixel, 0, -2, 0, self.width, 2)
	love.graphics.draw(Resources.atlas, Resources.quads.pixel, -2, -2, 0, 2, self.height + 2)
	love.graphics.draw(Resources.atlas, Resources.quads.pixel, -2, self.height, 0, self.width + 4, 2)
	love.graphics.draw(Resources.atlas, Resources.quads.pixel, self.width, -2, 0, 2, self.height + 2)

	love.graphics.setColor(Colors.text)
	love.graphics.draw(self.names, 5, 5)
end

return CommandPalette
