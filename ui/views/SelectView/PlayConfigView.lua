local just = require("just")
local int_rates = require("chart.scoring.int_rates")
local imgui = require("imgui")
local ModalImView = require("ui.imviews.ModalImView")
local _transform = require("gfx_util").transform
local spherefonts = require("sphere.assets.fonts")
local Timings = require("sea.chart.Timings")
local Subtimings = require("sea.chart.Subtimings")
local TimingValuesFactory = require("sea.chart.TimingValuesFactory")
local ColumnsOrder = require("sea.chart.ColumnsOrder")
local TimingsSelectorView = require("ui.views.SelectView.TimingsSelectorView")

local transform = {{1 / 2, -16 / 9 / 2}, 0, 0, {0, 1 / 1080}, {0, 1 / 1080}, 0, 0, 0, 0}

local scrollY = 0

local w, h = 792, 792
local _w, _h = w / 2, 55
local r = 8
local window_id = "PlayConfigView"

---@type ncdk2.Column
local swapping_column

return ModalImView(function(self, quit)
	---@type sphere.GameController
	local game = self.game

	local replay_base = game.configModel.configs.settings.replay_base

	if quit then
		game.multiplayerModel.client:updateReplayBase()
		return true
	end

	local state = game.modifierCoordinator.state

	imgui.setSize(w, h, _w, _h)

	love.graphics.setFont(spherefonts.get("Noto Sans", 24))

	love.graphics.replaceTransform(_transform(transform))
	love.graphics.translate((1920 - w) / 2, (1080 - h) / 2)

	love.graphics.setColor(0, 0, 0, 0.8)
	love.graphics.rectangle("fill", 0, 0, w, h, r)
	love.graphics.setColor(1, 1, 1, 1)

	just.push()

	imgui.Container(window_id, w, h, _h / 3, _h * 2, scrollY)

	imgui.text("Auto:")
	just.row(true)
	replay_base.auto_timings = imgui.checkbox("auto_timings", replay_base.auto_timings, "timings")
	-- replay_base.auto_healths = imgui.checkbox("auto_healths", replay_base.auto_healths, "healths")
	-- replay_base.auto_const = imgui.checkbox("auto_const", replay_base.auto_const, "const")
	-- replay_base.auto_tap_only = imgui.checkbox("auto_tap_only", replay_base.auto_tap_only, "tap only")
	just.row(false)

	imgui.separator()

	local replayBase = game.replayBase

	imgui.text(("Mode: %s"):format(replayBase.mode))
	imgui.text(("Modifiers: %d"):format(#replayBase.modifiers))
	imgui.text(("Rate: %0.3f"):format(replayBase.rate))

	local timeRateModel = game.timeRateModel
	local range = timeRateModel.range[replayBase.rate_type]
	local format = timeRateModel.format[replayBase.rate_type]

	local newRate = int_rates.round(imgui.slider1("rate", timeRateModel:get(), format, range[1], range[2], range[3], "play rate"))

	if newRate ~= timeRateModel:get() then
		game.modifierSelectModel:change()
	end
	timeRateModel:set(newRate)

	replayBase.rate_type = imgui.combo("rate_type", replayBase.rate_type, timeRateModel.types, nil, "rate type")

	just.row(true)
	replayBase.nearest = imgui.checkbox("nearest", replayBase.nearest, "nearest")
	replayBase.tap_only = imgui.checkbox("tap_only", replayBase.tap_only, "tap only")
	replayBase.const = imgui.checkbox("const", replayBase.const, "const")
	replayBase.custom = state.custom
	replayBase.custom = imgui.checkbox("custom", replayBase.custom, "custom", true)
	just.row(false)

	imgui.separator()

	TimingsSelectorView(game)

	imgui.separator()

	local co = ColumnsOrder(state.inputMode, replayBase.columns_order)

	imgui.text("Columns order: " .. (co:getName() or "unchanged"))

	just.row(true)
	if imgui.button("order reset", "reset") then
		co:import()
	end
	if imgui.button("order mirror", "mirror") then
		co:mirror()
	end
	if imgui.button("order shift-", "shift-") then
		co:shift(-1)
	end
	if imgui.button("order shift+", "shift+") then
		co:shift(1)
	end
	if imgui.button("order bracketswap", "bracketswap") then
		co:bracketswap()
	end
	if imgui.button("order random", "random") then
		local shift = love.keyboard.isDown("lshift")
		local ctrl = love.keyboard.isDown("lctrl")
		co:random(shift and "left" or ctrl and "right")
	end
	just.row(false)

	if not co.map[swapping_column] then
		swapping_column = nil
	end

	just.row(true)
	local inputs = state.inputMode:getInputs()
	local inv_map = co:getInverseMap()
	for i, c in ipairs(inputs) do
		local t, n = inv_map[c]:match("^(.-)(%d+)$")
		if t == "key" then
			t = ""
		end
		if imgui.button("order column " .. i, t:sub(1, 1):upper() .. n, swapping_column == c) then
			if not swapping_column then
				swapping_column = c
			else
				co.map[inv_map[swapping_column]], co.map[inv_map[c]] = co.map[inv_map[c]], co.map[inv_map[swapping_column]]
				swapping_column = nil
			end
		end
		just.next(-14)
	end
	just.row(false)

	replayBase.columns_order = co:export()

	scrollY = imgui.Container()
	just.pop()

	love.graphics.setColor(1, 1, 1, 1)
	love.graphics.rectangle("line", 0, 0, w, h, r)
end)
