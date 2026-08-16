local FormNavigation = require("ui.views.form.FormNavigation")
local View = require("gui.View")

---Base class for controls eligible for Form keyboard navigation.
---@class ui.views.form.FormControl : gui.View
---@operator call: ui.views.form.FormControl
---@field setting_name string?
---@field setting_keywords string[]
---@field tip string?
---@field setting_key string?
---@field private unsubscribe_setting function?
local FormControl = View + {}

function FormControl:new()
	View.new(self)
	self.setting_name = nil
	self.setting_keywords = {}
	self.tip = nil
	self.setting_key = nil
	self.unsubscribe_setting = nil
end

---@param unsubscribe function
function FormControl:setSettingSubscription(unsubscribe)
	self.unsubscribe_setting = unsubscribe
end

function FormControl:unload()
	if self.unsubscribe_setting then
		self.unsubscribe_setting()
		self.unsubscribe_setting = nil
	end
end

---@param name string
---@param keywords string[]?
---@param tip string?
---@param key string?
---@return ui.views.form.FormControl
function FormControl:setSettingMetadata(name, keywords, tip, key)
	self.setting_name = name
	self.setting_keywords = keywords or {}
	self.tip = tip
	self.setting_key = key
	return self
end

---@return boolean selectable
function FormControl:canBeSelected()
	return self.effective_visible and self.effective_enabled
end

---@param e gui.KeyDownEvent
---@return boolean activated
function FormControl:activate(e)
	return false
end

---@param e gui.KeyDownEvent
---@return boolean handled
function FormControl:onFormKeyDown(e)
	return false
end

function FormControl:disableFormNavigation()
	-- Inline to break the Form -> FormControl dependency cycle.
	local Form = require("ui.views.form.Form")
	local parent = self.parent
	while parent and not (Form * parent) do
		parent = parent.parent
	end
	if parent then
		---@cast parent ui.views.form.Form
		parent:setNavigation(FormNavigation.Mouse)
	end
end

---@param e gui.MouseDownEvent
function FormControl:onMouseDown(e)
	if e.button == 1 then
		self:disableFormNavigation()
	end
end

return FormControl
