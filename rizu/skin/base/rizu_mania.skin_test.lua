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

return test
