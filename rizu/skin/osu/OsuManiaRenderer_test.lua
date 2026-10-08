local FakeFilesystem = require("fs.FakeFilesystem")
local OsuSpriteBatch = require("rizu.skin.osu.OsuSpriteBatch")
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
					StageHint = "Mania\\stage-custom", StageUnderKeys = "0",
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
	t:eq(renderer.stage_under_keys, false)
	t:eq(renderer.score_view.score_prefix, "digits")
	t:eq(renderer.score_view.score_overlap, 1)
	local assets = renderer:getSkinAssets()
	local asset_names = {}
	for _, asset in ipairs(assets) do
		asset_names[asset.name or asset.fallback] = asset
	end
	t:assert(asset_names["Mania\\key-custom"])
	t:assert(asset_names["Mania\\note-custom"])
	t:assert(asset_names["Mania\\stage-custom"])
	t:assert(asset_names["mania-note1L"].animation)
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

function test.special_style_reorders_scratch_inputs_without_changing_columns(t)
	local function create_renderer(input_mode, special_style)
		local skin = {
			path = "skins/special-style-" .. input_mode .. "-" .. special_style,
			files = {}, skin_ini = {Mania = {{Keys = input_mode == "7key1scratch" and "8" or "16",
				SpecialStyle = tostring(special_style)}}},
		}
		local game = {
			fs = FakeFilesystem(),
			settings = {getStringMap = function() return {['osu/1osu'] = skin.path} end},
		skinRegistry = {
				getOsuSkin = function(_, path) return path == skin.path and skin end,
				getOsuSkins = function() return {skin} end,
			},
		}
		return OsuManiaRenderer(game, input_mode)
	end

	local left = create_renderer("7key1scratch", 1)
	t:eq(left.inputs[1], "scratch1")
	t:eq(left.input_map.scratch1, 1)
	t:eq(left:getColumnSuffix(0), "S")
	left:unload()

	local right = create_renderer("7key1scratch", 2)
	t:eq(right.inputs[8], "scratch1")
	t:eq(right.input_map.scratch1, 8)
	t:eq(right:getColumnSuffix(7), "S")
	right:unload()

	local outer = create_renderer("14key2scratch", 1)
	t:eq(outer.inputs[1], "scratch1")
	t:eq(outer.inputs[16], "scratch2")
	t:eq(outer.input_map.scratch1, 1)
	t:eq(outer.input_map.scratch2, 16)
	t:eq(outer:getColumnSuffix(0), "S")
	t:eq(outer:getColumnSuffix(15), "S")
	outer:unload()

	local center = create_renderer("14key2scratch", 2)
	t:eq(center.inputs[8], "scratch1")
	t:eq(center.inputs[9], "scratch2")
	t:eq(center.input_map.scratch1, 8)
	t:eq(center.input_map.scratch2, 9)
	t:eq(center:getColumnSuffix(7), "S")
	t:eq(center:getColumnSuffix(8), "S")
	center:unload()
end
function test.uses_separate_conveyor_hud_for_conveyor_anchored_views(t)
	local renderer = OsuManiaRenderer({fs = FakeFilesystem()}, "4key")
	t:eq(renderer.foreground_hud.children[1], renderer.score_view)
	t:eq(renderer.foreground_hud.children[2], renderer.accuracy_view)
	t:eq(renderer.foreground_hud.children[3], renderer.progress_view)
	t:eq(renderer.conveyor_hud.children[1], renderer.combo_view)
	t:eq(renderer.conveyor_hud.children[2], renderer.judge_view)
	t:eq(renderer.conveyor_hud.children[3], renderer.hit_meter_view)
	t:eq(renderer.combo_view.anchor, "top")
	t:eq(renderer.judge_view.anchor, "top")
	t:eq(renderer.hit_meter_view.anchor, "bottom")
	renderer:unload()
end

function test.column_anchor_width_includes_stage_separation(t)
	local renderer = OsuManiaRenderer({fs = FakeFilesystem()}, "4key")
	renderer.column_widths = {40, 50, 60, 70}
	renderer.column_spacings = {3, 4, 5}
	renderer.split_stages = true
	renderer.stage_separation = 40
	local left, _, scale, column_width = renderer:getPlayfieldLayout()
	t:eq(left, 136)
	t:eq(scale, 1)
	t:eq(column_width, 268)
	renderer:unload()
end

