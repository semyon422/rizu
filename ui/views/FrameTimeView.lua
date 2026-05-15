local class = require("class")
local spherefonts = require("sphere.assets.fonts")
local loop = require("rizu.loop.Loop")
local just = require("just")
local imgui = require("imgui")
local reqprof = require("reqprof")

---@class sphere.FrameTimeView
---@operator call: sphere.FrameTimeView
local FrameTimeView = class()

FrameTimeView.visible = false
FrameTimeView.profiler = false

local colors = {
	gray0 = {0.3, 0.3, 0.3, 0.3},
	-- gray0 = {0.5, 0.5, 0.5, 0.5},
	white = {1, 1, 1, 1},
	blue = {0.25, 0.25, 1, 1},
	gray = {0.25, 0.25, 0.25, 1},
	orange = {1, 0.5, 0, 1},
	yellow = {1, 1, 0.25, 1},
	cyan = {0, 1, 1, 1},
	red = {1, 0.25, 0.25, 1},
	green = {0.25, 1, 0.25, 1},
	purple = {1, 0.25, 1, 1}
}

function FrameTimeView:load()
	self.smallFont = spherefonts.get("Noto Sans Mono", 14)
	self.font = spherefonts.get("Noto Sans Mono", 20)
	self.largeFont = spherefonts.get("Noto Sans Mono", 40)

	self.graphs = {
		{
			id = "phases",
			label = "Frame Phases",
			enabled = true,
			color = colors.white,
			scale = 1,
			draw = function(y, h, scale)
				love.graphics.setColor(colors.white)
				love.graphics.line(0.5, y, 0.5, y - loop.timings.dt * 1000 * scale)

				love.graphics.setColor(colors.blue)
				love.graphics.line(0.5, y, 0.5, y - loop.timings.event * 1000 * scale)

				y = y - loop.timings.event * 1000 * scale
				love.graphics.setColor(colors.gray, 1)
				love.graphics.line(0.5, y, 0.5, y - loop.timings.update * 1000 * scale)

				y = y - loop.timings.update * 1000 * scale
				love.graphics.setColor(colors.orange)
				love.graphics.line(0.5, y, 0.5, y - loop.timings.draw * 1000 * scale)

				y = y - loop.timings.draw * 1000 * scale
				love.graphics.setColor(colors.yellow)
				love.graphics.line(0.5, y, 0.5, y - loop.timings.present * 1000 * scale)

				y = y - loop.timings.present * 1000 * scale
				love.graphics.setColor(colors.purple)
				love.graphics.line(0.5, y, 0.5, y - loop.timings.gc * 1000 * scale)

				y = y - loop.timings.gc * 1000 * scale
				love.graphics.setColor(colors.gray0)
				love.graphics.line(0.5, y, 0.5, y - loop.timings.sleep * 1000 * scale)

				y = y - loop.timings.sleep * 1000 * scale
				love.graphics.setColor(colors.red)
				love.graphics.line(0.5, y, 0.5, y - loop.timings.busy * 1000 * scale)
			end,
			info = function(val_y, scale)
				local ms = -val_y / scale
				return ("%3.2fms (%dfps)"):format(ms, 1000 / ms)
			end
		},
		{
			id = "jitter",
			label = "Jitter",
			enabled = true,
			color = colors.purple,
			scale = 1,
			draw = function(y, h, scale)
				love.graphics.setColor(colors.purple)
				love.graphics.line(0.5, y, 0.5, y - loop.jitter * 1000 * scale * 20)
			end,
			info = function(val_y, scale)
				local ms = -val_y / scale / 20
				return ("Jitter: %3.3fms"):format(ms)
			end
		},
		{
			id = "memory",
			label = "Lua Memory",
			enabled = true,
			color = colors.green,
			scale = 1,
			draw = function(y, h, scale)
				love.graphics.setColor(colors.green)
				love.graphics.line(0.5, y, 0.5, y - (loop.mem_count / 1024) * scale * 0.5)
			end,
			info = function(val_y, scale)
				local mb = -val_y / scale / 0.5
				return ("Memory: %d MB"):format(mb)
			end
		}
	}
end

function FrameTimeView:checkCanvas()
	local w, h = love.graphics.getDimensions()
	if self.width ~= w or self.height ~= h then
		self.width = w
		self.height = h
		self.canvas1 = love.graphics.newCanvas()
		self.canvas2 = love.graphics.newCanvas()
	end
end

function FrameTimeView:drawSmall()
	local w, h = love.graphics.getDimensions()
	love.graphics.origin()
	love.graphics.setColor(colors.white)
	local dt = love.timer.getDelta()
	local font = self.smallFont
	love.graphics.setFont(font)
	local text = ("%4dfps\n%3.1fms"):format(math.floor(1 / dt + 0.5), dt * 1000)
	local twidth = font:getWidth(text)
	local theight = font:getHeight() * 2
	love.graphics.translate(w - twidth, h - theight)
	love.graphics.setColor(0, 0, 0, 0.5)
	love.graphics.rectangle("fill", 0, 0, twidth, theight)
	love.graphics.setColor(1, 1, 1, 1)
	love.graphics.printf(text, 0, 0, twidth, "right")
	if just.button(self, just.is_over(twidth, theight)) then
		self.visible = not self.visible
	end
end

