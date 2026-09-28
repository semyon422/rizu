local class = require("class")

---@class rizu.skin.easy_lua.Note.HoldStyle
---@field head love.Image?
---@field head_scale_x number? Optional horizontal scale for the long-note head.
---@field head_scale_y number? Optional vertical scale for the long-note head.
---@field body love.Image?
---@field body_scale_x number?
---@field body_scale_y number? Body scale_y; defaults to the note scale_y.
---@field body_fit_duration boolean? Explicitly stretch the body to the note duration.
---@field tail love.Image?
---@field tail_scale_x number? Optional horizontal scale for the long-note tail.
---@field tail_scale_y number? Optional vertical scale for the long-note tail.

---@class rizu.skin.easy_lua.Note.Config
---@field image love.Image? Image used for short notes and default long-note head/tail.
---@field scale_x number? Sprite scale; defaults to 1 and is independent of column width.
---@field scale_y number? Sprite scale; defaults to 1.
---@field offset_x number? Sprite offset from its column center; defaults to 0.
---@field offset_y number? Sprite offset from its visual note position; defaults to 0.
---@field color number[]? Optional RGBA tint.
---@field hold rizu.skin.easy_lua.Note.HoldStyle? Optional long-note body/head/tail artwork.

---@class rizu.skin.easy_lua.Note.VisualNote : rizu.VisualNote
---@field start_dt number Visual-time delta to the note head, in seconds.
---@field end_dt number? Visual-time delta to the long-note tail, in seconds.

---@class rizu.skin.easy_lua.Note
---@operator call: rizu.skin.easy_lua.Note
---@field image love.Image?
---@field scale_x number
---@field scale_y number
---@field offset_x number
---@field offset_y number
---@field color number[]
---@field hold rizu.skin.easy_lua.Note.HoldStyle?
local Note = class()

---@param config rizu.skin.easy_lua.Note.Config?
function Note:new(config)
	config = config or {}
	self.image = config.image
	self.scale_x = config.scale_x or 1
	self.scale_y = config.scale_y or 1
	self.offset_x = config.offset_x or 0
	self.offset_y = config.offset_y or 0
	self.color = config.color or {1, 1, 1, 1}
	self.hold = config.hold

	assert(self.scale_x == self.scale_x and math.abs(self.scale_x) < math.huge,
		"note scale_x must be finite")
	assert(self.scale_y == self.scale_y and math.abs(self.scale_y) < math.huge,
		"note scale_y must be finite")
	assert(self.offset_x == self.offset_x and math.abs(self.offset_x) < math.huge,
		"note offset_x must be finite")
	assert(self.offset_y == self.offset_y and math.abs(self.offset_y) < math.huge,
		"note offset_y must be finite")
	assert(type(self.color) == "table", "note color must be an RGBA table")
	assert(self.hold == nil or type(self.hold) == "table", "note hold style must be a table")
end

---@param image love.Image?
---@param x number
---@param y number
---@param scale_x number
---@param scale_y number
---@param color number[]
---@param left number
---@param right number
---@param viewport_height number
local function draw_image(image, x, y, scale_x, scale_y, color, left, right, viewport_height)
	if not image or scale_x == 0 or scale_y == 0 then return end
	local width, height = image:getDimensions()
	local half_width = width * math.abs(scale_x) / 2
	local half_height = height * math.abs(scale_y) / 2
	if x + half_width < left or x - half_width > right
		or y + half_height < 0 or y - half_height > viewport_height
	then
		return
	end
	love.graphics.setColor(color[1], color[2], color[3], color[4] or 1)
	love.graphics.draw(image, x, y, 0, scale_x, scale_y, width / 2, height / 2)
end

---Draws visible notes matching one input without allocating per-note objects.
---@param visible_notes rizu.VisualNote[]
---@param input chart.Column
---@param column_x number
---@param hit_y number
---@param pixels_per_second number
---@param reverse boolean
---@param left number
---@param right number
---@param viewport_height number
function Note:draw(visible_notes, input, column_x, hit_y, pixels_per_second, reverse, left, right, viewport_height)
	for i = 1, #visible_notes do
		local visual_note = visible_notes[i]
		---@cast visual_note rizu.skin.easy_lua.Note.VisualNote
		if visual_note:getColumn() == input then
			self:drawNote(visual_note, column_x, hit_y, pixels_per_second, reverse, left, right, viewport_height)
		end
	end
end

---@param visual_note rizu.skin.easy_lua.Note.VisualNote
---@param column_x number
---@param hit_y number
---@param pixels_per_second number
---@param reverse boolean
---@param left number
---@param right number
---@param viewport_height number
function Note:drawNote(visual_note, column_x, hit_y, pixels_per_second, reverse, left, right, viewport_height)
	local state = visual_note:getState()
	local is_long = visual_note.type == "long"
	local head_visible = is_long and not state:find("^end") or not is_long and state == "clear"
	local long_note_visible = is_long and state ~= "endPassed"
	if not head_visible and not long_note_visible then return end

	local direction = reverse and -1 or 1
	local x = column_x + self.offset_x
	local image = self.image
	local scale_x = self.scale_x
	local scale_y = self.scale_y
	local color = self.color
	local hold = self.hold
	local start_y = hit_y + direction * visual_note.start_dt * pixels_per_second + self.offset_y
	if is_long and state == "startPassedPressed" then
		start_y = hit_y + self.offset_y
	end
	if is_long then
		local end_y = hit_y + direction * visual_note.end_dt * pixels_per_second + self.offset_y
		if long_note_visible and hold and hold.body then
			local _, body_height = hold.body:getDimensions()
			local body_scale_x = hold.body_scale_x or scale_x
			local body_scale_y = hold.body_scale_y or scale_y
			if hold.body_fit_duration then
				body_scale_y = body_height > 0 and math.abs(end_y - start_y) / body_height or 0
			end
			draw_image(hold.body, x, (start_y + end_y) / 2, body_scale_x, body_scale_y,
				color, left, right, viewport_height)
		end
		if head_visible then
			draw_image(hold and hold.head or image, x, start_y,
				hold and hold.head_scale_x or scale_x, hold and hold.head_scale_y or scale_y,
				color, left, right, viewport_height)
		end
		if long_note_visible then
			draw_image(hold and hold.tail or image, x, end_y,
				hold and hold.tail_scale_x or scale_x, hold and hold.tail_scale_y or scale_y,
				color, left, right, viewport_height)
		end
	elseif head_visible then
		draw_image(image, x, start_y, scale_x, scale_y, color, left, right, viewport_height)
	end
end

---@param dt number
function Note:update(dt) end

return Note
