local ConfigV2 = require("ui.modals.config.ConfigV2")
local FakeApp = require("rizu.api.fake.FakeApp")
local FakeFilesystem = require("fs.FakeFilesystem")
local Inputs = require("gui.input.Inputs")
local Localization = require("ui.localization.Localization")
local PopupContainer = require("ui.views.PopupContainer")
local Resources = require("ui.Resources")
local Screen = require("gui.Screen")
local Settings = require("rizu.config.Settings")
local UiConfig = require("ui.UiConfig")

local test = {}

---@return ui.modals.config.ConfigV2 config
---@return gui.Screen screen
local function createConfig()
	if not love.graphics.isActive() then assert(love.window.setMode(1600, 900)) end
	Resources.load()
	local fs = FakeFilesystem()
	fs:createDirectory("userdata")
	local screen = Screen()
	local popup_container = PopupContainer()
	local config = ConfigV2(
		UiConfig(fs, "userdata/ui.json"),
		Settings.createConfig(fs),
		popup_container,
		function() end,
		Localization(),
		function() end,
		FakeApp(),
		function() end
	)
	screen.root:add(config)
	screen.root:add(popup_container)
	screen.inputs = Inputs()
	screen:load()
	screen:resize(1600, 900)
	config:show()
	return config, screen
end

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
function test.rows_form_one_rounded_group_per_section(t)
	local config, screen = createConfig()
	run(screen, 2)

	local groups = {} ---@type ui.modals.config.rows.SettingRow[][]
	for _, row in ipairs(config.form.rows.children) do
		local setting_row = (row --[[@as {setting_row: ui.modals.config.rows.SettingRow?}]]).setting_row
		if not setting_row then
			groups[#groups + 1] = {}
		else
			table.insert(groups[#groups], setting_row)
		end
	end
	t:eq(#groups, #config.visible_sections)
	for _, group in ipairs(groups) do
		t:assert(#group > 0)
		for index, setting_row in ipairs(group) do
			t:eq(setting_row.first, index == 1)
			t:eq(setting_row.last, index == #group)
		end
	end
	screen:unload()
end

---@param t testing.T
function test.sidebar_follows_the_scrolled_section(t)
	local config, screen = createConfig()
	run(screen, 2)
	local first, last = config.visible_sections[1], config.visible_sections[#config.visible_sections]
	t:eq(config.nav_items[first].active, true)

	config:scrollToSection(last)
	run(screen, 120)
	t:eq(config.nav_items[first].active, false)
	t:eq(config.nav_items[last].active, true)
	screen:unload()
end

return test
