local just = require("just")
local imgui = require("imgui")
local ModalImView = require("ui.imviews.ModalImView")
local _transform = require("gfx_util").transform
local spherefonts = require("sphere.assets.fonts")
local table_util = require("table_util")

local transform = {{1 / 2, -16 / 9 / 2}, 0, 0, {0, 1 / 1080}, {0, 1 / 1080}, 0, 0, 0, 0}

---@param id any
---@param v number
---@param w number
---@param h number
---@param inactive boolean?
---@return number
local function intButtons(id, v, w, h, inactive)
	local _v = v
	local mod = love.keyboard.isScancodeDown("lshift", "rshift")
	if not mod then
		if imgui.TextButton(id .. "-1", "-1", w / 4, h, inactive) then
			v = v - 1
		end
		if imgui.TextButton(id .. "+1", "+1", w / 4, h, inactive) then
			v = v + 1
		end
	end
	if imgui.TextButton(id .. "-10", "-10", w / 4, h, inactive) then
		v = v - 10
	end
	if imgui.TextButton(id .. "+10", "+10", w / 4, h, inactive) then
		v = v + 10
	end
	if mod then
		if imgui.TextButton(id .. "-100", "-100", w / 4, h, inactive) then
			v = v - 100
		end
		if imgui.TextButton(id .. "+100", "+100", w / 4, h, inactive) then
			v = v + 100
		end
	end
	if v ~= _v then
		return math.floor(v)
	end
	return v
end

---@param id any
---@param v number
---@param w number
---@param h number
---@param inactive boolean?
---@return number
local function intButtonsMs(id, v, w, h, inactive)
	return intButtons(id, v * 1000, w, h, inactive) / 1000
end

---@param t table
---@param name string
---@param id any
---@param norm number
---@param mins table?
---@param w number
---@param h number
---@param inactive boolean?
local function drawTimings(t, name, id, norm, mins, w, h, inactive)
	local min1, min2 = 0, 0
	if mins then
		min1, min2 = mins[1], mins[2]
	end
	just.row(true)
	t[1] = math.min(math.max(intButtonsMs(id .. 1, t[1], w / 4, h, inactive), -1), min1)
	imgui.ValueBar(w / 4, h, -t[1] / norm, name, t[1] * 1000, true)
	imgui.ValueBar(w / 4, h, t[2] / norm, name, t[2] * 1000)
	t[2] = math.min(math.max(intButtonsMs(id .. 2, t[2], w / 4, h, inactive), min2), 1)
	just.row()
end

return ModalImView(function(self, quit)
	if quit then
		return true
	end

	love.graphics.setFont(spherefonts.get("Noto Sans", 24))

	love.graphics.replaceTransform(_transform(transform))
	local w, h = 1080, 680
	love.graphics.translate((1920 - w) / 2, (1080 - h) / 2)
	local r = 8

	love.graphics.setColor(0.1, 0.1, 0.1, 0.8)
	love.graphics.rectangle("fill", 0, 0, w, h, r)
	love.graphics.setColor(1, 1, 1, 1)

	just.clip(love.graphics.rectangle, "fill", 0, 0, w, h, r)

	local window_id = "TimingsModalView"
	local over = just.is_over(w, h)
	just.container(window_id, over)
	just.button(window_id, over)
	just.wheel_over(window_id, over)

	local _w, _h = w / 3, 44
	local _h2 = 55
	local quit = false

	---@type sphere.GameController
	local game = self.game

	local replayBase = game.replayBase

	local timings = replayBase.timing_values

	local maxt = 0
	for _, t in pairs(timings) do
		if type(t) == "table" and t.hit then
			maxt = math.max(maxt, -t.hit[1], t.hit[2], -t.miss[1], t.miss[2])
		end
	end

	local norm = 1
	while norm > maxt and norm / 2 > maxt do
		norm = norm / 2
	end
	while norm < maxt and norm * 2 < maxt do
		norm = norm * 2
	end

	local inactive = replayBase.timings.name ~= "arbitrary"

	just.indent(10)
	just.text("short note")

	drawTimings(timings.ShortNote.hit, "hit", "sn hit", norm, nil, w, _h, inactive)
	drawTimings(timings.ShortNote.miss, "miss", "sn miss", norm, timings.ShortNote.hit, w, _h, inactive)

	just.emptyline(20)
	just.indent(10)
	just.text("long note start")
	drawTimings(timings.LongNoteStart.hit, "hit", "lns hit", norm, nil, w, _h, inactive)
	drawTimings(timings.LongNoteStart.miss, "miss", "lns miss", norm, timings.LongNoteStart.hit, w, _h, inactive)

	just.emptyline(20)
	just.indent(10)
	just.text("long note end")
	drawTimings(timings.LongNoteEnd.hit, "hit", "lne hit", norm, nil, w, _h, inactive)
	drawTimings(timings.LongNoteEnd.miss, "miss", "lne miss", norm, timings.LongNoteEnd.hit, w, _h, inactive)

	just.emptyline(20)
	just.indent(10)
	just.text("hold shift to show +/-100 buttons")

	just.container()
	just.clip()

	love.graphics.setColor(1, 1, 1, 1)
	love.graphics.rectangle("line", 0, 0, w, h, r)

	return quit
end)
