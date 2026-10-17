local class = require("class")

---@class ui.modals.config.Section.Config
---@field name string
---@field icon gui.Sprite
---@field build fun(section: ui.modals.config.Section): ui.views.form.FormControl[]

---Defines a stateful settings section without owning any views.
---@class ui.modals.config.Section
---@operator call: ui.modals.config.Section
---@field name string
---@field icon gui.Sprite
---@field state {[string]: any}
---@field private build_controls fun(section: ui.modals.config.Section): ui.views.form.FormControl[]
---@field private invalidator (fun())?
local Section = class()

---@param config ui.modals.config.Section.Config
function Section:new(config)
	self.name = config.name
	self.icon = config.icon
	self.state = {}
	self.build_controls = config.build
	self.invalidator = nil
end

---@param invalidator fun()
function Section:setInvalidator(invalidator)
	self.invalidator = invalidator
end

function Section:invalidate()
	if self.invalidator then
		self.invalidator()
	end
end

---@return ui.views.form.FormControl[] controls
function Section:build()
	return self.build_controls(self)
end

return Section
