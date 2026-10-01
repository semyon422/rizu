local class = require("class")
local Note = require("rizu.skin.easy_lua.Note")
local Receptor = require("rizu.skin.easy_lua.Receptor")
local StageLighting = require("rizu.skin.easy_lua.StageLighting")
local HitLighting = require("rizu.skin.easy_lua.HitLighting")
local HitLightingGroup = require("rizu.skin.easy_lua.HitLightingGroup")

---@class rizu.skin.easy_lua.Column.HitLightingConfig
---@field short rizu.skin.easy_lua.HitLighting|rizu.skin.easy_lua.HitLighting.Config? Short-note hit effect.
---@field long rizu.skin.easy_lua.HitLighting|rizu.skin.easy_lua.HitLightingGroup|rizu.skin.easy_lua.HitLighting.Config? Long-note hold effect.
---@field long_start rizu.skin.easy_lua.HitLighting|rizu.skin.easy_lua.HitLightingGroup|rizu.skin.easy_lua.HitLighting.Config? Long-note head effect.
---@field long_end rizu.skin.easy_lua.HitLighting|rizu.skin.easy_lua.HitLightingGroup|rizu.skin.easy_lua.HitLighting.Config? Long-note tail effect.

---@class rizu.skin.easy_lua.Column.Config
---@field input chart.Column Input represented by this column.
---@field x number Centerline in the conveyor's native coordinate space.
---@field y number Hit position in the conveyor's native coordinate space.
---@field width number Suggested column width; note textures are not resized to it.
---@field notes rizu.skin.easy_lua.Note|rizu.skin.easy_lua.Note.Config? Note drawing style.
---@field background_color number[]? RGBA background fill; omitted means transparent.
---@field receptor rizu.skin.easy_lua.Receptor|rizu.skin.easy_lua.Receptor.Config? Input-state receptor art.
---@field stage_lighting rizu.skin.easy_lua.StageLighting|rizu.skin.easy_lua.StageLighting.Config? Input-triggered stage flash.
---@field hit_lighting rizu.skin.easy_lua.Column.HitLightingConfig? Separate short/long note-judgement effects.

---@class rizu.skin.easy_lua.Column
---@operator call: rizu.skin.easy_lua.Column
---@field input chart.Column
---@field x number
---@field y number
---@field width number
---@field background_color number[]?
---@field receptor rizu.skin.easy_lua.Receptor?
---@field stage_lighting rizu.skin.easy_lua.StageLighting?
---@field hit_lighting {[string]: rizu.skin.easy_lua.HitLighting|rizu.skin.easy_lua.HitLightingGroup?}?
---@field hit_lighting_notes {[rizu.VisualNote]: {[string]: boolean}}?
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
	self.stage_lighting = nil
	self.hit_lighting = nil
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
	local configured_stage_lighting = config.stage_lighting
	if configured_stage_lighting then
		if StageLighting * configured_stage_lighting then
			---@cast configured_stage_lighting rizu.skin.easy_lua.StageLighting
			self.stage_lighting = configured_stage_lighting
		else
			self.stage_lighting = StageLighting(configured_stage_lighting)
		end
	end
	local configured_hit_lighting = config.hit_lighting
	if configured_hit_lighting then
		assert(type(configured_hit_lighting) == "table", "column hit_lighting must be a table")
		self.hit_lighting = {} ---@type {[string]: rizu.skin.easy_lua.HitLighting|rizu.skin.easy_lua.HitLightingGroup}
		local lighting_configs = configured_hit_lighting ---@type {[string]: rizu.skin.easy_lua.HitLighting|rizu.skin.easy_lua.HitLightingGroup|rizu.skin.easy_lua.HitLighting.Config}
		for _, note_type in ipairs({"short", "long", "long_start", "long_end"}) do
			---@cast note_type "short"|"long"
			local configured_lighting = lighting_configs[note_type]
			if configured_lighting then
				if HitLighting * configured_lighting or HitLightingGroup * configured_lighting then
					self.hit_lighting[note_type] = configured_lighting
				elseif configured_lighting.effects then
					self.hit_lighting[note_type] = HitLightingGroup(configured_lighting)
				else
					self.hit_lighting[note_type] = HitLighting(configured_lighting)
				end
			end
		end
		self.hit_lighting_notes = setmetatable({}, {__mode = "k"})
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
	if pressed and not self.input_was_pressed and self.stage_lighting then
		self.stage_lighting:trigger()
	end
	self.input_was_pressed = pressed
end


function Column:drawStageLighting()
	if self.stage_lighting then
		self.stage_lighting:draw(self.x, self.y)
	end
end

function Column:drawHitLighting()
	if not self.hit_lighting then return end
	for _, name in ipairs({"short", "long_start", "long_end", "long"}) do
		local lighting = self.hit_lighting[name]
		if lighting then lighting:draw(self.x, self.y) end
	end
end

---@param visible_notes rizu.VisualNote[]
function Column:triggerHitLighting(visible_notes)
	if not self.hit_lighting then return end
	self.hit_lighting_notes = self.hit_lighting_notes or setmetatable({}, {__mode = "k"})
	local held_long = false
	for _, visual_note in ipairs(visible_notes) do
		if visual_note:getColumn() == self.input then
			local state = visual_note:getState()
			local events = self.hit_lighting_notes[visual_note]
			if not events then
				events = {}
				self.hit_lighting_notes[visual_note] = events
			end
			if visual_note.type == "short" and state == "passed" and not events.short then
				events.short = true
				local lighting = self.hit_lighting.short
				if lighting then lighting:trigger() end
			elseif visual_note.type == "long" then
				if state == "startPassedPressed" then held_long = true end
				if state == "startPassedPressed" and not events.long_start then
					events.long_start = true
					local lighting = self.hit_lighting.long_start
					if lighting then lighting:trigger() end
				elseif state == "endPassed" and not events.long_end then
					events.long_end = true
					local lighting = self.hit_lighting.long_end
					if lighting then lighting:trigger() end
				end
			end
		end
	end
	local hold = self.hit_lighting.long
	if hold then hold:setHeld(held_long) end
end

---@param pressed boolean
function Column:drawReceptor(pressed)
	if self.receptor then
		self.receptor:draw(self.x, self.y, pressed)
	end
end

---@param viewport_height number Conveyor native height.
function Column:drawNotes(visible_notes, pixels_per_second, reverse, left, right, viewport_height)
	self:triggerHitLighting(visible_notes)
	self.notes:draw(visible_notes, self.input, self.x, self.y,
		pixels_per_second, reverse, left, right, viewport_height or 480)
end

function Column:draw(visible_notes, pixels_per_second, reverse, left, right, viewport_height)
	self:drawNotes(visible_notes, pixels_per_second, reverse, left, right, viewport_height)
end

---@param dt number
function Column:update(dt)
	self.notes:update(dt)
	if self.receptor then self.receptor:update(dt) end
	if self.stage_lighting then self.stage_lighting:update(dt) end
	if self.hit_lighting then
		for _, name in ipairs({"short", "long_start", "long_end", "long"}) do
			local lighting = self.hit_lighting[name]
			if lighting then lighting:update(dt) end
		end
	end
end

return Column
