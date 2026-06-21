local BaseList = require("yi.views.select.BaseList")
local Resources = require("yi.Resources")
local Colors = require("yi.Colors")
local Painter = require("yi.Painter")
local time_util = require("time_util")

---@class yi.views.select.ScoreList : yi.views.select.BaseList
---@operator call: yi.views.select.ScoreList
local ScoreList = BaseList + {}

---@param score_selector rizu.select.ScoreSelector
function ScoreList:new(score_selector)
	BaseList.new(self)
	self.score_selector = score_selector
	self.is_centered = false
	self.visible_items = 5
	self.gap = 5
	self.batch = love.graphics.newSpriteBatch(Resources.atlas)
	self.text_batch24 = love.graphics.newTextBatch(Resources.getFont("regular", 24)) ---@type love.Text
	self.text_batch16 = love.graphics.newTextBatch(Resources.getFont("regular", 16)) ---@type love.Text
	self.items = {}
end

function ScoreList:load()
	self.width, self.height = self.box:getDimensions()
	BaseList.load(self)
end

local function getColorFromScore(score) -- TODO: Should use Chartplay:getGrade() but idk where to get it
	if score > 9800 then
		return Colors.grade_x
	elseif score > 8000 then
		return Colors.grade_s
	elseif score > 7000 then
		return Colors.grade_a
	elseif score > 6000 then
		return Colors.grade_b
	elseif score > 5000 then
		return Colors.grade_c
	end

	return Colors.grade_d
end

function ScoreList:reload()
	self.items = {}

	for i, v in ipairs(self.score_selector.store.items) do
		local mods_sb = {}

		if v.const then
			table.insert(mods_sb, "Const")
		end

		if v.rate and v.rate ~= 1 then
			table.insert(mods_sb, ("%0.02fx"):format(v.rate))
		end

		if v.pause_count and v.pause_count > 0 then
			table.insert(mods_sb, "Pauses")
		end

		table.insert(self.items, {
			label = ("#%i Username"):format(i),
			accuracy = ("%0.02f%%"):format((v.score or 0) / 100),
			time_ago = time_util.time_ago_in_words(v.created_at or 0),
			mods = table.concat(mods_sb, " "),
			color = getColorFromScore(v.score or 0),
			empty = false
		})
		--modifiers
	end

	if #self.items < self.visible_items then
		local diff = math.max(0, self.visible_items - #self.items)
		for _ = 1, diff do
			table.insert(self.items, {empty = true})
		end
	end
end

function ScoreList:getItem(index)
	return self.items[index]
end

function ScoreList:getSelectedIndex()
	return 1
end

function ScoreList:resetBatches()
	self.batch:clear()
	self.text_batch24:clear()
	self.text_batch16:clear()
end

local cs = {Colors.text, ""}

function ScoreList:addToBatch(item, index, y, is_selected)
	self.batch:setColor(Colors.panel[1], Colors.panel[2], Colors.panel[3], 1)
	self.batch:add(Resources.quads.pixel, 0, y, 0, self.box.width, self.item_height)

	if item.empty then
		return
	end

	self.batch:setColor(item.color[1], item.color[2], item.color[3], 1)
	self.batch:add(Resources.quads.score_grade_gradient, 0, y)

	self.batch:setColor(1, 1, 1, 1)
	self.batch:add(Resources.quads.avatar, 6, y + 6)

	self.text_batch24:add(item.label, 87, y + 23)

	cs[1] = item.color
	cs[2] = item.accuracy
	self.text_batch24:addf(cs, self.box.width, "right", -17, y + 12)

	cs[1] = Colors.text_muted
	cs[2] = item.time_ago
	self.text_batch16:addf(cs, self.box.width, "right", -17, y + 43)

	cs[1] = Colors.text
	cs[2] = item.mods
	self.text_batch16:addf(cs, self.box.width - 100, "right", -17, y + 43)
end

local lg = love.graphics

function ScoreList:draw()
	lg.clear(false, true, false)
	lg.setStencilMode("draw", 1)
	lg.rectangle("fill", 0, 0, self:getDimensions())
	lg.setStencilMode("test")
	lg.draw(self.batch)
	Painter.snapToPixel()
	lg.draw(self.text_batch16)
	lg.draw(self.text_batch24)
	lg.setStencilMode("off")
end

return ScoreList