function FrameTimeView:draw()
	local settings = self.game.configModel.configs.settings
	if not settings.miscellaneous.showFPS then return end
	if not self.visible then return self:drawSmall() end

	self:checkCanvas()
	love.graphics.origin()

	local activeGraphs = {}
	for _, g in ipairs(self.graphs) do
		if g.enabled then table.insert(activeGraphs, g) end
	end

	if #activeGraphs > 0 then
		local graphHeight = self.height / #activeGraphs
		love.graphics.setCanvas(self.canvas1)
		love.graphics.setLineStyle("rough")
		love.graphics.setLineWidth(1)

		for i, g in ipairs(activeGraphs) do
			local base_y = self.height - (i - 1) * graphHeight
			g.draw(base_y, graphHeight, g.scale)
		end
		love.graphics.setCanvas()

		love.graphics.setColor(1, 1, 1, 1)
		love.graphics.setCanvas(self.canvas2)
		love.graphics.clear()
		love.graphics.draw(self.canvas1, 1, 0)
		love.graphics.setCanvas()

		love.graphics.draw(self.canvas2, 1, 0)

		-- Labels & Scaling
		love.graphics.setFont(self.smallFont)
		for i, g in ipairs(activeGraphs) do
			local base_y = self.height - (i - 1) * graphHeight

			-- Check for mouse wheel over this specific graph area
			local wy = just.wheel_over(g.id, just.is_over(self.width, graphHeight, 0, base_y - graphHeight))
			if type(wy) == "number" then
				if wy > 0 then g.scale = g.scale * 2
				else g.scale = g.scale / 2 end
			end

			love.graphics.setColor(g.color)
			love.graphics.print(g.label, 10, base_y - graphHeight + 10)
		end
	end

	self:drawMouse(activeGraphs)
	self:drawFPS()

	self.canvas1, self.canvas2 = self.canvas2, self.canvas1
	self:drawSmall()
end

function FrameTimeView:drawMouse(activeGraphs)
	if #activeGraphs == 0 then return end
	local mx, my = love.mouse.getPosition()
	local graphHeight = self.height / #activeGraphs
	local graphIdx = math.floor((self.height - my) / graphHeight) + 1
	local g = activeGraphs[graphIdx]

	if g then
		local base_y = self.height - (graphIdx - 1) * graphHeight
		local val_y = my - base_y
		local info = g.info(val_y, g.scale)

		love.graphics.setColor(0, 0, 0, 0.75)
		love.graphics.rectangle("fill", mx - 250, my, 250, 30)
		love.graphics.setColor(0.25, 1, 0.75, 1)
		love.graphics.setFont(self.font)
		love.graphics.printf(info, mx - 250, my, self.width, "left")
	end
end

local colorText = {
	colors.white, "dt ",
	colors.blue, "event ",
	colors.gray, "update ",
	colors.orange, "draw ",
	colors.yellow, "present ",
	colors.purple, "gc ",
	colors.cyan, "sleep ",
	colors.red, "busy "
}

function FrameTimeView:drawFPS()
	love.graphics.setColor(0, 0, 0, 0.75)
	love.graphics.rectangle("fill", 0, 0, self.width, 60)

	love.graphics.setColor(1, 1, 1, 1)
	love.graphics.setFont(self.font)
	love.graphics.printf(colorText, 0, 0, self.width, "right")

	love.graphics.origin()
	love.graphics.translate(0, 100)
	love.graphics.setColor(0, 0, 0, 0.75)
	love.graphics.rectangle("fill", 0, 0, 200, 250)
	love.graphics.setColor(1, 1, 1, 1)
	love.graphics.setFont(self.smallFont)
	just.push()
	just.text("drawcalls: " .. loop.stats.drawcalls)
	just.text("canvasswitches: " .. loop.stats.canvasswitches)
	just.text("texturememory: " .. math.floor(loop.stats.texturememory / 1e6) .. "MB")
	just.text("textures: " .. loop.stats.textures)
	just.text("fonts: " .. loop.stats.fonts)
	just.emptyline(4)
	just.text(("avg: %3.2fms"):format(loop.ema_dt * 1000))
	just.text(("jitter: %3.3fms"):format(loop.ema_jitter * 1000))
	just.text(("gc: %3.3fms"):format(loop.timings.gc * 1000))
	just.text(("mem alloc: %d KB"):format(loop.mem_delta))
	just.emptyline(4)

	for _, g in ipairs(self.graphs) do
		g.enabled = imgui.checkbox(g.id, g.enabled, g.label)
	end

	just.pop()

	love.graphics.origin()
	love.graphics.translate((self.width - 200) / 2, 0)

	local action = self.profiler and "disable" or "enable"
	if imgui.TextOnlyButton("switch profiler", action .. " profiler", 200, 60) then
		if self.profiler then reqprof.disable() else reqprof.enable() end
		self.profiler = not self.profiler
	end
	just.sameline()
	if imgui.TextOnlyButton("reqprof.print()", "reqprof.print()", 200, 60) then
		reqprof.print()
	end
end

---@param event table
function FrameTimeView:receive(event)
	if not self.visible then return end
	if event.name == "keypressed" then
		self:keypressed(event[1])
	end
end

function FrameTimeView:keypressed(key)
	if key == "up" then
		for _, g in ipairs(self.graphs) do g.scale = g.scale * 2 end
	elseif key == "down" then
		for _, g in ipairs(self.graphs) do g.scale = g.scale / 2 end
	end
end

return FrameTimeView
