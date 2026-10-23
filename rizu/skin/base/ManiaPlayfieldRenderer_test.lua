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
	t:eq(properties[4].key, "column.width")
	t:eq(properties[5].key, "column.gap")
	t:eq(properties[6].key, "column.lines")
	t:eq(properties[7].key, "hold.end_offset")
	t:eq(properties[8].key, "note.shape")
	t:eq(renderer:getHoldEndOffset(), 0)
	t:eq(renderer:getColumnGap(), 4)
	t:eq(renderer:getColumnLines(), true)
	renderer:setColumnLines(false)
	t:eq(config:get("mania", "4key", "column.lines"), false)
	renderer:setColumnLines(true)
	t:eq(renderer:getColumnWidth(), 48)
	renderer:setColumnWidth(64)
	t:eq(config:get("mania", "4key", "column.width"), 64)
	renderer:setColumnWidth(48)
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
---@param renderer rizu.skin.base.ManiaPlayfieldRenderer
---@return string[] requested Texture names the elements asked for.
local function stub_textures(renderer)
	local requested = {}
	local image = {getDimensions = function() return 20, 46 end}
	local textures = renderer.textures
	textures.setFallbackArchive = function() end
	textures.loadAsync = function(_, assets)
		for _, asset in ipairs(assets) do requested[#requested + 1] = asset.name end
		return true
	end
	textures.getFrames = function() return {image} end
	textures.getAnimationFrames = function() return {image} end
	return requested
end

---@param t testing.T
function test.default_hud_puts_score_on_screen_and_combo_on_the_columns(t)
	local game = {
		fs = FakeFilesystem(),
		api = {gameplay = {
			getAccuracy = function() return 0.9725, "97.25%", 97.25 end,
			getScore = function() end,
			getCombo = function() end,
			getJudgementCount = function() return 0 end,
			getJudgeNames = function() return {} end,
		}},
	}
	local renderer = Renderer(game, "4key", "gameplay", SkinConfig(), "config.json")
	local requested = stub_textures(renderer)
	t:eq(#renderer.foreground_hud.children, 0)
	t:eq(#renderer.background_hud.children, 1)
	t:assert(require("rizu.skin.views.BgaView") * renderer.background_hud.children[1])
	renderer:load()
	local names = {}
	for _, name in ipairs(requested) do names[name] = true end
	t:assert(names["score-0"] and names["judges/marvelous"] and names["judges/pgreat"])

	local accuracy, score = renderer:getHudElements("screen")[1], renderer:getHudElements("screen")[2]
	t:eq(accuracy.type, "accuracy")
	t:eq(accuracy.anchor, "top_right")
	t:eq(accuracy.x, -8)
	t:eq(accuracy.y, 38)
	renderer:updateHud(0)
	t:eq(accuracy.text, "97.25%")
	t:eq(score.text, "") -- no score source
	t:eq(score.y, 8)
	local combo, judgement = renderer:getHudElements("conveyor")[1], renderer:getHudElements("conveyor")[2]
	t:eq(combo.y, -36)
	t:eq(judgement.y, -72)
	t:eq(judgement.values.scale, 0.5)
	t:eq(judgement.values.colored, true)

	local screen, conveyor = {}, {}
	local screen_draw, conveyor_draw = renderer.foreground_hud.draw, renderer.conveyor_hud.draw
	renderer.foreground_hud.draw = function(_, width, height, transform) screen = {width, height, transform} end
	renderer.conveyor_hud.draw = function(_, width, height, transform) conveyor = {width, height, transform} end
	renderer:drawHud(1280, 720, love.math.newTransform())
	renderer.foreground_hud.draw, renderer.conveyor_hud.draw = screen_draw, conveyor_draw
	t:aeq(screen[1], 1280 / 1.5, 1e-6)
	t:aeq(screen[2], 720 / 1.5, 1e-6)
	accuracy.width = 50
	local right_edge = accuracy:getWorldTransform(screen[1], screen[2], screen[3]):transformPoint(accuracy.width, 0)
	t:aeq(right_edge, 1280 - 8 * 1.5, 1e-3)
	t:eq(conveyor[1], 4 * 48)
	local left = conveyor[3]:transformPoint(0, 0)
	t:aeq(left, 1280 / 2 - 2 * 48 * 1.5, 1e-3) -- the columns are centered

	renderer:unload()
	t:eq(accuracy.font, nil)

	local preview_renderer = Renderer(game, "4key", "preview", SkinConfig(), "config.json")
	preview_renderer:load()
	t:eq(#preview_renderer.foreground_hud.children, 0)
end

---@param t testing.T
function test.old_combo_and_judgement_keys_seed_the_default_hud(t)
	local config = SkinConfig()
	config:set("mania", "4key", "combo.y", 0)
	config:set("mania", "4key", "judge.y", -37)
	config:set("mania", "4key", "judge.scale", 9)
	local renderer = Renderer({fs = FakeFilesystem()}, "4key", "gameplay", config, "config.json")
	local conveyor = renderer:getDefaultHudLayout().conveyor
	t:eq(conveyor[1].y, 0)
	t:eq(conveyor[2].y, -37)
	t:eq(conveyor[2].scale, 2) -- clamped like the old judge scale
end

function test.rejects_out_of_range_properties(t)
	local renderer = Renderer({fs = FakeFilesystem()}, "4key", "preview", SkinConfig(), "config.json")
	t:has_error(function() renderer:setReceptorY(481) end)
	t:has_error(function() renderer:setPlayfieldXOffset(641) end)
	t:has_error(function() renderer:setColumnWidth(15) end)
	t:has_error(function() renderer:setColumnGap(16) end)
	t:has_error(function() renderer:setHoldEndOffset(2.01) end)
	t:has_error(function() renderer:setHoldEndOffset(-0.01) end)
	t:has_error(function() renderer:setColumnLines(1) end)
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

for _, shape in ipairs({"rectangle_long", "rectangle_medium", "rectangle_short", "circle", "ellipse", "arrow"}) do
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
	t:tdeq(renderer:getNoteShapes(), {"rectangle_long", "rectangle_medium", "rectangle_short", "circle", "ellipse", "arrow"})
	t:eq(renderer:getNoteShape(), "rectangle_long")
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
	t:eq(drawn[1][4], 0.5) -- (48 - 4) / 88

	renderer:setColumnWidth(96)
	local wide = capture_note_rectangles(function()
		renderer:drawPreview({notes = preview, input_mode = "4key", time = 0.6, rate = 1}, 640, 480)
	end)
	t:eq(wide[1][4], 92 / 88) -- scales with the column, keeping the aspect ratio
	t:eq(wide[2][1] - wide[1][1], 96)

	renderer:setColumnGap(0)
	local flush = capture_note_rectangles(function()
		renderer:drawPreview({notes = preview, input_mode = "4key", time = 0.6, rate = 1}, 640, 480)
	end)
	t:eq(flush[1][4], 96 / 88)

	local seven = Renderer({fs = FakeFilesystem()}, "7key", "preview", SkinConfig(), "config.json")
	t:tdeq(seven:getNoteShapes(), {"rectangle_long", "rectangle_medium", "rectangle_short", "circle", "ellipse"})
	t:has_error(function() seven:setNoteShape("arrow") end)
	seven.config:set("mania", "7key", "note.shape", "arrow")
	t:eq(seven:getNoteShape(), "rectangle_long")
end

---@param t testing.T
function test.column_lines_can_be_disabled(t)
	local renderer = Renderer({fs = FakeFilesystem()}, "4key", "preview", SkinConfig(), "config.json")
	local preview = {columns = {{}, {}, {}, {}}, getVisibleRange = function() return 1, 0 end}
	local function count_rectangles()
		local previous = love.graphics.rectangle
		local count = 0
		love.graphics.rectangle = function() count = count + 1 end
		local ok, err = xpcall(function()
			renderer:drawPreview({notes = preview, input_mode = "4key", time = 0, rate = 1}, 640, 480)
		end, debug.traceback)
		love.graphics.rectangle = previous
		if not ok then error(err) end
		return count
	end
	local with_lines = count_rectangles()
	renderer:setColumnLines(false)
	t:eq(with_lines - count_rectangles(), 5) -- columns + 1 lines
end

---@param t testing.T
function test.hold_body_end_moves_down_by_a_fraction_of_the_note_height(t)
	local renderer = Renderer({fs = FakeFilesystem()}, "4key", "preview", SkinConfig(), "config.json")
	local preview = {
		columns = {{{time = 0.5, end_time = 1}}, {}, {}, {}},
		getVisibleRange = function(self, column) return 1, #self.columns[column] end,
	}
	---@return number top y of the hold body
	---@return number height
	local function body_top()
		local previous, previous_draw = love.graphics.rectangle, love.graphics.draw
		local top, body_height
		love.graphics.draw = function() end
		love.graphics.rectangle = function(_, _, y, width, height)
			if math.abs(width - 48 * 0.64) < 0.001 then top, body_height = y, height end
		end
		local ok, err = xpcall(function()
			renderer:drawPreview({notes = preview, input_mode = "4key", time = 0.6, rate = 1}, 640, 480)
		end, debug.traceback)
		love.graphics.rectangle, love.graphics.draw = previous, previous_draw
		if not ok then error(err) end
		return top, body_height
	end
	local base = body_top()
	renderer:setHoldEndOffset(0.5)
	-- the test sprites are 88x60, drawn 44 wide: 30 high
	t:eq(body_top(), base + 15)
	renderer:setHoldEndOffset(2)
	t:eq(body_top(), base + 60)
	preview.columns[1][1].end_time = 0.52 -- shorter than the shift: the end stops at the head
	t:eq(select(2, body_top()), 0)
end

return test
