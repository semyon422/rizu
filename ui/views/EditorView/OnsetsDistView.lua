return function(self)
	local state = self.editorViewServices.onsetsService:getDistributionState(
		self.game.editorModel.context:getViewContext()
	)
	if not state then
		return
	end

	local w, h = love.graphics.getDimensions()

	love.graphics.origin()
	love.graphics.setLineWidth(1)

	for i, obj in ipairs(state.onsetsDeltaDist) do
		local y = h / 2
		love.graphics.line(obj.t * w, y, obj.t * w, y + obj.v * h / 10)
	end

	for i = 0, state.binsSize - 1 do
		local v = state.bins[i]
		local x = i / state.binsSize
		love.graphics.line(x * w, 0, x * w, v * h / 10)
	end
end