function test.draws_conveyor_hud_over_the_complete_column_span(t)
	local renderer = OsuManiaRenderer({fs = FakeFilesystem()}, "4key")
	renderer.column_widths = {40, 50, 60, 70}
	renderer.column_spacings = {3, 4, 5}
	renderer.split_stages = false
	local received_width, received_height, received_transform
	renderer.foreground_hud.draw = function() end
	renderer.conveyor_hud.draw = function(_, width, height, transform)
		received_width, received_height, received_transform = width, height, transform
	end
	local viewport_transform = love.math.newTransform()
	viewport_transform:translate(5, 7)
	renderer:drawHud(1280, 720, viewport_transform)
	t:eq(received_width, 232)
	t:eq(received_height, 480)
	local x, y = received_transform:transformPoint(0, 0)
	t:aeq(x, 209, 1e-6)
	t:aeq(y, 7, 1e-6)
	x, y = received_transform:transformPoint(232, 480)
	t:aeq(x, 557, 1e-6)
	t:aeq(y, 727, 1e-6)
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
		batch = OsuSpriteBatch(),
		skin = skin,
		loaded = true,
		setFallbackArchive = function() end,
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

function test.preview_long_note_draws_hold_head_body_and_tail(t)
	local renderer = OsuManiaRenderer({fs = FakeFilesystem()}, "4key")
	local images = {
		body = {getDimensions = function() return 20, 20 end},
		head = {getDimensions = function() return 20, 20 end},
		tail = {getDimensions = function() return 20, 20 end},
	}
	renderer.skin_graphics = {
		batch = OsuSpriteBatch(),
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
	local preview = {
		columns = {{{time = 0.2, end_time = 0.9}}, {}, {}, {}},
		getVisibleRange = function() return 1, 1 end,
	}
	local graphics = love.graphics
	local previous = {
		draw = graphics.draw,
		push = graphics.push,
		pop = graphics.pop,
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
	graphics.translate = function() end
	graphics.scale = function() end
	graphics.setColor = function() end
	graphics.rectangle = function() end

	local ok, err = xpcall(function()
		renderer:drawPreview({notes = preview, input_mode = "4key", time = 0, rate = 1}, 640, 480)
		local seen = {}
		for _, draw in ipairs(draws) do seen[draw.image] = true end
		t:assert(seen[images.body], "expected hold body to draw in preview")
		t:assert(seen[images.head], "expected hold head to draw in preview")
		t:assert(seen[images.tail], "expected hold tail to draw in preview")
	end, debug.traceback)
	for name, fn in pairs(previous) do graphics[name] = fn end
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
		batch = OsuSpriteBatch(),
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
	renderer.score_view.draw = function() end
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

function test.long_note_body_uses_the_selected_animation_frame(t)
	local renderer = OsuManiaRenderer({fs = FakeFilesystem()}, "4key")
	local images = {
		body_first = {getDimensions = function() return 20, 20 end},
		body_second = {getDimensions = function() return 20, 20 end},
		head = {getDimensions = function() return 20, 20 end},
		tail = {getDimensions = function() return 20, 20 end},
	}
	renderer.skin_graphics = {
		batch = OsuSpriteBatch(),
		unload = function() end,
		getFrames = function(_, name)
			local image = name == "mania-note1H" and images.head
				or name == "mania-note1T" and images.tail
			return image and {image} or {}
		end,
		getAnimationFrames = function(_, name)
			return name == "mania-note1L" and {images.body_first, images.body_second} or {}
		end,
	}
	local note = {
		getState = function() return "startPassedPressed" end,
		getPressedTime = function() return 0 end,
		visual_info = {getTime = function() return 0.031 end},
	}
	t:eq(renderer:getNoteBodyFrame(note, 2), 2)

	local previous_draw = love.graphics.draw
	local drawn_images = {}
	love.graphics.draw = function(image) drawn_images[#drawn_images + 1] = image end
	local ok, err = xpcall(function()
		renderer.note_renderer:draw(renderer, {{
			column = 1, long_note = true, head_y = 100, tail_y = 200,
			body_visible = true, body_frame = 2, head_visible = false,
		}}, {30, 30, 30, 30}, {15, 45, 75, 105})
	end, debug.traceback)
	love.graphics.draw = previous_draw
	renderer:unload()
	if not ok then error(err) end
	t:eq(drawn_images[1], images.body_second)
end

function test.draws_stage_before_keys(t)
	local renderer = OsuManiaRenderer({fs = FakeFilesystem()}, "4key")
	renderer.load = function() end
	renderer.game.rhythm_engine = {visual_engine = {visible_notes = {}}, isColumnPressed = function() return false end}
	local events = {}
	renderer.field_renderer.drawBackground = function() end
	renderer.field_renderer.drawLanes = function() end
	renderer.field_renderer.drawGuides = function() end
	renderer.stage_renderer.draw = function() events[#events + 1] = "stage" end
	renderer.note_renderer.draw = function() events[#events + 1] = "notes" end
	renderer.key_renderer.draw = function() events[#events + 1] = "keys" end
	local graphics = love.graphics
	local previous = {push = graphics.push, pop = graphics.pop, applyTransform = graphics.applyTransform,
		translate = graphics.translate, scale = graphics.scale}
	graphics.push = function() end
	graphics.pop = function() end
	graphics.applyTransform = function() end
	graphics.translate = function() end
	graphics.scale = function() end
	local ok, err = pcall(function() renderer:draw(640, 480, {}) end)
	for name, fn in pairs(previous) do graphics[name] = fn end
	renderer:unload()
	if not ok then error(err) end
	t:tdeq(events, {"stage", "notes", "keys"})
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

function test.renderer_updates_each_playfield_component(t)
	local renderer = OsuManiaRenderer({fs = FakeFilesystem()}, "4key")
	local hud_updates = 0
	renderer.foreground_hud.update = function() hud_updates = hud_updates + 1 end
	renderer.conveyor_hud.update = function() hud_updates = hud_updates + 1 end
	renderer:updateHud(0.25)
	t:eq(hud_updates, 2)

	local updated = {}
	for _, component in ipairs({
		renderer.field_renderer,
		renderer.key_renderer,
		renderer.note_renderer,
		renderer.stage_renderer,
	}) do
		component.update = function(_, dt)
			updated[#updated + 1] = dt
		end
	end

	renderer:update(0.25)
	t:eq(#updated, 4)
	for _, dt in ipairs(updated) do t:eq(dt, 0.25) end
	renderer:unload()
end

---@param t testing.T
function test.loads_bundled_fallback_assets(t)
	local renderer = OsuManiaRenderer({fs = FakeFilesystem()}, "4key")
	local previous_new_image = love.graphics.newImage
	local previous_new_quad = love.graphics.newQuad
	local previous_new_batch = love.graphics.newSpriteBatch
	love.graphics.newSpriteBatch = function()
		return {release = function() end}
	end
	love.graphics.newQuad = function(x, y, width, height)
		return {getViewport = function() return x, y, width, height end, release = function() end}
	end
	love.graphics.newImage = function(data, settings)
		local width, height = data:getDimensions()
		local density = settings and settings.dpiscale or 1
		width, height = width / density, height / density
		return {
			getWidth = function() return width end,
			getHeight = function() return height end,
			getDimensions = function() return width, height end,
			setWrap = function() end,
			release = function() end,
		}
	end
	local ok, err = xpcall(function()
		renderer:load()
		local graphics = renderer.skin_graphics
		t:eq(graphics.fallback_archive, "resources/osu_default_assets.zip")
		for _, name in ipairs({"mania-key1", "mania-key2D", "mania-note1", "mania-note1L",
			"mania-note2T", "mania-stage-left", "mania-stage-hint", "score-0", "score-percent",
			"circularmetre", "editor-rate-arrow"}) do
			local group = name == "circularmetre" and "standalone"
				or name == "editor-rate-arrow" and "standalone"
				or name:match("^score") and "font"
				or name:match("^mania%-stage%-left") and "standalone" or "playfield"
			local image = graphics:getFrames(name, nil, group)[1]
			t:assert(image, name)
			if group == "standalone" then
				t:eq(image.texture, nil, name)
			else
				t:eq(graphics:getImageDensity(image), 2)
			end
		end
		t:assert(graphics:getAnimationFrames("mania-hit300g", nil, "playfield")[1])
		t:assert(renderer.score_view.height > 0)
		renderer:unload()
		renderer:load()
		t:assert(graphics:getFrames("mania-key1", nil, "playfield")[1])
	end, debug.traceback)
	love.graphics.newImage = previous_new_image
	love.graphics.newQuad = previous_new_quad
	love.graphics.newSpriteBatch = previous_new_batch
	renderer:unload()
	if not ok then error(err) end
end

return test
