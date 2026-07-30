local View = require("gui.View")

---Base class for controls eligible for Form keyboard navigation.
---@class ui.views.form.FormControl : gui.View
---@operator call: ui.views.form.FormControl
local FormControl = View + {}

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
		parent:clearSelection()
	end
end

---@param e gui.MouseDownEvent
function FormControl:onMouseDown(e)
	if e.button == 1 then
		self:disableFormNavigation()
	end
end

return FormControl
