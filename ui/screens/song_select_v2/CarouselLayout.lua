local class = require("class")

---@class ui.screens.song_select_v2.CarouselLayout.Group
---@field index integer Set row the charts hang under.
---@field count integer
---@field progress number 0 is fully closed, 1 is fully open.
---@field target number 0 or 1.
---@field items table<integer, any> Chart rows seen while open, so a closing group can still draw them.
---@field frozen number Row spacing a closing group keeps while it fades out.
---@field alpha number Opacity a closing group started fading from.
---@field close_t number Fade-out progress of a closing group, 0 to 1.

---Positions set rows with chart rows unfolded under some of them.
---Every group animates on its own, so a closing set and an opening set can overlap in time.
---@class ui.screens.song_select_v2.CarouselLayout
---@operator call: ui.screens.song_select_v2.CarouselLayout
---@field set_count integer
---@field groups ui.screens.song_select_v2.CarouselLayout.Group[] Sorted by index.
local CarouselLayout = class()

-- The damped motion and the fade of closing rows are taken from osu!lazer's carousel
-- (Carousel.cs: DampContinuously for panel positions, expirePanel for closing ones).
-- Seconds for the remaining distance to halve.
CarouselLayout.OPEN_HALF_LIFE = 0.06
-- The owner has to set this to the half-life of its own scrolling. The camera follows a set that
-- a closing group above it pulls up, and the two motions only cancel out when they decay alike.
CarouselLayout.CLOSE_HALF_LIFE = 0.07
-- Seconds a closing group's rows take to fade out.
CarouselLayout.FADE_TIME = 0.15
-- Pixels left at which a damped animation snaps to its end.
local SNAP = 0.5

---@param set_height number
---@param set_gap number
---@param child_height number
---@param child_gap number
function CarouselLayout:new(set_height, set_gap, child_height, child_gap)
	self.set_height = set_height
	self.set_step = set_height + set_gap
	self.set_gap = set_gap
	self.child_height = child_height
	self.child_step = child_height + child_gap
	self.set_count = 0
	self.groups = {}
end

---@param count integer
function CarouselLayout:setSetCount(count)
	self.set_count = count
end

---Drops every group without animating, for when the set list itself was replaced.
function CarouselLayout:reset()
	self.groups = {}
end

---@private
---@param index integer
---@return ui.screens.song_select_v2.CarouselLayout.Group?
function CarouselLayout:find(index)
	for _, g in ipairs(self.groups) do
		if g.index == index then
			return g
		end
	end
end

---Opens the group under `index` and closes all the others.
---@param index integer
---@param count integer
function CarouselLayout:expand(index, count)
	local group = self:find(index)
	if not group then
		group = {index = index, count = count, progress = 0, target = 1, items = {}, frozen = 0, alpha = 0, close_t = 0}
		table.insert(self.groups, group)
		table.sort(self.groups, function(a, b) return a.index < b.index end)
	end
	group.count = count
	group.target = 1
	for _, g in ipairs(self.groups) do
		if g ~= group then
			self:close(g)
		end
	end
end

function CarouselLayout:collapse()
	for _, g in ipairs(self.groups) do
		self:close(g)
	end
end

---The rows of a closing group stay where they are and fade out, while the sets below close up.
---@private
---@param g ui.screens.song_select_v2.CarouselLayout.Group
function CarouselLayout:close(g)
	if g.target == 0 then
		return
	end
	g.target = 0
	g.frozen = g.progress
	g.alpha = g.progress
	g.close_t = 0
end

---@param dt number
function CarouselLayout:update(dt)
	local groups = self.groups
	for i = #groups, 1, -1 do
		local g = groups[i]
		local half_life = g.target == 1 and self.OPEN_HALF_LIFE or self.CLOSE_HALF_LIFE
		g.progress = g.target + (g.progress - g.target) * 0.5 ^ (dt / half_life)
		if math.abs(g.progress - g.target) * g.count * self.child_step < SNAP then
			g.progress = g.target
		end
		if g.target == 0 then
			g.close_t = math.min(1, g.close_t + dt / self.FADE_TIME)
		end
		if g.target == 0 and g.progress == 0 and g.close_t == 1 then
			table.remove(groups, i)
		end
	end
end

---@return boolean
function CarouselLayout:isAnimating()
	for _, g in ipairs(self.groups) do
		if g.progress ~= g.target then
			return true
		end
	end
	return false
end

---Open fraction, which sets how much room the group takes.
---@param group ui.screens.song_select_v2.CarouselLayout.Group
---@param final boolean? Use the value the animation is heading to.
---@return number
function CarouselLayout:getOpen(group, final)
	if final then
		return group.target
	end
	return group.progress
end

