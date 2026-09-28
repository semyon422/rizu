local Conveyor = require("rizu.skin.easy_lua.Conveyor")
local Column = require("rizu.skin.easy_lua.Column")
local Note = require("rizu.skin.easy_lua.Note")

local test = {}

local function visual_note(input, kind, start_dt, end_dt)
	return {
		type = kind,
		start_dt = start_dt,
		end_dt = end_dt,
		getColumn = function() return input end,
		getState = function() return "clear" end,
	}
end

---@param t testing.T
function test.column_uses_explicit_native_geometry_and_note_style(t)
	local note = Note()
	local column = Column({input = "key1", x = 123, y = 321, width = 48, notes = note})
	t:eq(column.input, "key1")
	t:eq(column.x, 123)
	t:eq(column.y, 321)
	t:eq(column.width, 48)
	t:eq(column.notes, note)
end

---@param t testing.T
function test.column_rejects_invalid_geometry(t)
	t:assert(not pcall(function()
		Column({input = "key1", x = 100, y = 300, width = 0})
	end))
	t:assert(not pcall(function()
		Column({input = "key1", x = 0 / 0, y = 300, width = 48})
	end))
	local column = Column({input = "key1", x = 100, y = 300, width = 48})
	t:eq(column.notes.image, nil)
end

function test.column_hit_lighting_uses_note_type_and_success_state(t)
	local HitLighting = require("rizu.skin.easy_lua.HitLighting")
	local image = {getWidth = function() return 40 end, getDimensions = function() return 40, 40 end}
	local short_lighting = HitLighting({image = image})
	local long_lighting = HitLighting({image = image})
	local column = Column({
		input = "key1", x = 100, y = 300, width = 40,
		hit_lighting = {short = short_lighting, long = long_lighting},
	})
	local short_note = {
		type = "short",
		getColumn = function() return "key1" end,
		getState = function() return "clear" end,
	}
	local long_note = {
		type = "long",
		getColumn = function() return "key1" end,
		getState = function() return "clear" end,
	}

	column:triggerHitLighting({short_note, long_note})
	t:eq(short_lighting.active, false)
	t:eq(long_lighting.active, false)
	short_note.getState = function() return "passed" end
	column:triggerHitLighting({short_note, long_note})
	t:eq(short_lighting.active, true)
	t:eq(long_lighting.active, false)
	column:triggerHitLighting({short_note, long_note})
	t:eq(short_lighting.elapsed, 0)
	long_note.getState = function() return "startPassedPressed" end
	column:triggerHitLighting({short_note, long_note})
	t:eq(long_lighting.active, true)
	column:update(0.1)
	t:eq(short_lighting.elapsed, 0.1)
	t:eq(long_lighting.elapsed, 0.1)
end

---@param t testing.T
function test.conveyor_uses_480_high_native_space_and_aspect_scaled_width(t)
	t:eq(Conveyor.HEIGHT, 480)
	t:eq(Conveyor.WIDTH, 640)
	t:eq(Conveyor.getCanvasWidth(1280, 720), 1280 / 720 * 480)
	t:eq(Conveyor.getCanvasWidth(800, 600), 640)
	local conveyor = Conveyor({columns = {}, pixels_per_second = 240, reverse = true})
	t:eq(conveyor.pixels_per_second, 240)
	t:eq(conveyor.reverse, true)
end

---@param t testing.T
function test.conveyor_requires_unique_inputs_and_positive_scroll_speed(t)
	local column = {input = "key1", x = 100, y = 300, width = 48}
	t:assert(not pcall(function() Conveyor({columns = {column, column}}) end))
	t:assert(not pcall(function() Conveyor({columns = {}, pixels_per_second = 0}) end))
end

---@param t testing.T
function test.note_uses_visual_time_native_speed_and_centered_native_size(t)
	local graphics = love.graphics
	local old_draw, old_color = graphics.draw, graphics.setColor
	local calls = {}
	graphics.setColor = function() end
	graphics.draw = function(image, x, y, rotation, scale_x, scale_y, origin_x, origin_y)
		table.insert(calls, {image, x, y, rotation, scale_x, scale_y, origin_x, origin_y})
	end
	local image = {getDimensions = function() return 20, 10 end}
	local renderer = Note({image = image})
	local notes = {visual_note("key1", "short", -0.5)}
	local ok, err = pcall(function()
		renderer:draw(notes, "key1", 100, 300, 480, false, 0, 640, 480)
		t:eq(#calls, 1)
		t:eq(calls[1][2], 100)
		t:eq(calls[1][3], 60)
		t:eq(calls[1][5], 1)
		t:eq(calls[1][6], 1)
		t:eq(calls[1][7], 10)
		t:eq(calls[1][8], 5)
		calls = {}
		local later_note = {visual_note("key1", "short", -0.5)}
		renderer:draw(later_note, "key1", 100, 200, 480, true, 0, 640, 480)
		t:eq(calls[1][3], 440)
	end)
	graphics.draw, graphics.setColor = old_draw, old_color
	if not ok then error(err) end
end

---@param t testing.T
function test.note_filters_input_and_draws_long_note_parts(t)
	local graphics = love.graphics
	local old_draw, old_color = graphics.draw, graphics.setColor
	local calls = {}
	graphics.setColor = function() end
	graphics.draw = function(image, x, y, rotation, scale_x, scale_y, origin_x, origin_y)
		table.insert(calls, {image, x, y, scale_x, scale_y, origin_x, origin_y})
	end
	local ok, err = pcall(function()
		local function image(width, height)
			return {getDimensions = function() return width, height end}
		end
		local head, body, tail = image(12, 8), image(4, 20), image(16, 6)
		local renderer = Note({hold = {
			head = head,
			body = body,
			tail = tail,
			body_fit_duration = true,
		}})
		local notes = {
			visual_note("key1", "long", -0.5, 0.5),
			visual_note("key2", "short", -0.5),
		}
		renderer:draw(notes, "key1", 100, 240, 100, false, 0, 640, 480)
		t:eq(#calls, 3)
		t:eq(calls[1][1], body)
		t:eq(calls[1][4], 1)
		t:eq(calls[1][5], 5)
		t:eq(calls[2][1], head)
		t:eq(calls[3][1], tail)
		calls = {}
		local held_note = visual_note("key1", "long", 0, 0.5)
		held_note.getState = function() return "startPassedPressed" end
		renderer:draw({held_note}, "key1", 100, 240, 100, false, 0, 640, 480)
		t:eq(#calls, 3)
		t:eq(calls[1][1], body)
		t:eq(calls[2][1], head)
		t:eq(calls[2][3], 240)
		t:eq(calls[3][1], tail)
	end)
	graphics.draw, graphics.setColor = old_draw, old_color
	if not ok then error(err) end
end

return test
