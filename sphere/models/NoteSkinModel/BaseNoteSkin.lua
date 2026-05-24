local NoteSkinVsrg = require("sphere.models.NoteSkinModel.NoteSkinVsrg")
local BasePlayfield = require("sphere.models.NoteSkinModel.BasePlayfield")
local JustConfig = require("sphere.JustConfig")
local InputMode = require("chart.core.InputMode")

---@class sphere.BaseNoteSkin: sphere.NoteSkinVsrg
---@operator call: sphere.BaseNoteSkin
local BaseNoteSkin = NoteSkinVsrg + {}

BaseNoteSkin.bgaTransform = {{1 / 2, -16 / 9 / 2}, {0, -7 / 9 / 2}, 0, {0, 16 / 9}, {0, 16 / 9}, 0, 0, 0, 0}

---@param t table
---@return table
local function copyTable(t)
	local t2 = {}
	for k, v in pairs(t) do
		t2[k] = v
	end
	return t2
end

local configPath = "sphere/models/NoteSkinModel/BaseNoteSkinConfig.lua"

function BaseNoteSkin:load(inputMode)
	self.inputMode = InputMode(inputMode)
	self.stringInputMode = inputMode

	BaseNoteSkin.configContent = BaseNoteSkin.configContent or love.filesystem.read(configPath)

	local config = JustConfig({defaultContent = self.configContent}):fromFile(
		"userdata/skins/base." .. self.stringInputMode .. ".config.lua"
	)
	self.config = config

	self.name = "base skin"
	self.range = {-1, 1}
	self.unit = 480
	self.hitposition = config:get("hitposition") or 450
	self.columnWidth = config:get("noteWidth") or 48
	self.noteHeight = config:get("noteHeight") or 24

	local inputs = self.inputMode:getInputs()
	self:setInput(inputs)

	local width = {}
	local space = {}
	local image = {}
	local keyImage = {}
	local guidelines = {
		y = {},
		w = {},
		h = {},
		image = {},
	}
	local oldInputType
	for i = 1, #inputs do
		width[i] = self.columnWidth
		space[i] = 0
		image[i] = "pixel"
		keyImage[i] = "pixel.png"

		local input = inputs[i]
		local inputType, inputIndex = input:match("^(.-)(%d+)$")
		if not oldInputType then
			oldInputType = inputType
		elseif oldInputType ~= inputType then
			oldInputType = inputType
			guidelines.w[i] = 1
		end
		guidelines.y[i] = 0
		guidelines.w[i] = guidelines.w[i] or 0
		guidelines.h[i] = self.unit
		guidelines.image[i] = "pixel.png"
	end
	space[#inputs + 1] = 0
	guidelines.y[#inputs + 1] = 0
	guidelines.w[#inputs + 1] = 0
	guidelines.h[#inputs + 1] = self.unit
	guidelines.image[#inputs + 1] = "pixel.png"

	self:setColumns({
		offset = config:get("offset") or 0,
		align = config:get("align") or "center",
		width = width,
		space = space,
		upscroll = config:get("upscroll"),
	})

	self:setTextures({{pixel = "pixel.png"}})
	self:setImagesAuto()
	self:setShortNote({
		image = copyTable(image),
		h = self.noteHeight
	})
	self:setLongNote({
		head = copyTable(image),
		tail = copyTable(image),
		body = copyTable(image),
		h = self.noteHeight
	})
	self:setShortNote({
		image = copyTable(image),
		h = self.noteHeight,
		color = {1, 0.25, 0.25, 1},
	}, "SoundNote")
	if config:get("measureLine") then
		self:addMeasureLine({
			h = 4,
			color = {1, 1, 1, 0.5},
			image = "pixel"
		})
	end

	self:addBga({
		x = 0,
		y = 0,
		w = 1,
		h = 1,
		color = {0.25, 0.25, 0.25, 1},
	})

	local playfield = BasePlayfield(self)

	local judgementLineHeight = config:get("judgementLineHeight") or 4
	playfield:addBga({transform = self.bgaTransform})
	playfield:enableCamera()
	playfield:addNotes()
	playfield:addLightings()
	playfield:addKeyImages({
		h = judgementLineHeight,
		padding = self.unit - self.hitposition - judgementLineHeight,
		pressed = keyImage,
		released = keyImage,
	})
	playfield:addGuidelines(guidelines)
	playfield:addLaneCovers(config.data.covers)
	playfield:disableCamera()
	playfield:addBaseElements()
end

return BaseNoteSkin
