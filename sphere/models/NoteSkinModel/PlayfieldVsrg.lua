local class = require("class")

local RectangleView = require("sphere.views.RectangleView")
local ValueView = require("sphere.views.ValueView")
local ImageView = require("sphere.views.ImageView")
local CameraView = require("sphere.views.CameraView")
local ImageAnimationView = require("sphere.views.ImageAnimationView")

local ChartPreviewRhythmView = require("sphere.views.SelectView.ChartPreviewRhythmView")
local RhythmView = require("sphere.views.RhythmView")
local RectangleProgressView = require("sphere.views.GameplayView.RectangleProgressView")
local CircleProgressView = require("sphere.views.GameplayView.CircleProgressView")
local HitErrorView = require("sphere.views.GameplayView.HitErrorView")
local InputView = require("sphere.views.GameplayView.InputView")
local InputAnimationView = require("sphere.views.GameplayView.InputAnimationView")
local JudgementView = require("sphere.views.GameplayView.JudgementView")
local DeltaTimeJudgementView = require("sphere.views.GameplayView.DeltaTimeJudgementView")
local MatchPlayersView = require("sphere.views.GameplayView.MatchPlayersView")

---@class sphere.PlayfieldVsrg
---@operator call: sphere.PlayfieldVsrg
local PlayfieldVsrg = class()

---@param noteskin sphere.NoteSkin
function PlayfieldVsrg:new(noteskin)
	self.noteskin = noteskin
	self.noteskin.playField = self
end

---@param width number
---@param height number
---@param align string
---@return table
function PlayfieldVsrg:newTransform(width, height, align)
	local transform = {0, 0, 0, {0, 1 / height}, {0, 1 / height}, 0, 0, 0, 0}
	if align == "center" then
		transform[1] = {1 / 2, -width / height / 2}
	elseif align == "right" then
		transform[1] = {1, -width / height}
	end
	return transform
end

---@return table
function PlayfieldVsrg:newNoteskinTransform()
	local height = self.noteskin.unit
	local align = self.noteskin.align
	local transform = {0, 0, 0, {0, 1 / height}, {0, 1 / height}, 0, 0, 0, 0}
	if align == "center" then
		transform[1] = {1 / 2, 0}
	elseif align == "right" then
		transform[1] = {1, 0}
	end
	if self.noteskin.upscroll then
		transform[5][2] = -transform[5][2]
		transform[7] = height
	end
	return transform
end

---@param height number
---@return table
function PlayfieldVsrg:newLaneCenterTransform(height)
	local noteskin = self.noteskin
	local align = noteskin.align
	local offset = noteskin.columnsOffset or 0
	local unit = noteskin.unit or 1
	local transform = {0, 0, 0, {0, 1 / height}, {0, 1 / height}, 0, 0, 0, 0}
	if align == "center" then
		transform[1] = {1 / 2, offset / unit}
	elseif align == "right" then
		transform[1] = {1, -noteskin.fullWidth / unit / 2 + offset / unit}
	elseif align == "left" then
		transform[1] = {0, noteskin.fullWidth / unit / 2 + offset / unit}
	end
	return transform
end

---@param width number
---@param height number
---@return table
function PlayfieldVsrg:newFullTransform(width, height)
	return {0, 0, 0, {1 / width, 0}, {0, 1 / height}, 0, 0, 0, 0}
end

---@param ... any?
---@return any?
function PlayfieldVsrg:add(...)
	table.insert(self, ...)
	return ...
end

---@return table
function PlayfieldVsrg:enableCamera()
	return self:add(CameraView({
		draw_start = true,
	}))
end

---@return table
function PlayfieldVsrg:disableCamera()
	return self:add(CameraView({
		draw_end = true,
	}))
end

---@param object table
---@return table
function PlayfieldVsrg:addRhythmView(object)
	if not object.transform then
		object.transform = self:newNoteskinTransform()
	end
	return self:add(RhythmView(object))
end

---@param object table
---@return table
function PlayfieldVsrg:addImageView(object)
	return self:add(ImageView(object))
end

---@param object table?
---@return table
function PlayfieldVsrg:addNotes(object)
	object = object or {}
	if not object.transform then
		object.transform = self:newNoteskinTransform()
	end

	self:add(ChartPreviewRhythmView({
		transform = object.transform,
		subscreen = "preview",
	}))

	object.isNotesView = true
	object.subscreen = "gameplay"
	return self:addRhythmView(object)
end

---@param object table?
---@return table
function PlayfieldVsrg:addLightings(object)
	object = object or {}
	object.mode = "lighting"
	object.subscreen = "gameplay"
	return self:addRhythmView(object)
