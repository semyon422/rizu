local class = require("class")
local spherefonts = require("sphere.assets.fonts")
local erfunc = require("chart.scoring.erfunc")
local just = require("just")
local Format = require("sphere.views.Format")

---@class sphere.MatchPlayersView
---@operator call: sphere.MatchPlayersView
local MatchPlayersView = class()

function MatchPlayersView:draw()
	---@type sphere.GameController
	local game = self.game

	local client = game.multiplayerModel.client

	local room_users = client.room_users
	if not room_users then
		return
	end

	---@type sea.RoomUser[]
	local sorted_room_users = {}
	for i, room_user in ipairs(room_users) do
		sorted_room_users[i] = room_user
	end
	table.sort(sorted_room_users, function(a, b)
		return a.chartplay_computed.accuracy < b.chartplay_computed.accuracy
	end)

	love.graphics.setColor(1, 1, 1, 1)
	local font = spherefonts.get("Noto Sans Mono", 24)
	love.graphics.setFont(font)

	for i, room_user in ipairs(sorted_room_users) do
		local score = room_user.chartplay_computed
		local user = client:getUser(room_user.user_id)
		local user_name = user and user.name or "unknown"

		local twidth = 300
		local theight = font:getHeight() * 2

		love.graphics.setColor(0, 0, 0, 0.5)
		love.graphics.rectangle("fill", 0, 0, twidth, theight, theight / 6)
		love.graphics.setColor(1, 1, 1, 0.5)
		love.graphics.rectangle("line", 0, 0, twidth, theight, theight / 6)

		love.graphics.setColor(1, 1, 1, 1)
		just.text(("#%d: %s"):format(i, user_name))
		just.text(("%5d, %s"):format(score.miss_count, Format.accuracy(score.accuracy)))
		if score.failed then
			just.sameline()
			just.text(" failed")
		end
		just.emptyline(theight / 4)
	end
end

return MatchPlayersView
