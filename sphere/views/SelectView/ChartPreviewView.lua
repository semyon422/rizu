local class = require("class")
local SequenceView = require("sphere.views.SequenceView")
local ChartPreviewRhythmView = require("sphere.views.SelectView.ChartPreviewRhythmView")

---@class sphere.ChartPreviewView
---@operator call: sphere.ChartPreviewView
local ChartPreviewView = class()

---@param game sphere.GameController
function ChartPreviewView:new(game)
	self.game = game
	self.sequenceView = SequenceView()
	self.sequenceView:setSequenceConfig({})
end

function ChartPreviewView:load()
	local noteSkin = self.game.previewModel.chartPreview.noteSkin
	if not noteSkin then
		return
	end

	local playfield = self.game.previewModel.chartPreview.playField
	local transform = playfield:newNoteskinTransform()

	local sequenceView = self.sequenceView
	sequenceView.game = self.game
	sequenceView.subscreen = "preview"
	-- sequenceView:setSequenceConfig(playfield)

	sequenceView:setSequenceConfig({
		ChartPreviewRhythmView({
			transform = transform,
			subscreen = "preview",
			chartPreview = self.game.previewModel.chartPreview
		}),
	})
	sequenceView:load()

	self.loaded = true
end

---@param dt number
function ChartPreviewView:update(dt)
	if not self.loaded then
		self:load()
	end
	self.sequenceView:update(dt)
end

---@param event table
function ChartPreviewView:receive(event)
	self.sequenceView:receive(event)
end

function ChartPreviewView:draw()
	self.sequenceView:draw()
end

function ChartPreviewView:unload()
	self.sequenceView:unload()
end

return ChartPreviewView
