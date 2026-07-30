local View = require("gui.View")

---Base class for controls eligible for Form keyboard navigation.
---@class ui.views.form.FormControl : gui.View
---@operator call: ui.views.form.FormControl
local FormControl = View + {}

---@return boolean selectable
function FormControl:canBeSelected()
	return self.effective_visible and self.effective_enabled
end

return FormControl
