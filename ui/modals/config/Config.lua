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
---@field config rizu.config.Config|table
---@field schema? table
---@field scroll_view gui.ScrollView
---@field setting_views {[table]: gui.View}
---@field private config_observer? util.Observer
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

---@param root table
---@param keys (string|integer)[]
---@return any
local function getLegacyValue(root, keys)
	local node = root
	for _, key in ipairs(keys) do
		node = node[key]
	end
	return node
end

---@param root table
---@param keys (string|integer)[]
---@param value any
local function setLegacyValue(root, keys, value)
	local node = root
	for i = 1, #keys - 1 do
		node = node[keys[i]]
	end
	node[keys[#keys]] = value
end

---@param root table
---@param descriptor ui.SettingSchema
---@param path string
---@param keys (string|integer)[]
---@return gui.View? row
---@return gui.View? control
local function createLegacySettingView(root, descriptor, path, keys)
	local value = getLegacyValue(root, keys)
	local label = formatPath(path) .. (descriptor.deprecated and " (deprecated)" or "")
	if descriptor.kind == "checkbox" then
		local checkbox = Checkbox({
			text = label,
			checked = value,
			on_change = function(new_value)
				setLegacyValue(root, keys, new_value)
			end,
		})
		return checkbox, checkbox
	elseif descriptor.kind == "choice" then
		local dropdown = Dropdown({
			options = descriptor.options,
			value = value,
			width = 780,
			on_change = function(new_value)
				setLegacyValue(root, keys, new_value)
			end,
		})
		local row = FlowContainer({direction = "column", gap = 6,
			Label({font_name = "regular", font_size = 20, text = label}), dropdown})
		row:fitContent()
		return row, dropdown
	elseif descriptor.kind == "range" then
		-- Keep hand-edited legacy values usable even when they exceed the UI's suggested range.
		local min_value = math.min(descriptor.min_value, value)
		local max_value = math.max(descriptor.max_value, value)
		local slider = Slider({
			value = value,
			min = min_value,
			max = max_value,
			step = descriptor.step,
			width = 780,
			on_change = function(new_value)
				setLegacyValue(root, keys, new_value)
			end,
		})
		local row = FlowContainer({direction = "column", gap = 6,
			Label({font_name = "regular", font_size = 20, text = label}), slider})
		row:fitContent()
		return row, slider
	elseif descriptor.kind == "textbox" or descriptor.kind == "list" then
		local text = descriptor.kind == "list" and table.concat(value, ", ") or tostring(value)
		local textbox = Textbox({
			text = text,
			width = 780,
			on_change = function(new_value)
				if descriptor.kind == "list" then
					local values = {}
					for item in new_value:gmatch("[^,%s]+") do
						values[#values + 1] = item
					end
					setLegacyValue(root, keys, values)
				else
					setLegacyValue(root, keys, new_value)
				end
			end,
		})
		local row = FlowContainer({direction = "column", gap = 6,
			Label({font_name = "regular", font_size = 20, text = label}), textbox})
		row:fitContent()
		return row, textbox
	end
end

---@class ui.LegacySettingEntry
---@field descriptor ui.SettingSchema
---@field path string
---@field keys (string|integer)[]

---@param node table
---@param path string
---@param keys (string|integer)[]
---@param entries ui.LegacySettingEntry[]
local function collectLegacySettings(node, path, keys, entries)
	for key, child in pairs(node) do
		local child_keys = {unpack(keys)}
		child_keys[#child_keys + 1] = key
		local child_path = path == "" and tostring(key) or path .. "." .. tostring(key)
		if child.kind then
			entries[#entries + 1] = {descriptor = child, path = child_path, keys = child_keys}
		else
			collectLegacySettings(child, child_path, child_keys, entries)
		end
	end
end

---@param config rizu.config.Config|table
---@param schema? table Legacy settings schema from ui.Settings.
function Config:new(config, schema)
	ModalView.new(self)
	self.config = config
	self.schema = schema
	self.setting_views = {}
	self:setSize(890, 600)
	self:setAlignment(0.5, 0.5)
	self:setPivot(0.5, 0.5)
	self:setScale(0.9, 0.9)
	self:setOpacity(0)
	self:setVisible(false)

	local content = DropdownHost({direction = "column", gap = 18, padding = {20, 16, 20, 16}})
	content:add(Label({font_name = "bold", font_size = 32, text = "Settings"}))
	if schema then
		local entries = {} ---@type ui.LegacySettingEntry[]
		collectLegacySettings(schema, "", {}, entries)
		table.sort(entries, function(a, b)
			return a.descriptor.order < b.descriptor.order
		end)
		for _, entry in ipairs(entries) do
			local row, control = createLegacySettingView(config, entry.descriptor, entry.path, entry.keys)
			if row then
				content:add(row)
				self.setting_views[entry.descriptor] = control
			end
		end
	else
		---@cast config rizu.config.Config
		local settings = {} ---@type rizu.config.Setting[]
		for setting in pairs(config.settings_map) do
			settings[#settings + 1] = setting
		end
		table.sort(settings, function(a, b)
			return a.order < b.order
		end)
		for _, setting in ipairs(settings) do
			local path = assert(config.setting_to_path[setting], "setting has no config path")
			local row, control = createSettingView(config, setting, path)
			if row then
				content:add(row)
				self.setting_views[setting] = control
			end
		end
	end
	content:fitContent()

	self.scroll_view = ScrollView(content)
	self.scroll_view:anchorFixed(35, 40, 820, 520)

	local q = Resources.sprites

	self.background = NineSliceUsage({
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
	if self.schema then
		return
	end
	---@cast self.config rizu.config.Config
	self.config_observer = self.config.onChanged:add(function(setting)
		self:syncSetting(setting)
	end)
end

function Config:unload()
	if not self.config_observer then
		return
	end
	---@cast self.config rizu.config.Config
	self.config.onChanged:remove(self.config_observer)
	self.config_observer = nil
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
