local View = require("gui.View")

---@class ui.ModalView : gui.View
---@operator call: ui.ModalView
local ModalView = View + {}

function ModalView:show()
	error("ModalView:show() must be implemented")
end

function ModalView:hide()
	error("ModalView:hide() must be implemented")
end

return ModalView