---Spacing of the chart rows, as a fraction of fully open.
---@private
---@param group ui.screens.song_select_v2.CarouselLayout.Group
---@return number
function CarouselLayout:getSpacing(group)
	return group.target == 1 and group.progress or group.frozen
end

---@private
---@param group ui.screens.song_select_v2.CarouselLayout.Group
---@return number
function CarouselLayout:getAlpha(group)
	if group.target == 1 then
		return group.progress
	end
	return group.alpha * (1 - group.close_t) ^ 5 -- OutQuint, as in lazer.
end
---@private
---@param group ui.screens.song_select_v2.CarouselLayout.Group
---@param final boolean?
---@return number
function CarouselLayout:getExtent(group, final)
	return group.count * self.child_step * self:getOpen(group, final)
end

---@param final boolean?
---@return number
function CarouselLayout:getContentHeight(final)
	if self.set_count == 0 then
		return 0
	end
	local height = self.set_count * self.set_step - self.set_gap
	for _, g in ipairs(self.groups) do
		if g.index <= self.set_count then
			height = height + self:getExtent(g, final)
		end
	end
	return height
end

---@param index integer
---@param final boolean?
---@return number
function CarouselLayout:getSetY(index, final)
	local y = (index - 1) * self.set_step
	for _, g in ipairs(self.groups) do
		if g.index >= index then
			break
		end
		y = y + self:getExtent(g, final)
	end
	return y
end

---Top of chart row `j` once its group is fully open.
---@param group ui.screens.song_select_v2.CarouselLayout.Group
---@param j integer
---@param final boolean?
---@return number
function CarouselLayout:getChildY(group, j, final)
	local open = final and 1 or self:getSpacing(group)
	return self:getSetY(group.index, final) + self.set_step + (j - 1) * self.child_step * open
end

---Calls `on_set(index, y)` for the set rows and `on_child(group, j, y, alpha)` for the chart rows
---that intersect [top, bottom]. Chart rows come last-to-first so earlier rows end up on top.
---@param top number
---@param bottom number
---@param on_set fun(index: integer, y: number)
---@param on_child fun(group: ui.screens.song_select_v2.CarouselLayout.Group, j: integer, y: number, alpha: number)
function CarouselLayout:visit(top, bottom, on_set, on_child)
	local set_step = self.set_step
	local set_count = self.set_count
	local cursor_y, cursor_i = 0, 1

	local function sets(to_i)
		local first = math.max(cursor_i, cursor_i + math.floor((top - cursor_y - self.set_height) / set_step) + 1)
		local last = math.min(to_i, cursor_i + math.floor((bottom - cursor_y) / set_step))
		for i = first, last do
			on_set(i, cursor_y + (i - cursor_i) * set_step)
		end
	end

	for _, g in ipairs(self.groups) do
		if g.index > set_count then
			break
		end
		sets(g.index)
		local base = cursor_y + (g.index - cursor_i + 1) * set_step
		local extent = g.count * self.child_step * self:getOpen(g)
		local alpha = self:getAlpha(g)
		if alpha > 0 then
			local row_step = self.child_step * self:getSpacing(g)
			for j = g.count, 1, -1 do
				local y = base + (j - 1) * row_step
				if y < bottom and y + self.child_height > top then
					on_child(g, j, y, alpha)
				end
			end
		end
		cursor_y = base + extent
		cursor_i = g.index + 1
	end
	sets(set_count)
end

---Finds the row under content position `y`.
---@param y number
---@return "set"|"child"|nil kind
---@return integer? index Set index, or the group's set index for a chart row.
---@return integer? child
function CarouselLayout:locate(y)
	if y < 0 then
		return
	end
	local set_step = self.set_step
	local cursor_y, cursor_i = 0, 1

	local function setAt(from_y, from_i)
		local i = from_i + math.floor((y - from_y) / set_step)
		if i <= self.set_count and (y - from_y) % set_step < self.set_height then
			return "set", i
		end
	end

	for _, g in ipairs(self.groups) do
		if g.index > self.set_count then
			break
		end
		local base = cursor_y + (g.index - cursor_i + 1) * set_step
		if y < base then
			return setAt(cursor_y, cursor_i)
		end
		local open = self:getOpen(g)
		local row_step = self.child_step * open
		if y < base + g.count * row_step then
			for j = 1, g.target == 1 and g.count or 0 do -- closing rows can't be clicked
				local top = base + (j - 1) * row_step
				if y >= top and y < top + self.child_height then
					return "child", g.index, j
				end
			end
			return
		end
		cursor_y = base + g.count * row_step
		cursor_i = g.index + 1
	end
	return setAt(cursor_y, cursor_i)
end

return CarouselLayout
