local FakeFilesystem = require("fs.FakeFilesystem")
local OsuManiaRenderer = require("rizu.skin.osu.OsuManiaRenderer")

local test = {}

---@param t testing.T
function test.uses_osu_mania_skin_dimensions_and_key_images(t)
	local skin = {
		path = "skins/example",
		files = {},
		skin_ini = {
			Mania = {
				{Keys = "7", ColumnWidth = "30"},
				{Keys = "4", ColumnStart = "136", ColumnRight = "19", ColumnWidth = "51,51,51,51",
					ColumnSpacing = "2,2,2", HitPosition = "400", ComboPosition = "125",
					KeyImage0 = "Mania\\key-custom", NoteImage0 = "Mania\\note-custom",
					StageHint = "Mania\\stage-custom",
					SpecialStyle = "0", JudgementLine = "0"},
			},
			Fonts = {ComboPrefix = "combo", ScorePrefix = "digits", ComboOverlap = "-2", ScoreOverlap = "1"},
		},
	}
	local game = {
		fs = FakeFilesystem(),
		settings = {getStringMap = function() return {['osu/1osu'] = skin.path} end},
		skinRegistry = {
			getOsuSkin = function(_, path) return path == skin.path and skin end,
			getOsuSkins = function() return {skin} end,
		},
	}
	local renderer = OsuManiaRenderer(game, "4key")

	t:eq(renderer.skin, skin)
	t:eq(renderer.columns, 4)
	t:eq(renderer.hit_position, 400)
	t:eq(renderer.judgement_line, false)
	t:eq(renderer.hud.combo_position, 125)
	t:eq(renderer.hud.combo_prefix, "combo")
	t:eq(renderer.hud.score_prefix, "digits")
	t:eq(renderer.hud.combo_overlap, -2)
	t:eq(renderer.hud.score_overlap, 1)
	local assets = renderer:getSkinAssets()
	local asset_names = {}
	for _, asset in ipairs(assets) do asset_names[asset.name] = true end
	t:assert(asset_names["Mania\\key-custom"])
	t:assert(asset_names["Mania\\note-custom"])
	t:assert(asset_names["Mania\\stage-custom"])
	t:assert(asset_names["digits-9"])
	t:eq(asset_names["ui-button"], nil)
	local left, widths, width_scale = renderer:getPlayfieldLayout()
	t:eq(left, 136)
	t:tdeq(widths, {51, 51, 51, 51})
	t:eq(width_scale, 1)
	t:eq(renderer:getColumnSuffix(0), "1")
	t:eq(renderer:getColumnSuffix(1), "2")
	t:eq(renderer:getColumnSuffix(2), "2")
	t:eq(renderer:getColumnSuffix(3), "1")
	local field_scale, field_x, field_y = renderer:getFieldTransform(1280, 720)
	t:eq(field_scale, 1.5)
	t:eq(field_x, 0)
	t:eq(field_y, 0)
	local note_width, note_height = renderer:getNoteDimensions(1, {
		getDimensions = function() return 512, 164 end,
	})
	t:eq(note_width, 51)
	t:aeq(note_height, 51 * 164 / 512, 1e-6)
	renderer:unload()
end

