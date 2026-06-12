local gfx_util = require("gfx_util")

---@param key table
local function exTime(key)
	return key.time
end

return function(self)
	local editor = self.game.configModel.configs.settings.editor
	local editorModel = self.game.editorModel
	local ncbtContext = editorModel.ncbtContext
	local onsets = ncbtContext.onsets
	if not onsets then
		return
	end

	local time = editorModel:getSessionTime() - editorModel.audio_engine:getStartTime()

	local a, b = onsets:findex(time - 1 / editor.speed, exTime)
	local node = a or b

	if not node then
		return
	end

	local noteSkin = self.game.noteSkinModel.noteSkin

	love.graphics.push("all")
	love.graphics.setLineJoin("none")
	love.graphics.setLineStyle("smooth")
	love.graphics.setLineWidth(2)
	love.graphics.setColor(1, 1, 1, 1)

	love.graphics.replaceTransform(gfx_util.transform(self.transform))
	love.graphics.translate(noteSkin.baseOffset + noteSkin.fullWidth, 0)

	while node and node.key.time < time + 1 / editor.speed do
		local onset = node.key
		local y = noteSkin:getTimePosition((time - onset.time) * editor.speed)

		local value = onset.value

		if value <= 0 then
			love.graphics.setColor(1, 1, 1, 0.5)
		else
			if onset.peak_time then
				local yp = noteSkin:getTimePosition((time - onset.peak_time) * editor.speed)
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