end

---@param object table?
---@return table
function PlayfieldVsrg:addBga(object)
	-- Kept for legacy noteskin compatibility. BGA is rendered by the UI.
	return object or {}
end

---@param object table?
---@return table
function PlayfieldVsrg:addProgressBar(object)
	object = object or {}
	object.subscreen = "gameplay"
	if not getmetatable(object) then
		object = RectangleProgressView(object)
	end
	function object:getProgress() return self.game.rhythm_engine:getProgress() end
	return self:add(object)
end

---@param object table?
---@return table
function PlayfieldVsrg:addCircleProgressBar(object)
	object = object or {}
	object.subscreen = "gameplay"
	if not getmetatable(object) then
		object = CircleProgressView(object)
	end
	function object:getProgress() return self.game.rhythm_engine:getProgress() end
	return self:add(object)
end

---@param object table?
---@return table
function PlayfieldVsrg:addHpBar(object)
	object = object or {}
	object.subscreen = "gameplay"
	if not getmetatable(object) then
		object = RectangleProgressView(object)
	end
	function object:getProgress()
		local healthsSource = self.game.rhythm_engine.score_engine.healthsSource
		return healthsSource:getHealths() / healthsSource:getMaxHealths()
	end
	return self:add(object)
end

---@param object table?
---@return table
function PlayfieldVsrg:addValueView(object)
	object = object or {}
	return self:add(ValueView(object))
end


---@param object table?
---@return table
function PlayfieldVsrg:addScore(object)
	object = object or {}
	object.subscreen = "gameplay"
	if not getmetatable(object) then
		object = ValueView(object)
	end
	function object:value()
		---@type rizu.IScoreSource
		local score_source = self.game.rhythm_engine.score_engine.scoreSource
		self.format = score_source.score_format
		self.multiplier = score_source.score_multiplier
		return score_source:getScore()
	end
	object.color = object.color or {1, 1, 1, 1}
	return self:add(object)
end

---@param object table?
---@return table
function PlayfieldVsrg:addAccuracy(object)
	object = object or {}
	object.subscreen = "gameplay"
	if not getmetatable(object) then
		object = ValueView(object)
	end
	function object:value()
		---@type rizu.IAccuracySource
		local accuracy_source = self.game.rhythm_engine.score_engine.accuracySource
		self.format = accuracy_source.accuracy_format
		self.multiplier = accuracy_source.accuracy_multiplier
		return accuracy_source:getAccuracy()
	end
	object.color = object.color or {1, 1, 1, 1}
	return self:add(object)
end

---@param object table?
---@return table
function PlayfieldVsrg:addCombo(object)
	object = object or {}
	object.subscreen = "gameplay"
	if not getmetatable(object) then
		object = ValueView(object)
	end
	function object:value()
		return self.game.rhythm_engine.score_engine.comboSource:getCombo()
	end
	object.color = object.color or {1, 1, 1, 1}
	return self:add(object)
end

---@param object table
---@return table
function PlayfieldVsrg:addJudgement(object)
	if not object.transform then
		object.transform = self:newLaneCenterTransform(1080)
	end
	local judgements = {}
	for _, judgement in ipairs(object.judgements) do
		local config = ImageAnimationView({
			x = object.x, y = object.y,
			w = object.w, h = object.h,
			sx = object.sx or object.scale, sy = object.sy or object.scale,
			ox = object.ox, oy = object.oy,
			transform = object.transform,
			image = judgement[2],
			range = judgement[3],
			quad = judgement[4],
			rate = judgement.rate or object.rate,
			cycles = judgement.cycles or object.cycles,
		})
		table.insert(judgements, config)
		self:add(config)
	end
	return self:add(JudgementView({
		judgements = judgements,
		subscreen = "gameplay",
		animate = object.animate,
		scale = object.scale
	}))
end

---@param object table
---@return table
function PlayfieldVsrg:addDeltaTimeJudgement(object)
	if not object.transform then
		object.transform = self:newLaneCenterTransform(1080)
	end
	local judgements = {}
	for i, judgement in ipairs(object.judgements) do
		if type(judgement) == "string" then
			judgement = {judgement}
		end
		if type(judgement) == "table" then
			local config = ImageAnimationView({
				x = object.x, y = object.y,
				w = object.w, h = object.h,
				sx = object.sx or object.scale, sy = object.sy or object.scale,
				ox = object.ox, oy = object.oy,
				transform = object.transform,
				image = judgement[1],
				range = judgement[2],
				quad = judgement[3],
				rate = judgement.rate or object.rate,
			})
			judgements[i] = config
			self:add(config)
		else
			judgements[i] = judgement
		end
	end
	return self:add(DeltaTimeJudgementView({
		judgements = judgements,
		subscreen = "gameplay",
	}))