function test.preview_note_images_ignore_lane_and_hold_tints(t)
	local skin = {
		path = "skins/example",
		files = {},
		skin_ini = {Mania = {{Keys = "4", ColumnWidth = "30,30,30,30"}}},
	}
	local game = {
		fs = FakeFilesystem(),
		settings = {getStringMap = function() return {['osu/1osu'] = skin.path} end},
		skinRegistry = {
			getOsuSkin = function(_, path) return path == skin.path and skin end,
			getOsuSkins = function() return {skin} end,
		},
	}
	local renderer = OsuManiaRenderer(game, "4key")
	local image = {
		getDimensions = function() return 20, 20 end,
	}
	renderer.skin_graphics = {
		skin = skin,
		loaded = true,
		unload = function() end,
		getFrames = function(_, name)
			if name and name:match("^mania%-note") then return {image} end
			return {}
		end,
	}
	local preview = {
		columns = {
			{
				{time = 0.2, end_time = 0.2},
				{time = 0.4, end_time = 0.9},
			},
			{}, {}, {},
		},
		input_mode = "4key",
		time = 0,
		rate = 1,
		getVisibleRange = function() return 1, 2 end,
	}

	local previous_draw = love.graphics.draw
	local previous_rectangle = love.graphics.rectangle
	local draw_colors = {}
	love.graphics.rectangle = function() end
	love.graphics.draw = function(draw_image)
		if draw_image == image then draw_colors[#draw_colors + 1] = {love.graphics.getColor()} end
	end
	local ok, err = xpcall(function()
		renderer:drawPreview({notes = preview, input_mode = "4key", time = 0, rate = 1}, 640, 480)
		t:assert(#draw_colors > 0, "expected preview note textures to draw")
		for _, color in ipairs(draw_colors) do
			t:tdeq(color, {1, 1, 1, 1})
		end
	end, debug.traceback)
	love.graphics.draw = previous_draw
	love.graphics.rectangle = previous_rectangle
	renderer:unload()
	if not ok then error(err) end
end

function test.long_note_tail_is_reversed_and_body_starts_at_half_head(t)
	local renderer = OsuManiaRenderer({fs = FakeFilesystem()}, "4key")
	local images = {
		body = {getDimensions = function() return 20, 20 end},
		head = {getDimensions = function() return 20, 20 end},
		tail = {getDimensions = function() return 20, 20 end},
	}
	renderer.skin_graphics = {
		skin = nil,
		loaded = true,
		unload = function() end,
		getFrames = function(_, name)
			local image = name == "mania-note1L" and images.body
				or name == "mania-note1H" and images.head
				or name == "mania-note1T" and images.tail
			return image and {image} or {}
		end,
	}
	renderer.load = function() end
	renderer.drawStageDecorations = function() end
	renderer.hud.draw = function() end
	local note = {
		type = "long",
		start_dt = -0.5,
		end_dt = -1,
		getState = function() return "clear" end,
		getColumn = function() return "key1" end,
	}
	renderer.game.rhythm_engine = {
		visual_engine = {visible_notes = {note}},
		isColumnPressed = function() return false end,
	}

	local graphics = love.graphics
	local previous = {
		draw = graphics.draw,
		push = graphics.push,
		pop = graphics.pop,
		applyTransform = graphics.applyTransform,
		translate = graphics.translate,
		scale = graphics.scale,
		setColor = graphics.setColor,
		rectangle = graphics.rectangle,
	}
	local draws = {}
	graphics.draw = function(image, ...)
		draws[#draws + 1] = {image = image, args = {...}}
	end
	graphics.push = function() end
	graphics.pop = function() end
	graphics.applyTransform = function() end
	graphics.translate = function() end
	graphics.scale = function() end
	graphics.setColor = function() end
	graphics.rectangle = function() end

	local ok, err = xpcall(function()
		local function draw_and_check(upside_down, expected_body_y, expected_body_sy, expected_tail_y, expected_tail_sy)
			renderer.upside_down = upside_down
			draws = {}
			renderer:draw(640, 480, {})
			local body_draw, tail_draw
			for _, draw in ipairs(draws) do
				if draw.image == images.body then body_draw = draw end
				if draw.image == images.tail then tail_draw = draw end
			end
			t:assert(body_draw, "expected long-note body to draw")
			t:assert(tail_draw, "expected long-note tail to draw")
			t:aeq(body_draw.args[2], expected_body_y, 1e-6)
			t:aeq(body_draw.args[5], expected_body_sy, 1e-6)
			t:aeq(tail_draw.args[2], expected_tail_y, 1e-6)
			t:aeq(tail_draw.args[5], expected_tail_sy, 1e-6)
		end

		draw_and_check(false, -93, 12, -78, -1.5)
		draw_and_check(true, 573, -12, 558, 1.5)
	end, debug.traceback)
	for name, fn in pairs(previous) do graphics[name] = fn end
	renderer:unload()
	if not ok then error(err) end
end

function test.scales_wide_playfields_to_fit_the_640_pixel_skin_canvas(t)
	local renderer = OsuManiaRenderer({fs = FakeFilesystem()}, "18key")
	local left, widths, scale = renderer:getPlayfieldLayout()
	local total = 0
	for _, width in ipairs(widths) do total = total + width end
	t:eq(left, 136)
	t:eq(#widths, 18)
	t:assert(left + total * scale <= 640 - renderer.column_right)
	t:assert(scale < 1)
	renderer:unload()
end

return test
