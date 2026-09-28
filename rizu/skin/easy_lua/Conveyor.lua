local class = require("class")
local Column = require("rizu.skin.easy_lua.Column")

---@class rizu.skin.easy_lua.Conveyor.Config
---@field columns (rizu.skin.easy_lua.Column|rizu.skin.easy_lua.Column.Config)[] Ordered columns.
---@field pixels_per_second number Pixels traveled per visual-time second. Defaults to 480.
---@field reverse boolean? If true, notes scroll upward toward the hit position.

---@class rizu.skin.easy_lua.Conveyor
---@operator call: rizu.skin.easy_lua.Conveyor
---@field columns rizu.skin.easy_lua.Column[]
---@field pixels_per_second number
---@field reverse boolean
local Conveyor = class()

Conveyor.WIDTH = 640
Conveyor.HEIGHT = 480

---Returns the native canvas width for a viewport. The native canvas always
---remains 480 units high, so its width follows the viewport aspect ratio.
---@param viewport_width number
---@param viewport_height number
---@return number
function Conveyor.getCanvasWidth(viewport_width, viewport_height)
	assert(type(viewport_width) == "number" and viewport_width > 0 and viewport_width < math.huge,
		"viewport width must be positive and finite")
	assert(type(viewport_height) == "number" and viewport_height > 0 and viewport_height < math.huge,
		"viewport height must be positive and finite")
	return viewport_width / viewport_height * Conveyor.HEIGHT
end

---@param config rizu.skin.easy_lua.Conveyor.Config
function Conveyor:new(config)
	assert(type(config) == "table", "conveyor config must be a table")
	assert(type(config.columns) == "table", "conveyor columns must be an array")
	local pixels_per_second = config.pixels_per_second or Conveyor.HEIGHT
	assert(type(pixels_per_second) == "number" and pixels_per_second > 0
		and pixels_per_second < math.huge, "pixels_per_second must be positive and finite")
	self.columns = {} ---@type rizu.skin.easy_lua.Column[]
	self.pixels_per_second = pixels_per_second
	self.reverse = not not config.reverse

	local inputs = {} ---@type {[chart.Column]: boolean}
	for index, column in ipairs(config.columns) do
		local configured_column ---@type rizu.skin.easy_lua.Column
		if Column * column then
			---@cast column rizu.skin.easy_lua.Column
			configured_column = column
		else
			configured_column = Column(column)
		end
		local input = configured_column.input
		assert(not inputs[input], "conveyor columns must have unique inputs")
		inputs[input] = true
		self.columns[index] = configured_column
	end
end

---Draw visible notes in a viewport using a 480-unit native height. The native
---width expands/contracts with the viewport aspect ratio; authored column
---positions and pixels_per_second therefore stay in native units.
---@param visible_notes rizu.VisualNote[]
---@param viewport_width number Gameplay viewport width in drawable pixels.
---@param viewport_height number Gameplay viewport height in drawable pixels.
---@param transform love.Transform Maps viewport coordinates to drawable pixels.
---@param is_column_pressed fun(column: chart.Column): boolean Current input state for a chart input.
function Conveyor:draw(visible_notes, viewport_width, viewport_height, transform, is_column_pressed)
	assert(type(viewport_width) == "number" and viewport_width > 0, "viewport width must be positive")
	assert(type(viewport_height) == "number" and viewport_height > 0, "viewport height must be positive")
	local canvas_width = Conveyor.getCanvasWidth(viewport_width, viewport_height)
	local scale = viewport_height / Conveyor.HEIGHT

	love.graphics.push("all")
	love.graphics.applyTransform(transform)
	love.graphics.scale(scale)
	love.graphics.translate((canvas_width - Conveyor.WIDTH) / 2, 0)
	for i = 1, #self.columns do
		self.columns[i]:drawBackground(Conveyor.HEIGHT)
	end
	for i = 1, #self.columns do
		self.columns[i]:draw(visible_notes, self.pixels_per_second, self.reverse, 0, canvas_width)
	end
	for i = 1, #self.columns do
		local column = self.columns[i]
		local pressed = false
		if is_column_pressed then
			pressed = is_column_pressed(column.input)
		end
		column:updateInput(pressed)
		column:drawReceptor(pressed)
	end
	-- Stage lighting overlays the column background, notes, and receptor.
	for i = 1, #self.columns do
		self.columns[i]:drawStageLighting()
	end
	-- Judgement-driven hit effects stay on top of the stage lighting.
	for i = 1, #self.columns do
		self.columns[i]:drawHitLighting()
	end
	love.graphics.pop()
end

---@param dt number
function Conveyor:update(dt)
	for i = 1, #self.columns do
		self.columns[i]:update(dt)
	end
end

return Conveyor
