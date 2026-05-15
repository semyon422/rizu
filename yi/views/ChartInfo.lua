local View = require("ui.View")
local Colors = require("yi.Colors")

---@class yi.ChartInfo: ui.View
---@operator call: yi.ChartInfo
local ChartInfo = View + {}

local BOTTOM_KV_GAP = 10
local BOTTOM_VK_GAP = 45

---@param resources yi.Resources
function ChartInfo:new(resources)
	View.new(self)
	local kf = resources:getFont("regular", 24)
	local vf = resources:getFont("regular", 36)
	self.keys = love.graphics.newText(kf)
	self.values = love.graphics.newText(vf)
	self:setHeight(vf:getHeight())
end

local x = 0
local tk_y = 0

---@param tk love.Text
---@param tv love.Text
---@param k string
---@param v string
local function addKV(tk, tv, k, v)
	local i = 0
	i = tk:add(k, x, tk_y)
	x = x + tk:getWidth(i) + BOTTOM_KV_GAP
	i = tv:add(v, x)
	x = x + tv:getWidth(i) + BOTTOM_VK_GAP
end

---@param chartview rizu.library.Chartview
---@param replay_base sea.ReplayBase
function ChartInfo:bind(chartview, replay_base)
	local duration = (chartview.duration or 0) * replay_base.rate
	local notes = chartview.notes_count or 0
	local mode = (chartview.inputmode or "???"):gsub("key", "K")
	local tempo = (chartview.tempo or 0) * replay_base.rate
	local ln = chartview.long_notes_ratio or 0

	local minutes = duration / 60
	local seconds = duration % 60

	local tk = self.keys
	local tv = self.values
	x = 0
	tk_y = (tv:getFont():getHeight() - tk:getFont():getHeight()) / 2
	tk:clear()
	tv:clear()
	addKV(tk, tv, "DURATION", ("%i:%i"):format(minutes, seconds))
	addKV(tk, tv, "NOTES", tostring(notes))
	addKV(tk, tv, "MODE", tostring(mode))
	addKV(tk, tv, "TEMPO", ("%i"):format(tempo))
	addKV(tk, tv, "LN", ("%i%%"):format((ln * 100)))
end

local lg = love.graphics

function ChartInfo:draw()
	lg.setColor(Colors.text_subsection)
	lg.draw(self.keys)
	lg.setColor(Colors.text_label)
	lg.draw(self.values)
end

return ChartInfo
