local View = require("gui.View")

---@class yi.views.editor.EditorOnsetsDistView: gui.View
---@operator call: yi.views.editor.EditorOnsetsDistView
---@field screen table
local EditorOnsetsDistView = View + {}

---@param screen table
function EditorOnsetsDistView:new(screen)
	View.new(self)
	self.screen = screen
	self:setSize(love.graphics.getDimensions())
end

function EditorOnsetsDistView:load()
	self:setSize(love.graphics.getDimensions())
end

function EditorOnsetsDistView:draw()
	local screen = self.screen
	local state = screen.editorViewServices.onsetsService:getDistributionState(
		screen.game.editorModel.context:getViewContext()
	)
	if not state then
		return
	end

	local w, h = love.graphics.getDimensions()

	love.graphics.origin()
	love.graphics.setLineWidth(1)

	for _, obj in ipairs(state.onsetsDeltaDist) do
		local y = h / 2
		love.graphics.line(obj.t * w, y, obj.t * w, y + obj.v * h / 10)
	end

	for i = 0, state.binsSize - 1 do
		local v = state.bins[i]
		local x = i / state.binsSize
		love.graphics.line(x * w, 0, x * w, v * h / 10)
	end
end

return EditorOnsetsDistView
