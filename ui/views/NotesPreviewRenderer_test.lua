local NotesPreviewRenderer = require("ui.views.NotesPreviewRenderer")
local NotesPreview = require("rizu.preview.NotesPreview")
local SphPreview = require("chart.format.sph.SphPreview")
local Resources = require("ui.Resources")
local Painter = require("gui.Painter")

local test = {}

---@param t testing.T
function test.draw_crossing_hold_and_backward_seek(t)
	local preview = NotesPreview(SphPreview:encode({
		{offset = 0, notes = {true}},
		{offset = 2, notes = {false}},
	}), 2)
	local player = {notes = preview, column_map = {2, 1}, time = 1, rate = 1}
	local sprites, color = Resources.sprites, Painter.setColorRgb
	local draws = {}
	Resources.sprites = {pixel = {draw = function(_, x, y, rotation, w, h)
		draws[#draws + 1] = {x, y, w, h}
	end}}
	Painter.setColorRgb = function(r, g, b)
		t:eq(r, 1)
		t:eq(g, 1)
		t:eq(b, 1)
	end
	local ok, err = pcall(function()
		local renderer = NotesPreviewRenderer()
		renderer:draw(player, 400, 200)
		-- Only the hold body and head; no field decorations.
		t:eq(#draws, 2)
		local body = draws[1]
		t:eq(body[1], 200)
		t:eq(body[2], 0)
		t:eq(body[3], 20)
		t:eq(body[4], 200)
		t:eq(draws[2][1], 200)
		t:eq(draws[2][2], 190)
		t:eq(draws[2][3], 20)
		t:eq(draws[2][4], 10)
		draws = {}
		player.time = 3
		renderer:draw(player, 400, 200)
		t:eq(#draws, 0)
		draws = {}
		player.time = 0.5
		renderer:draw(player, 400, 200)
		t:eq(#draws, 2)
	end)
	Resources.sprites, Painter.setColorRgb = sprites, color
	assert(ok, err)
end

---@param t testing.T
function test.notes_enter_top_progressively(t)
	local preview = NotesPreview(SphPreview:encode({
		{offset = 0},
		{offset = 1, notes = {true, true}},
		{offset = 2, notes = {nil, false}},
	}), 2)
	local player = {notes = preview, column_map = {1, 2}, time = 0, rate = 1}
	local sprites, color = Resources.sprites, Painter.setColorRgb
	local draws = {}
	Resources.sprites = {pixel = {draw = function(_, x, y, rotation, w, h)
		draws[#draws + 1] = {y, h}
	end}}
	Painter.setColorRgb = function() end
	local ok, err = pcall(function()
		local renderer = NotesPreviewRenderer()
		renderer:draw(player, 400, 200)
		t:eq(#draws, 0)
		player.time = 0.025
		renderer:draw(player, 400, 200)
		t:eq(#draws, 3)
		for _, rect in ipairs(draws) do
			t:aeq(rect[1], 0, 0.000001)
			t:aeq(rect[2], 5, 0.000001)
		end
		draws = {}
		player.time = 0.075
		renderer:draw(player, 400, 200)
		t:aeq(draws[1][1], 5, 0.000001)
		t:aeq(draws[1][2], 10, 0.000001)
	end)
	Resources.sprites, Painter.setColorRgb = sprites, color
	assert(ok, err)
end

return test
