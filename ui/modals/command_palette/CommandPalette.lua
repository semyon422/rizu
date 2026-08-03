local Colors = require("ui.Colors")
local CommandList = require("ui.modals.command_palette.CommandList")
local ModalView = require("ui.ModalView")
local NineSliceUsage = require("gui.NineSliceUsage")
local Painter = require("gui.Painter")
local Resources = require("ui.Resources")
local Textbox = require("ui.views.Textbox")
local UiActions = require("ui.UiActions")

---@class ui.modals.command_palette.CommandPalette : ui.ModalView
---@operator call: ui.modals.command_palette.CommandPalette
---@field prompt string?
---@field needle_model rizu.ai.NeedleModel?
---@field needle_tools rizu.ai.NeedleToolRegistry?
---@field textbox ui.views.Textbox
---@field list ui.modals.command_palette.CommandList
---@field background gui.NineSliceUsage
local CommandPalette = ModalView + {}

local MODAL_WIDTH = 720
local MODAL_HEIGHT = 500
local PADDING = 20
local TEXTBOX_HEIGHT = 40
local LIST_TOP = 72
local SCALE_INACTIVE = 0.95
local Y_INACTIVE = -20

---@param state rizu.command.PaletteState
---@param on_close function
---@param needle_model rizu.ai.NeedleModel
---@param needle_tools rizu.ai.NeedleToolRegistry
function CommandPalette:new(state, on_close, needle_model, needle_tools)
	ModalView.new(self)
	self.state = state
	self.on_close = on_close
	self.needle_model = needle_model
	self.needle_tools = needle_tools
	self:setSize(MODAL_WIDTH, MODAL_HEIGHT)
	self:setAlignment(0.5, 0.5)
	self:setPivot(0.5, 0.5)
	self:setScale(SCALE_INACTIVE, SCALE_INACTIVE)
	self:setOpacity(0)
	self:setOffset(0, Y_INACTIVE)
	self:setVisible(false)
	self:setClip(true)
	self.query = ""
	self.prompt = nil
	self.selected_index = 1
	self.candidates = {}

	local sprites = Resources.sprites
	self.background = NineSliceUsage({
		sprites.nineslice_modal_lt,
		sprites.nineslice_modal_t,
		sprites.nineslice_modal_rt,
		sprites.nineslice_modal_l,
		sprites.nineslice_modal_c,
		sprites.nineslice_modal_r,
		sprites.nineslice_modal_lb,
		sprites.nineslice_modal_b,
		sprites.nineslice_modal_rb,
	})

	self.textbox = Textbox({
		placeholder = "Search commands...",
		icon = sprites.icon_search,
		blur_on_accept = false,
		blur_on_cancel = false,
		background = true,
		handle_clear_field = false,
		on_change = function(text)
			self.query = text
			self.selected_index = 1
			self:queryChanged()
		end,
	})
	self.textbox:anchorFixed(PADDING, PADDING, MODAL_WIDTH - PADDING * 2, TEXTBOX_HEIGHT)

	self.list = CommandList(function(index)
		self.selected_index = index
		self.list:setSelectedIndex(index)
	end, function(index)
		self.selected_index = index
		self:confirmSelection()
	end)
	self.list:anchorFixed(PADDING, LIST_TOP, MODAL_WIDTH - PADDING * 2, MODAL_HEIGHT - LIST_TOP - PADDING)

	self:add(self.textbox)
	self:add(self.list)
	self.state:setQuery(self.query)
	self:updateCandidates()
end

function CommandPalette:focusTextbox()
	local inputs = self.screen and self.screen.inputs
	if inputs and inputs.keyboard_focus ~= self.textbox then
		inputs:setKeyboardFocus(self.textbox, {control = false, shift = false, alt = false, super = false})
	end
end

function CommandPalette:reset()
	if self.needle_model then self.needle_model:cancel() end
	self.query = ""
	self.prompt = nil
	self.selected_index = 1
	self.state:reset()
	self.textbox.placeholder = self.state:getPromptText()
	self.textbox:setText("")
	self:updateCandidates()
end

function CommandPalette:show()
	self:setVisible(true)
	self:fadeIn(0.2, "OutCubic")
	self:moveToY(0, 0.25, "OutQuint")
	self:scaleTo(1, 1, 0.25, "OutQuint")
	self:focusTextbox()
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
	self:updateCandidates()
end

---@return table? candidate
function CommandPalette:getSelectedCandidate()
	if #self.candidates == 0 then
		return nil
	end
	self.selected_index = math.max(1, math.min(self.selected_index, #self.candidates))
	return self.candidates[self.selected_index]
end

---@param offset integer
function CommandPalette:moveSelection(offset)
	if #self.candidates == 0 then
		self.selected_index = 1
		return
	end
	self.selected_index = ((self.selected_index - 1 + offset) % #self.candidates) + 1
	self.list:setSelectedIndex(self.selected_index)
end

function CommandPalette:close()
	self.on_close()
	self:hide()
end

function CommandPalette:confirmSelection()
	if self:isNeedleMode() then
		if not self.needle_model then return end
		local executed, err = self.needle_model:execute()
		if executed then
			self:close()
		elseif err then
			print(err)
		end
		return
	end

	local success, err, executed = self.state:confirmSelection(self:getSelectedCandidate())
	if not success then
		print(err)
		return
	end
	if executed then
		self:close()
		return
	end
	if self.state:isArgumentMode() then
		self.query = ""
		self.selected_index = 1
		self.prompt = self.state:getPromptText()
		self.textbox.placeholder = self.prompt
		self.textbox:setText("")
		if self:isNeedleMode() and self.needle_model and self.needle_tools then
			self.needle_model:activate(self.needle_tools:snapshot())
		end
		self:updateCandidates()
	end
end

function CommandPalette:onHandleInputs(inputs)
	if inputs:consumeActionJustPressed(UiActions.down) then
		self:moveSelection(1)
	elseif inputs:consumeActionJustPressed(UiActions.up) then
		self:moveSelection(-1)
	elseif inputs:consumeActionJustPressed(UiActions.clear_field) then
		self:reset()
		self:focusTextbox()
	elseif inputs:consumeActionJustPressed(UiActions.accept) then
		self:confirmSelection()
	elseif inputs:consumeActionJustPressed(UiActions.cancel) then
		self:close()
	end
end

function CommandPalette:updateCandidates()
	self.candidates = self.state:getCandidates()
	if #self.candidates == 0 then
		self.selected_index = 1
	else
		self.selected_index = math.max(1, math.min(self.selected_index, #self.candidates))
	end
	self.list:setCandidates(self.candidates)
	self.list:setSelectedIndex(self.selected_index)
end

function CommandPalette:draw()
	Painter.setColorTable(Colors.panel)
	self.background:draw(self.width, self.height)

	if not self:isNeedleMode() then
		return
	end
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
	love.graphics.setFont(Resources.getFont("regular", 18))
	local failed = model.state == "error" or model.state == "unavailable"
	Painter.setColorTable(failed and {0.9, 0.3, 0.3, 1} or Colors.text_muted)
	love.graphics.printf(preview, PADDING, LIST_TOP + 12, self.width - PADDING * 2, "left")
	local telemetry = model:formatTelemetry()
	if telemetry then
		love.graphics.setFont(Resources.getFont("regular", 14))
		Painter.setColorTable(Colors.text_muted)
		love.graphics.printf(telemetry, PADDING, LIST_TOP + 46, self.width - PADDING * 2, "left")
	end
end

return CommandPalette
