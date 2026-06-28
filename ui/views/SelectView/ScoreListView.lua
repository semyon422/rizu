local ListView = require("sphere.views.ListView")
local just = require("just")
local TextCellImView = require("ui.imviews.TextCellImView")
local Format = require("sphere.views.Format")
local time_util = require("time_util")

local ScoreListView = ListView()

ScoreListView.rows = 5

function ScoreListView:reloadItems()
	local scoreStore = self.game.scoreSelector.store
	if not self.isSubscribed then
		scoreStore:onChanged(self)
		self.isSubscribed = true
		self.items = scoreStore
		self.refreshNeeded = true
	end

	if self.refreshNeeded then
		self.stateCounter = (self.stateCounter or 0) + 1
		self.refreshNeeded = false
	end
end

function ScoreListView:receive()
	self.refreshNeeded = true
end

---@return number
function ScoreListView:getItemIndex()
	return self.game.scoreSelector.state.chartplayIndex
end

---@param delta number
function ScoreListView:scroll(delta)
	self.game.scoreSelector:scrollScore(delta)
end

---@param i number
---@param w number
---@param h number
function ScoreListView:drawItem(i, w, h)
	local item = self:get(i)
	w = (w - 44) / 5

	local time = item.created_at or 0

	local sea_client = self.game.seaClient
	local user = sea_client.client:getUser()
	local username = user and user.name or "username"

	just.row(true)
	just.indent(22)
	TextCellImView(w * 2.25, h, "right", time ~= 0 and time_util.time_ago_in_words(time) or "never", item.user_name or username)
	TextCellImView(w / 2, h, "right", i == 1 and "rank" or "", i)
	TextCellImView(w * 0.75, h, "right", i == 1 and "rating" or "", Format.difficulty(item.rating))
	if just.mouse_over(i .. "pr", just.is_over(-w * 0.75, h), "mouse") then
		self.game.ui.gameView.tooltip = ("%dpp, %0.2fmsd"):format(item.rating_pp or 0, item.rating_msd or 0)
	end
	TextCellImView(w * 0.75, h, "right", i == 1 and "rate" or "", Format.timeRate(item.rate))
	if just.mouse_over(i .. "a", just.is_over(-w * 0.75, h), "mouse") then
		self.game.ui.gameView.tooltip = ("%0.2fX"):format(item.rate)
	end
	TextCellImView(w * 0.75, h, "right", i == 1 and "keys" or "", Format.inputMode(item.inputmode))
	if just.mouse_over(i .. "b", just.is_over(-w * 0.75, h), "mouse") then
		self.game.ui.gameView.tooltip = os.date("%c", time)
	end
	just.row()
end

return ScoreListView
