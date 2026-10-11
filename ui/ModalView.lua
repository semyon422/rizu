local CompositeView = require("gui.CompositeView")

---A composite so the show/hide fades blend the whole modal as one layer.
---@class ui.ModalView : gui.CompositeView
---@operator call: ui.ModalView
local ModalView = CompositeView + {}

function ModalView:show()
	error("ModalView:show() must be implemented")
end

function ModalView:hide()
	error("ModalView:hide() must be implemented")
end

return ModalView
