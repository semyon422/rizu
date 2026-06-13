local gfx_util = require("gfx_util")

return function(self)
	local waveform = self.game.configModel.configs.settings.editor.waveform
	if waveform.opacity == 0 or waveform.scale == 0 then
		return
	end

	local noteSkin = self.game.noteSkinModel.noteSkin
	local editor = self.game.configModel.configs.settings.editor
	local state = self.editorViewServices.waveformService:update(
		self.game.editorModel.context:getViewContext(),
		noteSkin,
		editor
	)
	if not state then
		return
	end

	love.graphics.push("all")
	love.graphics.setLineJoin("none")
	love.graphics.setLineStyle("smooth")
	love.graphics.setLineWidth(1)
	love.graphics.setColor(1, 1, 1, waveform.opacity)

	love.graphics.replaceTransform(gfx_util.transform(self.transform))
	love.graphics.translate(noteSkin.baseOffset, noteSkin.hitposition)
	love.graphics.translate(0, state.pointDrawDelta)

	for j = 0, state.channelCount - 1 do
		local line = state.lines[j]
		if #line >= 4 then
			love.graphics.push()
			love.graphics.scale(waveform.scale, 1)
			love.graphics.line(line)
			love.graphics.pop()
		end
		love.graphics.translate(noteSkin.fullWidth, 0)
	end

	love.graphics.pop()
end
