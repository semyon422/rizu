local gfx_util = require("gfx_util")

return function(self)
	local editor = self.game.configModel.configs.settings.editor
	local onsetsService = self.editorViewServices.onsetsService
	local state = onsetsService:getOnsetsState(self.game.editorModel.context:getViewContext(), editor.speed)
	if not state then
		return
	end
	local node = state.node

	local noteSkin = self.game.noteSkinModel.noteSkin

	love.graphics.push("all")
	love.graphics.setLineJoin("none")
	love.graphics.setLineStyle("smooth")
	love.graphics.setLineWidth(2)
	love.graphics.setColor(1, 1, 1, 1)

	love.graphics.replaceTransform(gfx_util.transform(self.transform))
	love.graphics.translate(noteSkin.baseOffset + noteSkin.fullWidth, 0)

	while node and onsetsService:isNodeVisible(state, node) do
		local onset = node.key
		local y = noteSkin:getTimePosition((state.time - onset.time) * editor.speed)

		local value = onset.value

		if value <= 0 then
			love.graphics.setColor(1, 1, 1, 0.5)
		else
			if onset.peak_time then
				local yp = noteSkin:getTimePosition((state.time - onset.peak_time) * editor.speed)
				love.graphics.setColor(1, 1, 1, 0.2)
				love.graphics.line(100, yp, 300, yp)
			end
			love.graphics.setColor(1, 1, 1, 1)
		end

		love.graphics.line(100, y, 100 + value * 100, y)

		node = node:next()
	end

	love.graphics.pop()
end
