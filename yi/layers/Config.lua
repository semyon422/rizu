local Layer = require("ui.Layer")
local Title = require("yi.views.Title")
local SettingsSchema = require("rizu.config.schemas.Settings")

local ConfigList = require("yi.views.config.ConfigList")
local ConfigTopBar = require("yi.views.config.ConfigTopBar")
local Checkbox = require("yi.views.config.Checkbox")
local Slider = require("yi.views.config.Slider")
local Dropdown = require("yi.views.config.Dropdown")

local lang = require("yi.lang.en")

local S = require("ui.composition.Strategies")

---@class yi.Config : ui.Layer
---@operator call: yi.Config
local Config = Layer + {}

---@param yi yi.UserInterface
function Config:new(yi)
	Layer.new(self)
	self.yi = yi

	self.atlas, self.quads = yi.resources.atlas, yi.resources.quads
	self.groups = {"all", "audio", "graphics", "gameplay", "select", "input", "offsets", "misc"}

	local cfg = self.yi.game.settings_config
	self.config_list = ConfigList(yi.resources, SettingsSchema, cfg)


	self.top_bar = ConfigTopBar(
		yi.resources,
		self.groups,
		function() end
	)

	self:setTab("all")

	self.composition:setRoot(S.Stack({
		padding = {100, 60, 20, 100},

		S.Track({
			direction = "column",
			space = {120, 20, 50, 20, "*"},

			Title(self.atlas, self.quads),
			S.Stack(),
			self.top_bar,
			S.Stack(),
			S.Track({
				space = {"*", "-", "*"},
				S.Stack(),
				self.config_list,
				S.Stack(),
			})
		}),
	}))
end

---@param group_name string
---@param section_name string
---@param setting_name string
---@param setting rizu.config.Setting
---@param cfg rizu.config.Config
---@return yi.ConfigItem?
local function makeItem(group_name, section_name, setting_name, setting, cfg)
	local key = ("%s.%s.%s"):format(group_name, section_name, setting_name)
	local label = lang.settings[key] or key
	local kind = setting.kind
	local item ---@type yi.ConfigItem?
	if kind == "checkbox" then
		item = Checkbox(label, setting, cfg)
	elseif kind == "range" then
		item = Slider(label, setting, cfg)
	elseif kind == "choice" then
		item = Dropdown(label, setting, cfg)
	end
	return item
end

---@param name string
function Config:setTab(name)
	local items = {} ---@type yi.ConfigItem[]
	local cfg = self.yi.game.settings_config

	if name == "all" then
		for group_name, group in pairs(SettingsSchema) do
			for section_name, section in pairs(group) do
				for setting_name, setting in pairs(section) do
					local item = makeItem(group_name, section_name, setting_name, setting, cfg)
					table.insert(items, item)
				end
			end
		end
	elseif SettingsSchema[name] then
		local group = SettingsSchema[name]
		local group_name = name
		for section_name, section in pairs(group) do
			for setting_name, setting in pairs(section) do
				local item = makeItem(group_name, section_name, setting_name, setting, cfg)
				table.insert(items, item)
			end
		end
	end

	table.sort(items, function(a, b)
		return a.label < b.label
	end)

	self.config_list:setItems(items)
end

function Config:handleKeyDown(key)
	if key == "escape" then
		local prev = self.yi.previous_screen
		if not prev or prev == "config" then
			self.yi:setScreen("main_menu")
		else
			self.yi:setScreen(prev)
		end
		self.yi.game.settings_config:commit()
		return true
	end

	local n = tonumber(key)
	if n then
		self:setTab(self.groups[n])
		self.top_bar:setTabActive(n)
	end
end

return Config
