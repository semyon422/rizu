local class = require("class")
local View = require("yi.views.View")
local ViewState = View.State
local LayoutEngine = require("ui.layout.LayoutEngine")
local LayoutEnums = require("ui.layout.Enums")
local CommandBuffer = require("yi.renderer.CommandBuffer")
local Renderer = require("yi.renderer")
local table_util = require("table_util")

---@return number
---@return number
local function getDimensions()
	if love and love.graphics and love.graphics.getDimensions then
		return love.graphics.getDimensions()
	end
	return 1280, 720
end

---@class yi.Engine
---@overload fun(inputs: ui.Inputs, ctx: yi.Context, timer: time.ITimer): yi.Engine
---@field ctx yi.Context
---@field root yi.View
---@field layout_engine ui.LayoutEngine
---@field layout_update_requesters yi.View[]
---@field transform_update_requesters yi.View[]
---@field removal_deferred yi.View[]
---@field target_height number?
---@field check_dimensions_during_update boolean
local Engine = class()

---@param inputs ui.Inputs
---@param ctx yi.Context
---@param timer time.ITimer
function Engine:new(inputs, ctx, timer)
	self.inputs = inputs
	self.ctx = ctx
	self.timer = timer
	self.layout_engine = LayoutEngine()
	self.root = View()
	self.root.id = "root"

	self.rebuild_command_buffer = true
	self.layout_update_requesters = {}
	self.transform_update_requesters = {}
	self.removal_deferred = {}
	self.check_dimensions_during_update = false
	self.last_window_width = nil
	self.last_window_height = nil
end

function Engine:load()
	self.root:mount(self.ctx)
	self:updateRootDimensions()
end

---@private
---@param view yi.View
function Engine:processDisabledView(view)
	if view.just_changed_enabled then
		view.just_changed_enabled = false
		self.rebuild_command_buffer = true
	end

	local state = view.state

	if state == ViewState.Active then
		-- do nothing
	elseif state == ViewState.Loaded then
		view.state = ViewState.Active
		view:loadComplete()
		self.rebuild_command_buffer = true
	elseif state == ViewState.Killed then
		table.insert(self.removal_deferred, view)
	elseif state == ViewState.Destoryed then
		error("DO NOT CALL View:destroy() manually!!!")
	end
end

---@private
---@param view yi.View
---@param dt number
function Engine:updateView(view, dt)
	if view.just_changed_enabled then
		view.just_changed_enabled = false
		self.rebuild_command_buffer = true
	end

	local state = view.state

	if state == ViewState.Active then
		view:update(dt)

		if not view.layout_box:isValid() then
			table.insert(self.layout_update_requesters, view)
		end

		if view.transform.dirty then
			table.insert(self.transform_update_requesters, view)
		end

		local children = view.children
		for i = #children, 1, -1 do
			self:updateView(children[i], dt)
		end

		self.inputs:processNode(view)

		local disabled = view.disabled_children
		for i = #disabled, 1, -1 do
			self:processDisabledView(disabled[i])
		end
	elseif state == ViewState.Loaded then
		view.state = ViewState.Active
		view:loadComplete()
		self.rebuild_command_buffer = true
		self:updateView(view, dt)
	elseif state == ViewState.Killed then
		table.insert(self.removal_deferred, view)
	elseif state == ViewState.Destoryed then
		error("DO NOT CALL View:destroy() manually!!!")
	end
end

---@private
---@param view yi.View
---@param kill boolean
function Engine:remove(view, kill)
	local parent = view.parent
	if parent then
		local idx = table_util.indexof(parent.children, view)
		if idx then
			table.remove(parent.children, idx)
			self.rebuild_command_buffer = true
			parent.layout_box:markDirty(LayoutEnums.Axis.Both)
			table.insert(self.layout_update_requesters, parent)
		else
			local disabled_idx = table_util.indexof(parent.disabled_children, view)
			if disabled_idx then
				table.remove(parent.disabled_children, disabled_idx)
			end
		end
	end

	if kill then
		view:destroy()
	end
end

---@param dt number
---@param mouse_x number
---@param mouse_y number
function Engine:update(dt, mouse_x, mouse_y)
	self.inputs:beginFrame(mouse_x, mouse_y)

	if self.check_dimensions_during_update then
		self:checkRootDimensions()
	end

	table_util.clear(self.layout_update_requesters)
	table_util.clear(self.transform_update_requesters)
	table_util.clear(self.removal_deferred)

	self:updateView(self.root, dt)

	for i = 1, #self.removal_deferred do
		self:remove(self.removal_deferred[i], true)
	end

	local t1 = self.timer:getTime()

	local updated_roots = self.layout_engine:updateLayout(self.layout_update_requesters)

	local t2 = self.timer:getTime()

	if updated_roots then
		for node, _ in pairs(updated_roots) do
			---@cast node yi.View
			node:updateTransforms()
		end
	end

	for i = 1, #self.transform_update_requesters do
		local view = self.transform_update_requesters[i]
		view:updateTransforms()
	end

	if self.rebuild_command_buffer then
		self.rebuild_command_buffer = false
		self.command_buffer = CommandBuffer(self.root)
	end

	local lt = (t2 - t1) * 1000
	if lt > 1 then
		print(("Layout recalc takes too long: %0.02f MS Time: %0.01f"):format(lt, self.timer:getTime()))
	end
end

function Engine:draw()
	Renderer(self.command_buffer)
end

function Engine:updateRootDimensions()
	local ww, wh = getDimensions()
	self.last_window_width = ww
	self.last_window_height = wh
	local w, h = 1, 1
	local target_h = self.target_height

	if target_h then
		local s = wh / target_h
		w, h = ww * (1 / s), target_h
		self.root.transform:setScale(s, s)
	else
		w, h = ww, wh
		self.root.transform:setScale(1, 1)
	end

	self.root:setWidth(w)
	self.root:setHeight(h)
end

function Engine:checkRootDimensions()
	local ww, wh = getDimensions()
	if ww ~= self.last_window_width or wh ~= self.last_window_height then
		self:updateRootDimensions()
	end
end

---@type ui.ModifierKeys
local modifiers = {
	control = false,
	shift = false,
	super = false,
	alt = false
}

function Engine:receive(event)
	if event.name ~= "framestarted" then
		modifiers.control = love.keyboard.isDown("lctrl", "rctrl")
		modifiers.shift = love.keyboard.isDown("lshift", "rshift")
		modifiers.alt = love.keyboard.isDown("lalt", "ralt")
		self.inputs:receive(event, modifiers)
	end
end

return Engine
