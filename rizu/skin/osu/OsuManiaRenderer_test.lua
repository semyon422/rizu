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
