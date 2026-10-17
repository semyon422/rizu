local class = require("class")

---Scrollable content state consumed by scrollbar views.
---@class gui.IScrollModel
---@operator call: gui.IScrollModel
local IScrollModel = class()

---Returns the bounded visual position. Transient rubber-band overscroll is not
---included, so scrollbar thumbs remain inside their tracks.
---@return number position
function IScrollModel:getScrollPosition()
	error("not implemented")
end

---@return number size
function IScrollModel:getScrollContentSize()
	error("not implemented")
end

---@return number size
function IScrollModel:getScrollViewportSize()
	error("not implemented")
end

---@param position number
---@param immediate boolean?
function IScrollModel:scrollTo(position, immediate)
	error("not implemented")
end

return IScrollModel
