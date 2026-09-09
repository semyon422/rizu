local class = require("class")
local Resources = require("ui.Resources")
local Painter = require("gui.Painter")

---@class ui.views.NotesPreviewRenderer
---@operator call: ui.views.NotesPreviewRenderer
local NotesPreviewRenderer = class()

---@param player rizu.preview.NotesPreviewPlayer
---@param width number
---@param height number
function NotesPreviewRenderer:draw(player, width, height)
	local preview = player.notes
	if not preview then return end
	local count = #preview.columns
	local lane = height * 48 / 480
	local note_height = height * 24 / 480
	local field_width = count * lane
	local left = (width - field_width) / 2
	local top, bottom = 0, height
	local pixels_per_second = (bottom - top) * math.max(player.rate, 0.01)
	local time = player.time
	local until_time = time + (bottom - top) / pixels_per_second
	local pixel = Resources.sprites.pixel
	for column, notes in ipairs(preview.columns) do
		local display_column = player.column_map[column]
		local x = left + (display_column - 1) * lane
		local first, last = preview:getVisibleRange(column, time, until_time)
		for i = first, last do
			local note = notes[i]
			if note.end_time >= time then
				local head = math.min(bottom, bottom - (note.time - time) * pixels_per_second)
				local tail = math.max(top, bottom - (note.end_time - time) * pixels_per_second)
				if note.end_time > note.time and head > tail then
					Painter.setColorRgb(1, 1, 1, 0.5)
					pixel:draw(x, tail, 0, lane, head - tail)
				end
				local head_top = math.max(top, head - note_height)
				local head_height = head - head_top
				if head_height > 0 then
					Painter.setColorRgb(1, 1, 1, 1)
					pixel:draw(x, head_top, 0, lane, head_height)
				end
			end
		end
	end
	Painter.setColorRgb(1, 1, 1, 1)
end

return NotesPreviewRenderer
