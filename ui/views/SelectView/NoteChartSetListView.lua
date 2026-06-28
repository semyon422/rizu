local ListView = require("sphere.views.ListView")
local just = require("just")
local TextCellImView = require("ui.imviews.TextCellImView")

local NoteChartSetListView = ListView()

NoteChartSetListView.rows = 11

function NoteChartSetListView:reloadItems()
	local chartSetStore = self.game.chartSelector.stores[1]
	if not self.isSubscribed then
		chartSetStore:onChanged(self)
		self.isSubscribed = true
		self.items = chartSetStore
		self.refreshNeeded = true
	end

	if self.refreshNeeded then
		self.stateCounter = (self.stateCounter or 0) + 1
		self.refreshNeeded = false
	end
end

function NoteChartSetListView:receive()
	self.refreshNeeded = true
end

---@return number
function NoteChartSetListView:getItemIndex()
	return self.game.chartSelector.state.levels[1].index
end

---@param count number
function NoteChartSetListView:scroll(count)
	self.game.chartSelector:scrollLevel(1, count)
end

---@param ... any?
function NoteChartSetListView:draw(...)
	ListView.draw(self, ...)

	local kp = just.keypressed
	if kp("left") then self:scroll(-1)
	elseif kp("right") then self:scroll(1)
	elseif kp("pageup") then self:scroll(-10)
	elseif kp("pagedown") then self:scroll(10)
	elseif kp("home") then self:scroll(-math.huge)
	elseif kp("end") then self:scroll(math.huge)
	end
end

---@param i number
---@param w number
---@param h number
function NoteChartSetListView:drawItem(i, w, h)
	local item = self:get(i)

	if item.difftable_chartmetas and #item.difftable_chartmetas > 0 then
		love.graphics.circle("line", w - 22 * 2, 36, 5, 16)
	end

	if item.lamp then
		love.graphics.circle("fill", 22, 36, 7)
		love.graphics.circle("line", 22, 36, 7)
	end

	local artist = item.artist or ""
	local title = item.title or item.set_name

	just.indent(44)
	TextCellImView(math.huge, h, "left", artist, title)
end

return NoteChartSetListView
