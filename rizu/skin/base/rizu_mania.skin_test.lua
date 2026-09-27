local FakeFilesystem = require("fs.FakeFilesystem")
local NotesPreviewPlayer = require("rizu.preview.NotesPreviewPlayer")
local SkinConfig = require("rizu.skin.SkinConfig")
local Settings = require("rizu.config.Settings")
local SphPreview = require("chart.format.sph.SphPreview")

local skin = assert(love.filesystem.load("rizu/skin/base/rizu_mania.skin.lua"))()

local test = {}

---@param t testing.T
function test.exposes_receptor_and_playfield_properties(t)
	local config = SkinConfig()
	local renderer = skin.load({fs = FakeFilesystem()}, "4key", "gameplay", config,
		"userdata/dlc/skins_rizu/base/skin-config.json")
	local properties = renderer:getProperties()
	t:eq(#properties, 2)
	t:eq(properties[1].key, "receptor.y")
	t:eq(properties[2].key, "playfield.x_offset")
	t:eq(renderer:getReceptorY(), 360)
	t:eq(renderer:getPlayfieldXOffset(), 0)

	renderer:setReceptorY(320)
	renderer:setPlayfieldXOffset(-24)
	t:eq(renderer:getReceptorY(), 320)
	t:eq(renderer:getPlayfieldXOffset(), -24)
	t:eq(config:getOverride("mania", "4key", "receptor.y"), 320)
	t:eq(config:getOverride("mania", "4key", "playfield.x_offset"), -24)
	t:eq(config:getOverride("mania", "7key", "receptor.y"), nil)
end

---@param t testing.T
function test.rejects_out_of_range_properties(t)
	local renderer = skin.load({fs = FakeFilesystem()}, "4key", "gameplay", SkinConfig(), "config.json")
	t:has_error(function() renderer:setReceptorY(481) end)
	t:has_error(function() renderer:setPlayfieldXOffset(641) end)
end

---@param t testing.T
function test.preview_column_mapping_handles_stale_and_changed_keymodes(t)
	local settings = {
		getBoolean = function(_, key) return key == Settings.keys.select.chart_preview end,
		getNumber = function() return 1 end,
	}
	local player = NotesPreviewPlayer(settings, {rate = 1, getTime = function() return 0 end}, {})
	local renderer = skin.load({fs = FakeFilesystem()}, "7key1scratch", "preview", SkinConfig(), "config.json")
	local three_key_preview = SphPreview:encode({{offset = 0, notes = {true}}, {offset = 1}})
	player:setChartview({chartdiff_inputmode = "3key", notes_preview = three_key_preview})

	t:eq(renderer:getPreviewDisplayColumn(player, 1, 8), 1)
	player:setChartview({chartdiff_inputmode = "7key1scratch", notes_preview = three_key_preview})
	t:eq(renderer:getPreviewDisplayColumn(player, 1, 8), 1)
	t:eq(renderer:getPreviewDisplayColumn(player, 8, 8), 8)
	player.column_map = {[1] = 4, [2] = 2}
	t:eq(renderer:getPreviewDisplayColumn(player, 1, 8), 4)
	player:setChartview(nil)
	t:eq(player.input_mode, nil)
	t:eq(renderer:getPreviewDisplayColumn(player, 1, 8), 1)
end

local function capture_note_rectangles(draw)
	local previous_rectangle = love.graphics.rectangle
	local note_rectangles = {}
	love.graphics.rectangle = function(_, x, y, width, height)
		if width == 48 and height == 30 then
			note_rectangles[#note_rectangles + 1] = {x, y, width, height}
		end
	end
	local ok, err = xpcall(draw, debug.traceback)
	love.graphics.rectangle = previous_rectangle
	if not ok then error(err) end
	return note_rectangles
end

---@param t testing.T
function test.gameplay_notes_continue_below_the_receptor_after_their_absolute_time(t)
	local renderer = skin.load({
		fs = FakeFilesystem(),
		rhythm_engine = {
			visual_engine = {
				visible_notes = {
					{type = "short", start_dt = 0.1, getState = function() return "missed" end,
						getColumn = function() return "key1" end},
				},
			},
			isColumnPressed = function() return false end,
		},
	}, "4key", "gameplay", SkinConfig(), "config.json")
	local note_rectangles = capture_note_rectangles(function()
		renderer:draw(640, 480, love.math.newTransform())
	end)
	t:eq(#note_rectangles, 1)
	t:assert(note_rectangles[1][2] > renderer:getReceptorY())
end

---@param t testing.T
function test.preview_notes_continue_below_the_receptor_after_their_absolute_time(t)
	local renderer = skin.load({fs = FakeFilesystem()}, "4key", "preview", SkinConfig(), "config.json")
	local preview = {
		columns = {{{time = 0.5, end_time = 0.5}}, {}, {}, {}},
		getVisibleRange = function(self, column)
			return 1, #self.columns[column]
		end,
	}
	local note_rectangles = capture_note_rectangles(function()
		renderer:drawPreview({notes = preview, input_mode = "4key", time = 0.6, rate = 1}, 640, 480)
	end)
	t:eq(#note_rectangles, 1)
	t:assert(note_rectangles[1][2] > renderer:getReceptorY())
end

return test