end

---@param object table
function PlayfieldVsrg:addKeyImages(object)
	local noteskin = self.noteskin
	if not object.transform then
		object.transform = self:newNoteskinTransform()
	end
	for i = 1, noteskin.columnsCount do
		local pressed
		local released
		if object.pressed and object.pressed[i] then
			pressed = ImageView({
				x = noteskin.columns[i],
				y = noteskin.unit - object.padding,
				w = noteskin.width[i],
				h = object.h,
				sy = object.sy,
				oy = 1,
				transform = object.transform,
				image = object.pressed[i],
			})
		end
		if object.released and object.released[i] then
			released = ImageView({
				x = noteskin.columns[i],
				y = noteskin.unit - object.padding,
				w = noteskin.width[i],
				h = object.h,
				sy = object.sy,
				oy = 1,
				transform = object.transform,
				image = object.released[i],
			})
		end
		local key = InputView({
			column = i,
			inputs = noteskin:getColumnInputs(i),
			pressed = pressed,
			released = released,
		})
		self:add(pressed)
		self:add(released)
		self:add(key)
	end
end

---@param object table
function PlayfieldVsrg:addStaticKeyImages(object)
	local noteskin = self.noteskin
	if not object.transform then
		object.transform = self:newNoteskinTransform()
	end
	for i = 1, noteskin.columnsCount do
		if object.image and object.image[i] then
			local image = ImageView({
				x = noteskin.columns[i],
				y = noteskin.unit - object.padding,
				w = noteskin.width[i],
				h = object.h,
				sy = object.sy,
				oy = 1,
				transform = object.transform,
				image = object.image[i],
			})
			self:add(image)
		end
	end
end

---@param object table
function PlayfieldVsrg:addKeyImageAnimations(object)
	local noteskin = self.noteskin
	if not object.transform then
		object.transform = self:newNoteskinTransform()
	end
	for i = 1, noteskin.columnsCount do
		local pressed, hold, released
		local color = object.color and object.color[i]
		if object.pressed and object.pressed[i] then
			pressed = ImageAnimationView({
				x = noteskin.columns[i],
				y = noteskin.unit - object.padding,
				w = noteskin.width[i],
				h = object.h,
				sy = object.sy,
				oy = 1,
				transform = object.transform,
				image = object.pressed[i][1],
				range = object.pressed[i][2],
				quad = object.pressed[i][3],
				rate = object.rate,
				color = color,
			})
		end
		if object.hold and object.hold[i] then
			hold = ImageAnimationView({
				x = noteskin.columns[i],
				y = noteskin.unit - object.padding,
				w = noteskin.width[i],
				h = object.h,
				sy = object.sy,
				oy = 1,
				transform = object.transform,
				image = object.hold[i][1],
				range = object.hold[i][2],
				quad = object.hold[i][3],
				rate = object.rate,
				color = color,
			})
		end
		if object.released and object.released[i] then
			released = ImageAnimationView({
				x = noteskin.columns[i],
				y = noteskin.unit - object.padding,
				w = noteskin.width[i],
				h = object.h,
				sy = object.sy,
				oy = 1,
				transform = object.transform,
				image = object.released[i][1],
				range = object.released[i][2],
				quad = object.released[i][3],
				rate = object.rate,
				color = color,
			})
		end
		local key = InputAnimationView({
			column = i,
			inputs = noteskin:getColumnInputs(i),
			pressed = pressed,
			hold = hold,
			released = released,
		})
		self:add(pressed)
		self:add(hold)
		self:add(released)
		self:add(key)
	end
end

---@param object table
---@return table?
function PlayfieldVsrg:addColumnsBackground(object)
	if not object then
		return
	end
	if not object.transform then
		object.transform = self:newNoteskinTransform()
	end
	local noteskin = self.noteskin
	local rectangles = {}
	for i = 1, noteskin.columnsCount do
		local color = object.color[i]
		if type(object.color[1]) == "number" then
			color = object.color
		end
		table.insert(rectangles, {
			color = color,
			mode = "fill",
			lineStyle = "rough",
			lineWidth = 1,
			x = noteskin.columns[i],
			y = 0,
			w = noteskin.width[i],
			h = noteskin.unit,
			rx = 0,
			ry = 0
		})
	end
	return self:add(RectangleView({
		transform = object.transform,
		rectangles = rectangles
	}))
