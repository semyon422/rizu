local Layer = require("gui.Layer")
local View = require("gui.View")

---@class gui.Screen : gui.Layer
---@operator call: gui.Screen
---@field root gui.Composition.Node?
---@field views gui.View[]
---@field hidden_views gui.View[]
local Screen = Layer + {}

function Screen:new()
	self.ui_scale = 1
	self.views = {}
	self.hidden_views = {}
	self.input_handler = View()
	self.input_handler.handles_keyboard_input = true
	self.input_handler.onKeyDown = function(_, e)
		return self:handleKeyDown(e.key)
	end
end

function Screen:load()
	assert(self.views, "Call Composition.new(self)")

	local scale = self.ui_scale

	if self.root then
		local w, h = love.graphics.getDimensions()
		self.root:measure()
		self.root:grow(w / scale, h / scale)
		self.root:arrange()
		self.root:insertViewsInto(self.views)
	end

	for _, v in ipairs(self.views) do
		v.ui_scale = scale
		v:load()
		v:applyLayout()
	end

	for _, v in ipairs(self.hidden_views) do
		v.ui_scale = scale
		v:load()
		v:applyLayout()
	end
end

function Screen:unload()
	for _, v in ipairs(self.views) do
		v:unload()
	end

	for _, v in ipairs(self.hidden_views) do
		v:unload()
	end

	self.views = {}
	self.hidden_views = {}
end

function Screen:enter() end

function Screen:exit() end

function Screen:acceptInputs(inputs)
	self.input_handler:acceptInputs(inputs)

	for i = #self.views, 1, -1 do
		local view = self.views[i]
		view:acceptInputs(inputs)
	end
end

function Screen:update(dt)
	for _, v in ipairs(self.views) do
		v:update(dt)
	end
end

function Screen:draw()
	for _, v in ipairs(self.views) do
		love.graphics.push("all")
		love.graphics.applyTransform(v.transform)
		v:draw()
		love.graphics.pop()
	end
end

---@param key string
function Screen:handleKeyDown(key) end

---@param view gui.View
function Screen:hideView(view)
	for i, v in ipairs(self.views) do
		if v == view then
			table.remove(self.views, i)
			break
		end
	end
	for _, hv in ipairs(self.hidden_views) do
		if hv == view then
			return
		end
	end
	table.insert(self.hidden_views, view)
end

---@param view gui.View
function Screen:showView(view)
	for i, v in ipairs(self.hidden_views) do
		if v == view then
			table.remove(self.hidden_views, i)
			for _, ev in ipairs(self.views) do
				if ev == view then
					return
				end
			end
			table.insert(self.views, view)
			return
		end
	end
end

return Screen
