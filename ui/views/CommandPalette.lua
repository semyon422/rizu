local Painter = require("gui.Painter")
local View = require("gui.View")
local Resources = require("ui.Resources")
local utf8 = require("utf8")

---@class ui.views.CommandPalette : gui.View
---@operator call: ui.views.CommandPalette
---@field prompt string?
---@field needle_model rizu.ai.NeedleModel?
---@field needle_tools rizu.ai.NeedleToolRegistry?
local CommandPalette = View + {}

local CELL_HEIGHT = 40
local SCALE_INACTIVE = 0.95
local Y_INACTIVE = -20

---@param state ui.command_palette.PaletteState
---@param on_close function
---@param needle_model rizu.ai.NeedleModel
---@param needle_tools rizu.ai.NeedleToolRegistry
function CommandPalette:new(state, on_close, needle_model, needle_tools)
	View.new(self)
	self.state = state
	self.on_close = on_close
	self.needle_model = needle_model
	self.needle_tools = needle_tools
	self:anchorFixed(0, 0, 800, 600)
	self:setAlignment(0.5, 0.5)
	self:setPivot(0.5, 0.5)
	self:setScale(SCALE_INACTIVE, SCALE_INACTIVE)
	self:setOpacity(0)
	self:setOffset(0, Y_INACTIVE)
	self:setVisible(false)
	self.names = love.graphics.newTextBatch(Resources.getFont("regular", 24))
	self.descriptions = love.graphics.newTextBatch(Resources.getFont("regular", 16))
	self.handles_keyboard_input = true
	self.query = ""
	self.selected_index = 1
	self.candidates = {}
	self.state:setQuery(self.query)
	self:updateText()
end

function CommandPalette:reset()
	if self.needle_model then self.needle_model:cancel() end
	self.query = ""
	self.prompt = nil
	self.selected_index = 1
	self.state:reset()
	self:updateText()
end

function CommandPalette:show()
	self:setVisible(true)
	self:fadeIn(0.2, "OutCubic")
	self:moveToY(0, 0.25, "OutQuint")
	self:scaleTo(1, 1, 0.25, "OutQuint")
end

function CommandPalette:hide()
	self:moveToY(Y_INACTIVE, 0.18, "InCubic")
	self:scaleTo(SCALE_INACTIVE, SCALE_INACTIVE, 0.18, "InCubic")
	self:transformTo("opacity", 0, 0.15, "InCubic", function()
		self:setVisible(false)
	end)
end

---@return boolean
function CommandPalette:isNeedleMode()
	return self.state.active_command ~= nil and self.state.active_command.id == "global.needle"
end

function CommandPalette:queryChanged()
	self.state:setQuery(self.query)
	if self:isNeedleMode() and self.needle_model then self.needle_model:setQuery(self.query) end
	self:updateText()
end

---@return boolean
function CommandPalette:goBack()
	if self:isNeedleMode() and self.needle_model then self.needle_model:cancel() end
	if not self.state:goBack() then return false end
	self.query = self.state.query
	self.prompt = self.state:isArgumentMode() and self.state:getPromptText() or nil
	self.selected_index = 1
	self:updateText()
	return true
end

---@return table? candidate
function CommandPalette:getSelectedCandidate()
	local candidates = self.candidates
	if #candidates == 0 then
		return nil
	end
	self.selected_index = math.max(1, math.min(self.selected_index, #candidates))
	return candidates[self.selected_index]
end

---@param offset integer
function CommandPalette:moveSelection(offset)
	local candidates = self.candidates
	if #candidates == 0 then
		self.selected_index = 1
		return
	end
	self.selected_index = ((self.selected_index - 1 + offset) % #candidates) + 1
	self:updateText()
end

function CommandPalette:onKeyDown(e)
	if e.key == "backspace" then
		if #self.query > 0 then
			local byte_offset = utf8.offset(self.query, -1)
			if byte_offset then
				self.query = self.query:sub(1, byte_offset - 1)
			end
			self.selected_index = 1
			self:queryChanged()
		end
	elseif e.key == "down" then
		self:moveSelection(1)
	elseif e.key == "up" then
		self:moveSelection(-1)
	elseif e.key == "return" or e.key == "kpenter" then
		if self:isNeedleMode() then
			if not self.needle_model then return true end
			local executed, err = self.needle_model:execute()
			if executed then
				self.on_close()
				self:hide()
			elseif err then
				print(err)
			end
			return true
		end
		local success, err, executed = self.state:confirmSelection(self:getSelectedCandidate())

		if not success then
			print(err)
			return true
		end

		if executed then
			self.on_close()
			self:hide()
			return true
		end

		if self.state:isArgumentMode() then
			self.query = ""
			self.selected_index = 1
			self.prompt	= self.state:getPromptText()
			if self:isNeedleMode() and self.needle_model and self.needle_tools then
				self.needle_model:activate(self.needle_tools:snapshot())
			end
			self:updateText()
		end
	elseif e.key == "escape" then
		self.on_close()
		self:hide()
	end
	return true
end

function CommandPalette:onTextInput(e)
	self.query = self.query .. (e.text or e.key or "")
	self.selected_index = 1
	self:queryChanged()
	return true
end

function CommandPalette:updateText()
	local c = self.state:getCandidates()
	self.candidates = c
	if #c == 0 then
		self.selected_index = 1
	else
		self.selected_index = math.max(1, math.min(self.selected_index, #c))
	end

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
	local lg = love.graphics
	lg.setScissor(0, 0, self.world_transform:transformPoint(self.width, self.height))
	Painter.setColorRgb(0.08, 0.08, 0.1)
	lg.rectangle("fill", 0, 0, self.width, self.height)
	Painter.setColorRgb(0.2, 0.2, 0.25)
	lg.rectangle("fill", 0, 0, self.width, CELL_HEIGHT)
	if self.candidates[self.selected_index] then
		Painter.setColorRgb(0.3, 0.3, 0.4)
		lg.rectangle("fill", 0, self.selected_index * CELL_HEIGHT, self.width, CELL_HEIGHT)
	end
	Painter.setColorRgb(0.9, 0.9, 0.95)
	lg.draw(self.names, 5, 5)

	if self:isNeedleMode() then
		local model = self.needle_model
		if not model then
			return
		end
		local preview = model.formatted_call or model.streamed_text
		if preview == "" then
			if model.state == "debouncing" then preview = "Waiting for input pause…"
			elseif model.state == "generating" then preview = "Generating…"
			elseif model.state == "unavailable" or model.state == "error" then preview = model.error or "Needle unavailable"
			else preview = "Type a request; Enter runs the displayed call." end
		end
		love.graphics.setFont(Resources.getFont("regular", 20))
		local failed = model.state == "error" or model.state == "unavailable"
		Painter.setColorTable(failed and {0.9, 0.3, 0.3, 1} or {0.7, 0.7, 0.75, 1})
		love.graphics.printf(preview, 12, CELL_HEIGHT * 2, self.width - 24, "left")
		local telemetry = model:formatTelemetry()
		if telemetry then
			love.graphics.setFont(Resources.getFont("regular", 14))
			Painter.setColorRgb(0.7, 0.7, 0.75)
			love.graphics.printf(telemetry, 12, CELL_HEIGHT * 2 + 30, self.width - 24, "left")
		end
	end
end

return CommandPalette
