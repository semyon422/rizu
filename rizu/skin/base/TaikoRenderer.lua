local PlayfieldRenderer = require("rizu.gameplay.views.PlayfieldRenderer")

---@class rizu.skin.base.TaikoRenderer : rizu.gameplay.views.PlayfieldRenderer
---@operator call: rizu.skin.base.TaikoRenderer
local TaikoRenderer = PlayfieldRenderer + {}

---@param game sphere.GameController
function TaikoRenderer:new(game)
	PlayfieldRenderer.new(self, game)
end

---@param width number Gameplay viewport width in drawable pixels
---@param height number Gameplay viewport height in drawable pixels
---@param transform love.Transform Maps viewport coordinates to drawable pixels
function TaikoRenderer:draw(width, height, transform)
	local re = self.game.rhythm_engine
	local rules = re and re.taiko_rules
	if not rules then return end
	love.graphics.push("all")
	love.graphics.setColor(0.04, 0.05, 0.08)
	love.graphics.applyTransform(transform)
	love.graphics.rectangle("fill", 0, 0, width, height)
	local scale = math.min(width / 800, height / 450)
	love.graphics.translate((width - 800 * scale) / 2, (height - 450 * scale) / 2)
	love.graphics.scale(scale)
	love.graphics.setColor(0.7, 0.8, 1)
	love.graphics.setLineWidth(2)
	love.graphics.line(80, 210, 760, 210)
	love.graphics.circle("line", 100, 210, 28)
	local time = re.visual_info.time
	for i = rules.first_index, #rules.objects do
		local object, state = rules.objects[i], rules.states[i]
		if object.time > time + rules.preempt then break end
		if not state.result then
			local x = 100 + (object.time - time) / rules.preempt * 640
			if object.kind == "note" then
				if object.color == "don" then love.graphics.setColor(1, 0.35, 0.35) else love.graphics.setColor(0.35, 0.7, 1) end
				love.graphics.circle("fill", x, 210, object.big and 25 or 17)
				if state.first_time then
					love.graphics.setColor(1, 1, 1)
					love.graphics.circle("line", x, 210, 29)
				end
			else
				local ending = math.min(760, 100 + (object.end_time - time) / rules.preempt * 640)
				x = math.max(100, x)
				if object.kind == "roll" then love.graphics.setColor(1, 0.8, 0.25) else love.graphics.setColor(0.75, 0.4, 1) end
				love.graphics.setLineWidth(object.big and 28 or 18)
				love.graphics.line(x, 210, ending, 210)
			end
		end
	end
	love.graphics.pop()
end

return TaikoRenderer
