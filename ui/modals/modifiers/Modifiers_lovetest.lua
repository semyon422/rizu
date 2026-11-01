local FakePlay = require("rizu.api.fake.FakePlay")
local FakeScores = require("rizu.api.fake.FakeScores")
local Inputs = require("gui.input.Inputs")
local Localization = require("ui.localization.Localization")
local Modifiers = require("ui.modals.modifiers.Modifiers")
local Resources = require("ui.Resources")
local Screen = require("gui.Screen")

local test = {}

---@param screen gui.Screen
---@param frames integer
local function run(screen, frames)
	for _ = 1, frames do
		screen:update(1 / 60)
		love.graphics.clear()
		screen:draw()
		love.graphics.present()
	end
end

---@param t testing.T
function test.rows_form_one_group_per_section_inside_the_modal(t)
	if not love.graphics.isActive() then assert(love.window.setMode(1600, 900)) end
	Resources.load()
	local play = FakePlay()
	for _, toggle in ipairs({"auto_timings", "auto_accuracy", "auto_healths"}) do
		play:setToggle(toggle, false)
	end
	local screen = Screen()
	local modifiers = Modifiers(play --[[@as rizu.api.Play]], function() end, Localization(), function() end,
		FakeScores() --[[@as rizu.api.Scores]])
	screen.root:add(modifiers)
	screen.inputs = Inputs()
	screen:load()
	screen:resize(1600, 900)
	modifiers:show()
	run(screen, 2)

	local groups = {} ---@type gui.View[][]
	for _, row in ipairs(modifiers.form.rows.children) do
		local setting_row = (row --[[@as {setting_row: ui.modals.config.rows.SettingRow?}]]).setting_row
		if not setting_row then
			groups[#groups + 1] = {}
		else
			t:eq(row.x + row.width <= modifiers.width - 32, true)
			table.insert(groups[#groups], row)
		end
	end
	t:eq(#groups, 4)
	for _, group in ipairs(groups) do
		for index, row in ipairs(group) do
			local setting_row = (row --[[@as {setting_row: ui.modals.config.rows.SettingRow}]]).setting_row
			t:eq(setting_row.first, index == 1)
			t:eq(setting_row.last, index == #group)
		end
	end
	screen:unload()
end

return test
