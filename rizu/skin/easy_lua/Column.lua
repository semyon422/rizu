local class = require("class")
local Note = require("rizu.skin.easy_lua.Note")
local Receptor = require("rizu.skin.easy_lua.Receptor")
local HitLighting = require("rizu.skin.easy_lua.HitLighting")

---@class rizu.skin.easy_lua.Column.Config
---@field input chart.Column Input represented by this column.
---@field x number Centerline in the conveyor's 640x480 reference space.
---@field y number Hit position in the conveyor's 640x480 reference space.
---@field width number Suggested column width; note textures are not resized to it.
---@field notes rizu.skin.easy_lua.Note|rizu.skin.easy_lua.Note.Config? Note drawing style.
---@field background_color number[]? RGBA background fill; omitted means transparent.
---@field receptor rizu.skin.easy_lua.Receptor|rizu.skin.easy_lua.Receptor.Config? Input-state receptor art.
---@field hit_lighting rizu.skin.easy_lua.HitLighting|rizu.skin.easy_lua.HitLighting.Config? Input-triggered hit flash.

---@class rizu.skin.easy_lua.Column
---@operator call: rizu.skin.easy_lua.Column
---@field input chart.Column
---@field x number
---@field y number
---@field width number
---@field background_color number[]?
---@field receptor rizu.skin.easy_lua.Receptor?
---@field hit_lighting rizu.skin.easy_lua.HitLighting?
---@field notes rizu.skin.easy_lua.Note
local Column = class()

---@param config rizu.skin.easy_lua.Column.Config
function Column:new(config)
	assert(type(config) == "table", "column config must be a table")
	assert(type(config.input) == "string" and config.input ~= "", "column input must be a non-empty string")
	assert(type(config.x) == "number" and config.x == config.x and math.abs(config.x) < math.huge,
		"column x must be finite")
	assert(type(config.y) == "number" and config.y == config.y and math.abs(config.y) < math.huge,
		"column y must be finite")
	assert(type(config.width) == "number" and config.width > 0 and config.width < math.huge,
		"column width must be positive and finite")
	self.input = config.input
	self.x = config.x
	self.y = config.y
	self.width = config.width
	self.background_color = config.background_color
	if self.background_color then
		assert(type(self.background_color) == "table" and #self.background_color >= 3
			and #self.background_color <= 4, "column background_color must be RGB or RGBA")
		for i = 1, #self.background_color do
			local channel = self.background_color[i]
			assert(type(channel) == "number" and channel == channel and channel >= 0 and channel <= 1,
				"column background_color channels must be between 0 and 1")
		end
	end
	local configured_receptor = config.receptor
	if configured_receptor then
		if Receptor * configured_receptor then
			---@cast configured_receptor rizu.skin.easy_lua.Receptor
			self.receptor = configured_receptor
		else
			self.receptor = Receptor(configured_receptor)
		end
	end
	local configured_hit_lighting = config.hit_lighting
	if configured_hit_lighting then
		if HitLighting * configured_hit_lighting then
			---@cast configured_hit_lighting rizu.skin.easy_lua.HitLighting
			self.hit_lighting = configured_hit_lighting
		else
			self.hit_lighting = HitLighting(configured_hit_lighting)
		end
	end
	local configured_notes = config.notes
	if Note * configured_notes then
		---@cast configured_notes rizu.skin.easy_lua.Note
		self.notes = configured_notes
	else
		self.notes = Note(configured_notes)
	end
end

---@param height number Conveyor native height.
function Column:drawBackground(height)
	local color = self.background_color
	if not color then return end
	love.graphics.setColor(color[1], color[2], color[3], color[4] or 1)
	love.graphics.rectangle("fill", self.x - self.width / 2, 0, self.width, height)
end

---@param pressed boolean
function Column:updateInput(pressed)
	if pressed and not self.input_was_pressed and self.hit_lighting then
		self.hit_lighting:trigger()
	end
	self.input_was_pressed = pressed
end


function Column:drawHitLighting()
	if self.hit_lighting then
		self.hit_lighting:draw(self.x, self.y)
	end
end

---@param pressed boolean
function Column:drawReceptor(pressed)
	if self.receptor then
		self.receptor:draw(self.x, self.y, pressed)
	end
end

---@param visible_notes rizu.VisualNote[]
---@param pixels_per_second number
---@param reverse boolean
---@param left number
---@param right number
function Column:draw(visible_notes, pixels_per_second, reverse, left, right)
	self.notes:draw(visible_notes, self.input, self.x, self.y,
		pixels_per_second, reverse, left, right, 480)
end

---@param dt number
function Column:update(dt)
	self.notes:update(dt)
	if self.receptor then self.receptor:update(dt) end
	if self.hit_lighting then self.hit_lighting:update(dt) end
end

return Column