end

---@param bw number
---@param noteskin sphere.NoteSkinVsrg
---@param i number
---@param inputs number
---@return number
local function getGuidelineX(bw, noteskin, i, inputs)
	if bw < 0 then
		if i <= inputs then
			return noteskin.columns[i]
		else
			return noteskin.columns[inputs] + noteskin.width[inputs] + noteskin.space[i]
		end
	elseif bw > 0 then
		if i <= inputs then
			return noteskin.columns[i] - noteskin.space[i]
		else
			return noteskin.columns[inputs] + noteskin.width[inputs]
		end
	end
end

---@param object table?
function PlayfieldVsrg:addGuidelines(object)
	if not object then
		return
	end
	if not object.transform then
		object.transform = self:newNoteskinTransform()
	end
	local noteskin = self.noteskin
	local columns = noteskin.columnsCount
	for i = 1, columns + 1 do
		local bw = object.w and object.w[i]
		local bh = object.h and object.h[i]
		local by = object.y and object.y[i]

		if bw and bh and by and bw ~= 0 and bh ~= 0 then
			local color = object.color and object.color[i]
			if not color or type(color) == "number" then
				color = object.color
			end

			local lbw = bw
			if object.mode == "symmetric" and i > columns / 2 + 1 then
				lbw = -bw
			end

			self:add(ImageView({
				x = getGuidelineX(bw, noteskin, i, columns),
				y = by,
				w = lbw,
				h = bh,
				transform = object.transform,
				image = object.image[i],
				color = color,
			}))
			if object.both and noteskin.space[i] ~= 0 then
				local rbw = bw
				if object.mode == "symmetric" and i > columns / 2 then
					rbw = -bw
				end
				self:add(ImageView({
					x = getGuidelineX(-bw, noteskin, i, columns),
					y = by,
					w = rbw,
					h = bh,
					transform = object.transform,
					image = object.image[i],
					color = color,
				}))
			end
		end
	end
end

---@param object table?
---@return table?
function PlayfieldVsrg:addHitError(object)
	if not object then
		return
	end
	object.subscreen = "gameplay"
	object.transform = object.transform or self:newLaneCenterTransform(1080)
	object.count = object.count or 1
	object.unit = object.unit or 0.16
	return self:add(HitErrorView(object))
end

---@return table
function PlayfieldVsrg:addMatchPlayers()
	local object = {}
	object.subscreen = "gameplay"
	object.transform = self:newTransform(1920, 1080, "left")
	function object:draw()
		local gfx_util = require("gfx_util")
		love.graphics.replaceTransform(gfx_util.transform(self.transform))
		love.graphics.translate(20, 540)
		MatchPlayersView.game = self.game
		MatchPlayersView:draw()
	end

	return self:add(object)
end

---@param covers table?
---@param x number?
---@param w number?
function PlayfieldVsrg:addLaneCovers(covers, x, w)
	if not covers then
		return
	end
	if covers.top.enabled then
		self:addLaneCover({
			x = x,
			w = w,
			position = covers.top.position,
			size = covers.top.size,
			isBottom = false,
		})
	end
	if covers.bottom.enabled then
		self:addLaneCover({
			x = x,
			w = w,
			position = covers.bottom.position,
			size = covers.bottom.size,
			isBottom = true,
		})
	end
end

---@param object table
---@return table?
function PlayfieldVsrg:addLaneCover(object)
	local noteskin = self.noteskin
	local unit = noteskin.unit
	if not unit then
		return
	end

	local gfx_util = require("gfx_util")

	object = object or {}
	object.transform = self:newNoteskinTransform()
	object.mesh = gfx_util.newGradient("vertical", {0, 0, 0, 1}, {0, 0, 0, 0})

	object.position = object.position or unit / 2
	object.size = object.size or 20

	object.x = object.x or noteskin.baseOffset
	object.w = object.w or noteskin.fullWidth

	function object:draw()
		love.graphics.replaceTransform(gfx_util.transform(self.transform))
		love.graphics.translate(object.x, 0)
		love.graphics.setColor(0, 0, 0, 1)

		local p, g = self.position, self.size

		if not self.isBottom then
			love.graphics.rectangle("fill", 0, 0, object.w, p - g)
			love.graphics.draw(self.mesh, 0, p - g, 0, object.w, g)
		else
			love.graphics.draw(self.mesh, 0, p + g, 0, object.w, -g)
			love.graphics.rectangle("fill", 0, p + g, object.w, unit - p + g)
		end
	end

	return self:add(object)
end

return PlayfieldVsrg
