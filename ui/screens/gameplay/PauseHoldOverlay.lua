local View = require("gui.View")
local Label = require("ui.views.Label")
local NineSliceUsage = require("gui.NineSliceUsage")
local Painter = require("gui.Painter")
local Resources = require("ui.Resources")

---@class ui.screens.gameplay.PauseHoldOverlay : gui.View
---@operator call: ui.screens.gameplay.PauseHoldOverlay
---@field progress number
---@field prompt "pause"|"restart"
---@field label ui.views.Label
---@field pause_text string
---@field restart_text string
---@field background gui.NineSliceUsage
---@field progress_track gui.NineSliceUsage
---@field progress_fill gui.NineSliceUsage
local PauseHoldOverlay = View + {}

---@param localization ui.localization.Localization
function PauseHoldOverlay:new(localization)
	View.new(self)
	-- Keep the card proportional to the gameplay viewport. The message can wrap
	-- inside it, so longer translations do not escape the background.
	self:anchorPercent(0.28, 0.5, 0.72, 0.5)
	self:setHeight(180)
	self:setAlignmentY(0.5)
	self:setVisible(false)
	self:setOpacity(0)
	self.progress = 0
	self.prompt = "pause"
	self.pause_text = localization:get("gameplay.pause.hold")
	self.restart_text = localization:get("gameplay.retry.hold")
	self.background = NineSliceUsage(Resources.nine_slices.gameplay_pause_hold)
	self.progress_track = NineSliceUsage(Resources.nine_slices.gameplay_pause_hold_track)
	self.progress_fill = NineSliceUsage(Resources.nine_slices.gameplay_pause_hold_fill)

	self.label = self:add(Label({
		font_name = "bold",
		font_size = 26,
		text = self.pause_text,
		align = "center",
	}))
	self.label:fillWidth(36, 36)
	self.label:setHeight(72)
	self.label:setAlignmentY(0):addPosition(0, 30)
end

---@param prompt "pause"|"restart"
function PauseHoldOverlay:setPrompt(prompt)
	assert(prompt == "pause" or prompt == "restart", "invalid hold overlay prompt")
	if self.prompt == prompt then
		return
	end
	self.prompt = prompt
	-- The label has responsive authored bounds, so only replace its content;
	-- Label:setText() would attempt to restore an intrinsic fixed width.
	self.label.text = prompt == "pause" and self.pause_text or self.restart_text
end

---@param progress number
function PauseHoldOverlay:setProgress(progress)
	local was_active = self.progress > 0
	self.progress = math.max(0, math.min(1, progress))
	local is_active = self.progress > 0

	if is_active and not was_active then
		self:clearTransforms("opacity")
		self:setVisible(true)
		self:setOpacity(0)
		self:fadeIn(0.15, "OutQuad")
	elseif not is_active and was_active then
		self:clearTransforms("opacity")
		self:transformTo("opacity", 0, 0.12, "OutQuad", function()
			if self.progress == 0 then
				self:setVisible(false)
			end
		end)
	end
end

function PauseHoldOverlay:draw()
	Painter.setColorRgb(1, 1, 1)
	self.background:draw(self.width, self.height)
	local x, y, width, height = 42, 130, math.max(12, self.width - 84), 12
	love.graphics.push("transform")
	love.graphics.translate(x, y)
	self.progress_track:draw(width, height)
	if self.progress > 0 then
		love.graphics.push("transform")
		love.graphics.scale(self.progress, 1)
		self.progress_fill:draw(width, height)
		love.graphics.pop()
	end
	love.graphics.pop()
end

return PauseHoldOverlay
