local AvailableModifierList = require("ui.modals.chart_mutators.AvailableModifierList")
local ModalView = require("ui.ModalView")
local SelectedModifierList = require("ui.modals.chart_mutators.SelectedModifierList")
local FormNavigation = require("ui.views.form.FormNavigation")
local UiActions = require("ui.UiActions")

---@class ui.modals.chart_mutators.ChartMutators : ui.ModalView
---@operator call: ui.modals.chart_mutators.ChartMutators
---@field game sphere.GameController
---@field available_list ui.modals.chart_mutators.AvailableModifierList
---@field selected_list ui.modals.chart_mutators.SelectedModifierList
---@field active_list integer
---@field navigation ui.views.form.FormNavigation
---@field private navigation_mouse_x number?
---@field private navigation_mouse_y number?
---@field private on_change fun()?
local ChartMutators = ModalView + {}

local MODAL_WIDTH = 920
local MODAL_HEIGHT = 620
local LIST_GAP = 20
local LIST_WIDTH = (MODAL_WIDTH - LIST_GAP) / 2

---@param game sphere.GameController
---@param on_change fun()?
function ChartMutators:new(game, on_change)
	ModalView.new(self)
	self.game = game
	self.on_change = on_change
	self.active_list = 1
	self.navigation = FormNavigation.Mouse
	self.navigation_mouse_x = nil
	self.navigation_mouse_y = nil

	self:setSize(MODAL_WIDTH, MODAL_HEIGHT)
	self:setAlignment(0.5, 0.5)
	self:setPivot(0.5, 0.5)
	self:setScale(0.9, 0.9)
	self:setOpacity(0)
	self:setVisible(false)
	self.handles_mouse_input = true
	self.handles_keyboard_input = true

	local model = game.modifierSelectModel
	self.available_list = self:add(AvailableModifierList(model, function()
		self:setActiveList(1)
		self:changed()
	end))
	self.available_list:anchorFixed(0, 0, LIST_WIDTH, MODAL_HEIGHT)

	self.selected_list = self:add(SelectedModifierList(model, function()
		self:setActiveList(2)
		self:changed()
	end))
	self.selected_list:anchorFixed(LIST_WIDTH + LIST_GAP, 0, LIST_WIDTH, MODAL_HEIGHT)
	self:setActiveList(1)
end

---@param index integer
function ChartMutators:setActiveList(index)
	self.active_list = math.max(1, math.min(index, 2))
	self.available_list:setActive(self.active_list == 1)
	self.selected_list:setActive(self.active_list == 2)
end

---@param navigation ui.views.form.FormNavigation
function ChartMutators:setNavigation(navigation)
	self.navigation = navigation
	local inputs = self.screen and self.screen.inputs
	if inputs then
		self.navigation_mouse_x = inputs.mouse_x
		self.navigation_mouse_y = inputs.mouse_y
	end
end

---@param mouse_x number
---@param mouse_y number
---@return boolean selected
function ChartMutators:selectHoveredItem(mouse_x, mouse_y)
	local index = self.available_list:getIndexAt(mouse_x, mouse_y)
	if index then
		self.game.modifierSelectModel.availableModifierIndex = index
		self:setActiveList(1)
		return true
	end

	index = self.selected_list:getIndexAt(mouse_x, mouse_y)
	if index then
		self.game.modifierSelectModel.modifierIndex = index
		self:setActiveList(2)
		return true
	end
	return false
end

---@param e gui.MouseDownEvent
function ChartMutators:onMouseDown(e)
	self:setNavigation(FormNavigation.Mouse)
end

function ChartMutators:changed()
	if self.on_change then
		self.on_change()
	end
end

---@param inputs gui.Inputs
function ChartMutators:onHandleInputs(inputs)
	if inputs:isActionJustPressed(UiActions.left)
		or inputs:isActionJustPressed(UiActions.right)
		or inputs:isActionJustPressed(UiActions.down)
		or inputs:isActionJustPressed(UiActions.up)
		or inputs:isActionJustPressed(UiActions.accept)
	then
		self:setNavigation(FormNavigation.Keyboard)
	end

	if inputs:consumeActionJustPressed(UiActions.left) then
		if self.active_list == 2 then
			self.selected_list:changeValue(-1)
		else
			self:setActiveList(1)
		end
	elseif inputs:consumeActionJustPressed(UiActions.right) then
		if self.active_list == 2 then
			self.selected_list:changeValue(1)
		else
			self:setActiveList(2)
		end
	elseif inputs:consumeActionJustPressed(UiActions.down) then
		if self.active_list == 1 then
			self.available_list:move(1)
		else
			self.selected_list:move(1)
		end
	elseif inputs:consumeActionJustPressed(UiActions.up) then
		if self.active_list == 1 then
			self.available_list:move(-1)
		else
			self.selected_list:move(-1)
		end
	elseif inputs:consumeActionJustPressed(UiActions.accept) then
		if self.active_list == 1 then
			self.available_list:activate()
		else
			self.selected_list:activate()
		end
	end
end

---@param dt number
function ChartMutators:update(dt)
	local inputs = self.screen and self.screen.inputs
	if not inputs then
		return
	end

	local mouse_x, mouse_y = inputs.mouse_x, inputs.mouse_y
	if self.navigation_mouse_x ~= nil
		and (mouse_x ~= self.navigation_mouse_x or mouse_y ~= self.navigation_mouse_y)
	then
		self:setNavigation(FormNavigation.Mouse)
	end
	self.navigation_mouse_x = mouse_x
	self.navigation_mouse_y = mouse_y

	if self.navigation == FormNavigation.Mouse then
		self:selectHoveredItem(mouse_x, mouse_y)
	end
end

function ChartMutators:show()
	local model = self.game.modifierSelectModel
	model:updateAdded()
	model.modifierIndex = math.max(1, math.min(model.modifierIndex, #model.replayBase.modifiers + 1))
	self:setNavigation(FormNavigation.Mouse)
	self:setVisible(true)
	self:fadeIn(0.3, "OutCubic")
end

function ChartMutators:hide()
	self:transformTo("opacity", 0, 0.2, "InCubic", function()
		self:setVisible(false)
	end)
end

return ChartMutators
