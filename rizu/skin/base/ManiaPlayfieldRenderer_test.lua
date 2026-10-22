local FakeFilesystem = require("fs.FakeFilesystem")
local NotesPreviewPlayer = require("rizu.preview.NotesPreviewPlayer")
local SkinConfig = require("rizu.skin.SkinConfig")
local Settings = require("rizu.config.Settings")
local SphPreview = require("chart.format.sph.SphPreview")

local Renderer = require("rizu.skin.base.ManiaPlayfieldRenderer")

local test = {}

---@param t testing.T
function test.exposes_receptor_and_playfield_properties(t)
	local config = SkinConfig()
	local renderer = Renderer({fs = FakeFilesystem()}, "4key", "preview", config, "userdata/dlc/skins_rizu/base/skin-config.json")
	local properties = renderer:getProperties()
	t:eq(#properties, 8)
	t:eq(properties[1].key, "receptor.y")
	t:eq(properties[2].key, "playfield.x_offset")
	t:eq(properties[3].key, "bga.brightness")
	t:eq(properties[4].key, "combo.y")
	t:eq(properties[5].key, "judge.y")
	t:eq(properties[6].key, "column.width")
	t:eq(properties[7].key, "note.shape")
	t:eq(properties[8].key, "judge.scale")
	t:eq(renderer:getColumnWidth(), 48)
	renderer:setColumnWidth(64)
	t:eq(config:get("mania", "4key", "column.width"), 64)
	renderer:setColumnWidth(48)
	t:eq(properties[4].get(), -36)
	t:eq(properties[5].get(), -72)
	properties[5].set(-100)
	t:eq(config:get("mania", "4key", "judge.y"), -100)
	t:eq(renderer:getJudgeScale(), 0.5)
	renderer:setJudgeScale(0.75)
	t:eq(config:get("mania", "4key", "judge.scale"), 0.75)
	renderer:setJudgeScale(0.5)
	t:eq(renderer:getReceptorY(), 430)
	t:eq(renderer:getPlayfieldXOffset(), 0)
	t:eq(renderer:getBgaBrightness(), 0.15)

	renderer:setReceptorY(320)
	renderer:setPlayfieldXOffset(-24)
	renderer:setBgaBrightness(0.4)
	t:eq(renderer:getReceptorY(), 320)
	t:eq(renderer:getPlayfieldXOffset(), -24)
	t:eq(renderer:getBgaBrightness(), 0.4)
	t:eq(config:get("mania", "4key", "receptor.y"), 320)
	t:eq(config:get("mania", "4key", "playfield.x_offset"), -24)
	t:eq(config:get("mania", "4key", "bga.brightness"), 0.4)
	t:eq(config:get("mania", "7key", "receptor.y"), nil)
end

---@param t testing.T
function test.exposes_gameplay_hud_with_accuracy_view(t)
	local game = {
		fs = FakeFilesystem(),
		rhythm_engine = {
			score_engine = {
				accuracySource = {getAccuracyString = function() return "97.25%" end},
			},
		},
	}
	local original_new_font = love.graphics.newFont
	local fonts = {}
	love.graphics.newFont = function(_, size)
		local font = {
			size = size,
			released = false,
			getWidth = function(self, text) return #text * self.size / 2 end,
			getHeight = function(self) return self.size end,
			release = function(self) self.released = true end,
		}
		fonts[#fonts + 1] = font
		return font
	end
	local renderer = Renderer(game, "4key", "gameplay", SkinConfig(), "config.json")
	t:eq(#renderer.foreground_hud.children, 0)
	t:eq(#renderer.background_hud.children, 1)
	t:assert(require("rizu.skin.views.BgaView") * renderer.background_hud.children[1])
	renderer:load()
	love.graphics.newFont = original_new_font
	t:assert(#renderer.foreground_hud.children > 0)
	local accuracy_view = renderer.foreground_hud.children[1]
	t:eq(accuracy_view.anchor, "top_right")
	t:eq(accuracy_view.x, -8)
	t:eq(accuracy_view.y, 38)
	t:eq(accuracy_view.text, "97.25%")
	t:eq(accuracy_view.font:getHeight(), 24)
	t:eq(renderer.foreground_hud.children[2].text, "") -- score source not present
	t:eq(renderer.foreground_hud.children[2].x, -8)
	t:eq(renderer.foreground_hud.children[2].y, 8)
	t:eq(renderer.foreground_hud.children[3].text, "") -- combo source not present
	t:eq(renderer.foreground_hud.children[4].image, nil) -- no judgement yet

	local hud = renderer.foreground_hud
	local native_width, native_height, hud_transform
	local draw_hud = hud.draw
	hud.draw = function(_, width, height, transform)
		native_width, native_height, hud_transform = width, height, transform
	end
	renderer:drawHud(1280, 720, love.math.newTransform())
	hud.draw = draw_hud
	t:aeq(native_width, 1280 / 1.5, 1e-6)
	t:aeq(native_height, 720 / 1.5, 1e-6)
	for _, view in ipairs({renderer.foreground_hud.children[1], renderer.foreground_hud.children[2]}) do
		local view_transform = view:getWorldTransform(native_width, native_height, hud_transform)
		local right_edge = view_transform:transformPoint(view.width, 0)
		t:aeq(right_edge, 1280 - 8 * 1.5, 1e-3)
	end

	renderer:unload()
	t:eq(#renderer.foreground_hud.children, 0)
	t:eq(renderer.hud_fonts, nil)
	t:eq(#fonts, 2)
	for _, font in ipairs(fonts) do t:assert(font.released) end

	local preview_renderer = Renderer(game, "4key", "preview", SkinConfig(), "config.json")
	t:eq(#preview_renderer.foreground_hud.children, 0)
	preview_renderer:load()
	t:eq(#preview_renderer.foreground_hud.children, 0)
end

---@param t testing.T
function test.rejects_out_of_range_properties(t)
	local renderer = Renderer({fs = FakeFilesystem()}, "4key", "preview", SkinConfig(), "config.json")
	t:has_error(function() renderer:setReceptorY(481) end)
	t:has_error(function() renderer:setPlayfieldXOffset(641) end)
	t:has_error(function() renderer:setJudgeScale(3) end)
	t:has_error(function() renderer:setColumnWidth(15) end)
	t:has_error(function() renderer:setHudY("combo.y", 241) end)
	renderer:setBgaBrightness(2)
	t:eq(renderer:getBgaBrightness(), 1)
	renderer:setBgaBrightness(-1)
	t:eq(renderer:getBgaBrightness(), 0)
end

---@param t testing.T
function test.preview_column_mapping_handles_stale_and_changed_keymodes(t)
	local settings = {
		getBoolean = function(_, key) return key == Settings.keys.select.chart_preview end,
		getNumber = function() return 1 end,
	}
	local player = NotesPreviewPlayer(settings, {rate = 1, getTime = function() return 0 end}, {})
	local renderer = Renderer({fs = FakeFilesystem()}, "7key1scratch", "preview", SkinConfig(), "config.json")
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

for _, shape in ipairs({"rectangle", "circle", "ellipse", "arrow"}) do
	Renderer.note_images[shape] = {getDimensions = function() return 88, 60 end}
end

---@return number[][] drawn notes as {x, y, rotation, scale}
local function capture_note_rectangles(draw)
	local previous_draw, previous_rectangle = love.graphics.draw, love.graphics.rectangle
	local note_rectangles = {}
	love.graphics.rectangle = function() end
	love.graphics.draw = function(_, x, y, rotation, scale)
		note_rectangles[#note_rectangles + 1] = {x, y, rotation, scale}
	end
	local ok, err = xpcall(draw, debug.traceback)
	love.graphics.draw, love.graphics.rectangle = previous_draw, previous_rectangle
	if not ok then error(err) end
	return note_rectangles
end

---@param t testing.T
function test.gameplay_notes_continue_below_the_receptor_after_their_absolute_time(t)
	local original_new_font = love.graphics.newFont
	love.graphics.newFont = function()
		return {
			getWidth = function(_, text) return #text * 12 end,
			getHeight = function() return 24 end,
			getDPIScale = function() return 1 end,
		}
	end
	local renderer = Renderer({
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
	love.graphics.newFont = original_new_font
	local note_rectangles = capture_note_rectangles(function()
		renderer:draw(640, 480, love.math.newTransform())
	end)
	t:eq(#note_rectangles, 1)
	t:assert(note_rectangles[1][2] > renderer:getReceptorY())
end

---@param t testing.T
function test.gameplay_does_not_draw_successfully_hit_notes(t)
	local original_new_font = love.graphics.newFont
	love.graphics.newFont = function()
		return {
			getWidth = function(_, text) return #text * 12 end,
			getHeight = function() return 24 end,
			getDPIScale = function() return 1 end,
		}
	end
	local renderer = Renderer({
		fs = FakeFilesystem(),
		rhythm_engine = {
			visual_engine = {
				visible_notes = {
					{type = "short", start_dt = 0, getState = function() return "passed" end,
						getColumn = function() return "key1" end},
					{type = "long", start_dt = 0.1, end_dt = -0.1,
						getState = function() return "endPassed" end,
						getColumn = function() return "key2" end},
				},
			},
			isColumnPressed = function() return false end,
		},
	}, "4key", "gameplay", SkinConfig(), "config.json")
	love.graphics.newFont = original_new_font

	local note_rectangles = capture_note_rectangles(function()
		renderer:draw(640, 480, love.math.newTransform())
	end)
	t:eq(#note_rectangles, 0)
end

---@param t testing.T
function test.preview_notes_continue_below_the_receptor_after_their_absolute_time(t)
	local renderer = Renderer({fs = FakeFilesystem()}, "4key", "preview", SkinConfig(), "config.json")
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

---@param t testing.T
function test.arrow_notes_are_4k_only_and_rotate_by_column(t)
	local config = SkinConfig()
	local renderer = Renderer({fs = FakeFilesystem()}, "4key", "preview", config, "config.json")
	t:tdeq(renderer:getNoteShapes(), {"rectangle", "circle", "ellipse", "arrow"})
	t:eq(renderer:getNoteShape(), "rectangle")
	renderer:setNoteShape("arrow")
	t:eq(config:get("mania", "4key", "note.shape"), "arrow")

	local preview = {
		columns = {{{time = 0.5, end_time = 0.5}}, {{time = 0.5, end_time = 0.5}}, {{time = 0.5, end_time = 0.5}}, {{time = 0.5, end_time = 0.5}}},
		getVisibleRange = function(self, column) return 1, #self.columns[column] end,
	}
	local drawn = capture_note_rectangles(function()
		renderer:drawPreview({notes = preview, input_mode = "4key", time = 0.6, rate = 1}, 640, 480)
	end)
	t:eq(#drawn, 4)
	t:eq(drawn[1][3], 0)
	t:eq(drawn[2][3], -math.pi / 2)
	t:eq(drawn[3][3], math.pi / 2)
	t:eq(drawn[4][3], math.pi)
	t:eq(drawn[1][4], 0.5) -- 48 * 44 / 48 / 88

	renderer:setColumnWidth(96)
	local wide = capture_note_rectangles(function()
		renderer:drawPreview({notes = preview, input_mode = "4key", time = 0.6, rate = 1}, 640, 480)
	end)
	t:eq(wide[1][4], 1) -- scales with the column, keeping the aspect ratio
	t:eq(wide[2][1] - wide[1][1], 96)

	local seven = Renderer({fs = FakeFilesystem()}, "7key", "preview", SkinConfig(), "config.json")
	t:tdeq(seven:getNoteShapes(), {"rectangle", "circle", "ellipse"})
	t:has_error(function() seven:setNoteShape("arrow") end)
	seven.config:set("mania", "7key", "note.shape", "arrow")
	t:eq(seven:getNoteShape(), "rectangle")
end

return test
