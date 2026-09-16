local View = require("gui.View")
local NineSlice = require("gui.NineSlice")
local Colors = require("ui.Colors")
local Label = require("ui.views.Label")
local Rectangle = require("ui.views.Rectangle")
local Resources = require("ui.Resources")
local Settings = require("rizu.config.Settings")

local WIDTH = 72
local HEIGHT = 320
local BAR_X = 28
local BAR_Y = 60
local BAR_WIDTH = 16
local BAR_HEIGHT = HEIGHT - BAR_Y - 20
local DISPLAY_DURATION = 1
local FADE_DURATION = 0.25

---@class ui.views.VolumeOverlay : gui.View
---@operator call: ui.views.VolumeOverlay
---@field label ui.views.Label
---@field fill ui.views.Rectangle
---@field private unsubscribe_volume function
local VolumeOverlay = View + {}

---@param settings rizu.config.Config
function VolumeOverlay:new(settings)
	View.new(self)
	self:setSize(WIDTH, HEIGHT)
	self:setOpacity(0)

	self:add(NineSlice(Resources.nine_slices.volume_overlay)):anchorFill(0, 0, 0, 0)
	local bar = self:add(View())
	bar:anchorFixed(BAR_X, BAR_Y, BAR_WIDTH, BAR_HEIGHT)
	bar:add(Rectangle(Colors.surface_raised)):anchorFill(0, 0, 0, 0)
	self.fill = bar:add(Rectangle(Colors.accent))
	self.fill:setSize(BAR_WIDTH, 0):setAlignment(0, 1)

	self.label = self:add(Label({
		font_name = "medium",
		font_size = 24,
		text = "0%",
		align = "center",
	}))
	self.label:setAlignmentX(0.5):addPosition(0, 10)

	local volume_key = Settings.keys.audio.volume_master
	self.unsubscribe_volume = settings:subscribeNumber(volume_key, function(volume)
		self:showVolume(volume)
	end)
end

---@param volume number
function VolumeOverlay:showVolume(volume)
	volume = math.max(0, math.min(1, volume))
	self.label:setText(("%d%%"):format(math.floor(volume * 100 + 0.5)))
	self.fill:setHeight(BAR_HEIGHT * volume)

	self:clearTransforms("opacity")
	self:setOpacity(1)
	self:delay(DISPLAY_DURATION):fadeOut(FADE_DURATION)
end

function VolumeOverlay:unload()
	self.unsubscribe_volume()
end

return VolumeOverlay
