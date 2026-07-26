local ModalView = require("ui.ModalView")
local Resources = require("ui.Resources")
local Painter = require("gui.Painter")
local Colors = require("ui.Colors")
local Checkbox = require("ui.views.Checkbox")
local Dropdown = require("ui.views.Dropdown")
local DropdownHost = require("ui.views.DropdownHost")
local FlowContainer = require("gui.layout.FlowContainer")
local Label = require("ui.views.Label")
local ScrollView = require("gui.ScrollView")
local Slider = require("ui.views.Slider")
local Textbox = require("ui.views.Textbox")
local NineSliceUsage = require("gui.NineSliceUsage")

---@class ui.modals.config.Config : ui.ModalView
---@operator call: ui.modals.config.Config
---@field config rizu.config.Config
---@field scroll_view gui.ScrollView
---@field setting_views {[rizu.config.Setting]: gui.View}
---@field private config_observer util.Observer
local Config = ModalView + {}

---@param path string
---@return string
local function formatPath(path)
	local name = path:gsub("_", " "):gsub("%.", " / ")
	return name:gsub("^%l", string.upper)
end

---@param config rizu.config.Config
---@param setting rizu.config.Setting
---@param path string
---@return gui.View? row
---@return gui.View? control
local function createSettingView(config, setting, path)
	if setting.kind == "checkbox" then
		local checkbox = Checkbox({
			text = formatPath(path),
			checked = config:getBoolean(setting),
			on_change = function(value)
				config:setBoolean(setting, value)
			end,
		})
		return checkbox, checkbox
	elseif setting.kind == "choice" then
		local format = type(setting.format) == "function" and setting.format or nil
		local dropdown = Dropdown({
			options = setting.options,
			value = config:get(setting),
			width = 780,
			format = format,
			on_change = function(value)
				config:set(setting, value)
			end,
		})
		local row = FlowContainer({direction = "column", gap = 6,
			Label({font_name = "regular", font_size = 20, text = formatPath(path)}), dropdown})
		row:fitContent()
		return row, dropdown
	elseif setting.kind == "textbox" then
		local textbox = Textbox({
			text = config:getString(setting),
			width = 780,
			on_change = function(value)
				config:setString(setting, value)
			end,
		})
		local row = FlowContainer({direction = "column", gap = 6,
			Label({font_name = "regular", font_size = 20, text = formatPath(path)}), textbox})
		row:fitContent()
		return row, textbox
	elseif setting.kind == "range" then
		local slider = Slider({
			value = config:getNumber(setting),
			min = setting.min_value,
			max = setting.max_value,
			step = setting.step,
			width = 780,
			on_change = function(value)
				config:setNumber(setting, value)
			end,
		})
		local row = FlowContainer({direction = "column", gap = 6,
			Label({font_name = "regular", font_size = 20, text = formatPath(path)}), slider})
		row:fitContent()
		return row, slider
	end
end

---@param config rizu.config.Config
function Config:new(config)
	ModalView.new(self)
	self.config = config
	self.setting_views = {}
	self:setSize(890, 600)
	self:setAlignment(0.5, 0.5)
	self:setPivot(0.5, 0.5)
	self:setScale(0.9, 0.9)
	self:setOpacity(0)
	self:setVisible(false)

	local settings = {} ---@type rizu.config.Setting[]
	for setting in pairs(config.settings_map) do
		settings[#settings + 1] = setting
	end
	table.sort(settings, function(a, b)
		return a.order < b.order
	end)

	local content = DropdownHost({direction = "column", gap = 18, padding = {20, 16, 20, 16}})
	content:add(Label({font_name = "bold", font_size = 32, text = "Settings"}))
	for _, setting in ipairs(settings) do
		local path = assert(config.setting_to_path[setting], "setting has no config path")
		local row, control = createSettingView(config, setting, path)
		if row then
			content:add(row)
			self.setting_views[setting] = control
		end
	end
	content:fitContent()

	self.scroll_view = ScrollView(content)
	self.scroll_view:anchorFixed(35, 40, 820, 520)

	local q = Resources.quads

	self.background = NineSliceUsage(Resources.atlas, {
		q.nineslice_modal_lt,
		q.nineslice_modal_t,
		q.nineslice_modal_rt,
		q.nineslice_modal_l,
		q.nineslice_modal_c,
		q.nineslice_modal_r,
		q.nineslice_modal_lb,
		q.nineslice_modal_b,
		q.nineslice_modal_rb,
	})

	self:add(self.scroll_view)
end

---@param setting rizu.config.Setting
function Config:syncSetting(setting)
	local view = self.setting_views[setting]
	if not view then
		return
	end
	if setting.kind == "checkbox" then
		---@cast view ui.views.Checkbox
		view:setChecked(self.config:getBoolean(setting))
	elseif setting.kind == "choice" then
		---@cast view ui.views.Dropdown
		view:setValue(self.config:get(setting))
	elseif setting.kind == "textbox" then
		---@cast view ui.views.Textbox
		view:setText(self.config:getString(setting))
	elseif setting.kind == "range" then
		---@cast view ui.views.Slider
		view:setValue(self.config:getNumber(setting))
	end
end

function Config:load()
	self.config_observer = self.config.onChanged:add(function(setting)
		self:syncSetting(setting)
	end)
end

function Config:unload()
	self.config.onChanged:remove(self.config_observer)
end

function Config:show()
	self:setVisible(true)
	self:fadeIn(0.3, "OutCubic")
	self:scaleTo(1, 1, 0.4, "OutQuart")
end

function Config:hide()
	self:scaleTo(0.9, 0.9, 0.24, "InQuart")
	self:transformTo("opacity", 0, 0.2, "InCubic", function()
		self:setVisible(false)
	end)
end

function Config:draw()
	Painter.setColorTable(Colors.panel)
	self.background:draw(self.width, self.height)
end

return Config
