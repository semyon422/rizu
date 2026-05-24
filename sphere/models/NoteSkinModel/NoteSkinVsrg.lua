local NoteSkin = require("sphere.models.NoteSkinModel.NoteSkin")

---@class sphere.NoteSkinVsrg: sphere.NoteSkin
---@operator call: sphere.NoteSkinVsrg
local NoteSkinVsrg = NoteSkin + {}

---@param columns table
function NoteSkinVsrg:setColumns(columns)
	self.columns = columns

	if columns.inputs then
		local t = {}
		for _, d in pairs(columns.inputs) do
			local input, column = unpack(d)
			t[input] = t[input] or {}
			table.insert(t[input], column)
		end
		self.input_to_columns = t
	end

	self.autoColumnsCount = columns.count or self.autoColumnsCount
	self.columnsCount = self.autoColumnsCount
	local cc = self.columnsCount

	assert(columns.width, "columns.width is required")
	assert(#columns.width == cc, "table columns.width should contain " .. cc .. " values")

	assert(columns.space or columns.position, "either columns.space or columns.position is required")
	assert(not (columns.space and columns.position), "columns.space and columns.position are mutually exclusive")
	if columns.space then
		assert(#columns.space == cc + 1, "table columns.space should contain " .. cc + 1 .. " values")
	elseif columns.position then
		columns.space = self:xwToSpace(columns.position, columns.width)
	end

	self.offset = columns.offset
	self.align = columns.align
	self.width = columns.width
	self.space = columns.space
	self.upscroll = columns.upscroll

	local fullWidth = 0
	for j = 1, #columns.width do
		fullWidth = fullWidth + columns.width[j]
	end
	for j = 1, #columns.space do
		fullWidth = fullWidth + columns.space[j]
	end
	self.fullWidth = fullWidth

	local offset
	if columns.align == "left" then
		offset = columns.offset
	elseif columns.align == "right" then
		offset = columns.offset - fullWidth
	else
		offset = columns.offset - fullWidth / 2
	end
	self.baseOffset = offset
	self.columnsOffset = columns.offset

	local x = {}
	for i = 1, #columns.width do
		offset = offset + columns.space[i]
		x[i] = offset
		offset = offset + columns.width[i]
	end
	self.columns = x
end

---@param inputs table
function NoteSkinVsrg:setInput(inputs)
	local input_to_columns = {
		key1 = {3, 4},
	}
	for i, input in ipairs(inputs) do
		input_to_columns[input] = {i} -- table of values here because of split stages
	end
	self.input_to_columns = input_to_columns
	self.autoColumnsCount = #inputs
	self.columnsCount = #inputs
end

---@param column chart.Column
---@return number?
function NoteSkinVsrg:getInputColumn(column)
	return self.input_to_columns[column][1]
end

---@param column number
---@param split boolean?
---@return table
function NoteSkinVsrg:getColumnInputs(column, split)
	column = (column - 1) % self.columnsCount + 1

	local inputs = {}
	for input, columns in pairs(self.input_to_columns) do
		for _, _column in pairs(columns) do
			if _column == column then
				table.insert(inputs, input)
			end
		end
	end

	return inputs
end

---@param column number
---@return string
---@return number
function NoteSkinVsrg:getFirstColumnInput(column)
	local input = self:getColumnInputs(column)[1]
	return input
end

local colors = {
	transparent = {1, 1, 1, 0},
	clear = {1, 1, 1, 1},
	missed = {0.5, 0.5, 0.5, 1},
	passed = {1, 1, 1, 0},
	startMissed = {0.5, 0.5, 0.5, 1},
	startMissedPressed = {0.75, 0.75, 0.75, 1},
	startPassedPressed = {1, 1, 1, 1},
	endPassed = {1, 1, 1, 1},
	endMissed = {0.5, 0.5, 0.5, 1},
	endMissedPassed = {0.5, 0.5, 0.5, 1},
}
NoteSkinVsrg.colors = colors

---@param timeState table
---@param noteView sphere.NoteView
---@param column number
---@return table
function NoteSkinVsrg.color(timeState, noteView, column)
	local visual_note = noteView.graphicalNote

	local state = visual_note:getState()
	if state == "clear" or state == "skipped" then
		return colors.clear
	elseif state == "missed" then
		return colors.missed
	elseif state == "passed" then
		return colors.passed
	end

	if visual_note.start_dt <= visual_note.end_dt then
		return colors.transparent
	elseif colors[state] then
		return colors[state]
	end

	return colors.clear
end

local bufferColor = {0, 0, 0, 0}

---@param source table
---@param color table|function
---@return table
function NoteSkinVsrg:multiplyColors(source, color)
	if type(color) == "function" then
		color = color()
	end
	for i = 1, 4 do
		bufferColor[i] = (source[i] or 1) * (color[i] or 1)
	end
	return bufferColor
end

---@param x table
---@param w table
---@return table
function NoteSkinVsrg:xwToSpace(x, w)
	local s = {}
	local sum = 0
	for i = 1, #w do
		s[i] = x[i] - sum
		sum = sum + w[i] + s[i]
	end
	s[#s + 1] = 0
	return s
end

---@param a table
---@param deltaTime number
---@return number?
local function getFrame(a, deltaTime)
	if not a.range then
		return
	end
	return math.floor(deltaTime * a.rate) % a.frames * (a.range[2] - a.range[1]) / (a.frames - 1) + a.range[1]
end

---@param time number
---@return number
function NoteSkinVsrg:getTimePosition(time)
	return self.hitposition + self.unit * time
end

---@param pos number
---@return number
function NoteSkinVsrg:getInverseTimePosition(pos)
	return (pos - self.hitposition) / self.unit
end

---@param timeState table
---@param noteView sphere.NoteView
---@param column number
---@return number
function NoteSkinVsrg:getPosition(timeState, noteView, column)
	return self:getTimePosition(timeState.dt)
	-- if self.editor then
	-- 	return self:getTimePosition(timeState.scaledAbsoluteDeltaTime)
	-- end
	-- return self:getTimePosition(timeState.scaledFakeVisualDeltaTime or timeState.scaledVisualDeltaTime)
end

---@param mx number
---@return number?
function NoteSkinVsrg:getInverseColumnPosition(mx)
	for i = 1, self.columnsCount do
		local Head = self.notes.ShortNote.Head
		local x, w = Head.x[i], Head.w[i]
		if w < 0 then
			x, w = x + w, -w
		end
		if x <= mx and mx < x + w then
			return i
		end
	end
end

---@param params table
---@param noteType string?
function NoteSkinVsrg:setShortNote(params, noteType)
	local h = params.h or 0
	local height = {}
	for i = 1, self.columnsCount do
		height[i] = h
	end

	local image = params.image
	if type(params.image) ~= "table" then
		image = {}
		for i = 1, self.columnsCount do
			image[i] = params.image
		end
	end

	local color = {}
	for i = 1, self.columnsCount do
		color[i] = params.color or self.color
	end

	local oy = {}
	for i = 1, self.columnsCount do
		oy[i] = 1
	end

	noteType = noteType or "ShortNote"
	self.notes[noteType] = {
		Head = {
			x = self.columns,
			y = function(...) return self:getPosition(...) end,
			w = self.width,
			h = height,
			sx = {},
			sy = {},
			ox = {},
			oy = oy,
			r = {},
			color = color,
			image = image,
		}
	}
end

---@param params table
function NoteSkinVsrg:setLongNote(params)
	local h = params.h or 0
	local headHeight = {}
	local tailHeight = {}
	for i = 1, self.columnsCount do
		headHeight[i] = h
		tailHeight[i] = h
	end

	local tail = params.tail
	if type(params.tail) ~= "table" then
		tail = {}
		for i = 1, self.columnsCount do
			tail[i] = params.tail
		end
	end
	local body = params.body
	if type(params.body) ~= "table" then
		body = {}
		for i = 1, self.columnsCount do
			body[i] = params.body
		end
	end
	local head = params.head
	if type(params.head) ~= "table" then
		head = {}
		for i = 1, self.columnsCount do
			head[i] = params.head
		end
	end
	local style = params.style
	if type(params.style) ~= "table" then
		style = {}
		for i = 1, self.columnsCount do
			style[i] = params.style
		end
	end

	local color = {}
	for i = 1, self.columnsCount do
		color[i] = self.color
	end

	local headOy = {}
	local tailOy = {}
	for i = 1, self.columnsCount do
		headOy[i] = 1
		tailOy[i] = 1
	end
	local bh = {}
	for i = 1, self.columnsCount do
		bh[i] = 0
	end

	local Head = {
		x = self.columns,
		y = function(...) return self:getPosition(...) end,
		w = self.width,
		h = headHeight,
		sx = {},
		sy = {},
		ox = {},
		oy = headOy,
		r = {},
		color = color,
		image = head,
	}

	local Tail = {
		x = self.columns,
		y = function(...) return self:getPosition(...) end,
		w = self.width,
		h = tailHeight,
		sx = {},
		sy = {},
		ox = {},
		oy = tailOy,
		r = {},
		color = color,
		image = tail,
	}

	local Body = {
		x = self.columns,
		y = function(...) return self:getPosition(...) - h / 2 end,
		w = self.width,
		h = bh,
		sx = {},
		sy = {},
		ox = {},
		oy = {},
		color = color,
		image = body,
		scale = params.scale,
		style = style,
	}

	self.notes.LongNote = {
		Head = Head,
		Tail = Tail,
		Body = Body,
	}
end

local bmsLayers = {
	0x04,
	-- 0x06,
	0x07,
	0x0A,
	-- 0x0B,
	-- 0x0C,
	-- 0x0D,
	-- 0x0E,
}

---@param params table?
function NoteSkinVsrg:addBga(params)
	local imageHead = {
		x = {},
		y = {},
		w = {},
		h = {},
		color = {},
	}
	local videoHead = {
		x = {},
		y = {},
		w = {},
		h = {},
		color = {},
	}
	self.notes.ImageNote = {Head = imageHead}
	self.notes.VideoNote = {Head = videoHead}

	for _, head in ipairs({imageHead, videoHead}) do
		for _, inputIndex in ipairs(bmsLayers) do
			self:addImageNote(head, "bmsbga" .. inputIndex, params)
		end
	end
end

---@param input string
---@param index number?
---@return number
function NoteSkinVsrg:setInputListIndex(input, index)
	local input_to_columns = self.input_to_columns
	index = index or 1

	local i = input_to_columns[input] and input_to_columns[input][index]
	if not i then
		self.autoColumnsCount = self.autoColumnsCount + 1
		i = self.autoColumnsCount
		input_to_columns[input] = input_to_columns[input] or {}
		input_to_columns[input][index] = i
	end
	return i
end

---@param head table
---@param input string
---@param params table
---@param index number?
function NoteSkinVsrg:addImageNote(head, input, params, index)
	local i = self:setInputListIndex(input, index)

	head.x[i] = params.x or 0
	head.y[i] = params.y or 0
	head.w[i] = params.w or 1
	head.h[i] = params.h or 1
	head.color[i] = params.color or colors.clear
end

---@param params table
---@param index number?
function NoteSkinVsrg:addMeasureLine(params, index)
	local i = self:setInputListIndex("measure1", index)

	if not self.notes.SoundNote then
		self:setShortNote({}, "SoundNote")
	end

	local Head = self.notes.SoundNote.Head
	Head.x[i] = params.x or self.baseOffset
	Head.w[i] = params.w or self.fullWidth
	Head.h[i] = params.h
	Head.ox[i] = 0
	Head.oy[i] = 1
	Head.r[i] = 0
	Head.color[i] = params.color
	Head.image[i] = params.image
end

---@param params table
function NoteSkinVsrg:setLighting(params)
	if params.range then
		params.frames = math.abs(params.range[2] - params.range[1]) + 1
	else
		params.frames = 1
	end
	local note = {
		Head = {
			x = function(_, _, column) return self.columns[column] + self.width[column] / 2 end,
			y = self.hitposition + params.offset,
			sx = params.scale,
			sy = params.scale,
			ox = 0.5,
			oy = 0.5,
			r = 0,
			color = function() return colors.clear end,
			image = function(timeState, noteView)
				local pressedTime = noteView.graphicalNote:getPressedTime()
				if not pressedTime then
					return
				end
				local deltaTime = timeState.currentTime - pressedTime
				if not params.long and deltaTime >= params.frames / params.rate then
					return
				end
				return params.image, getFrame(params, deltaTime)
			end,
		}
	}
	if not params.long then
		self.notes.ShortNoteLighting = note
	else
		self.notes.LongNoteLighting = note
	end
end

---@param animations table
---@param timeState table
---@return table?
---@return number?
local function getAnimation(animations, timeState)
	local beforeStart = animations.beforeStart
	local afterStart = animations.afterStart
	local between = animations.between
	local beforeEnd = animations.beforeEnd
	local afterEnd = animations.afterEnd

	local currentTime = timeState.currentTime
	local startTime = timeState.absoluteTime

	local endTime
	if timeState.endTimeState then
		endTime = timeState.endTimeState.absoluteTime
	else
		endTime = math.huge
		between = nil
		beforeEnd = nil
		afterEnd = nil
	end

	local bs = currentTime - startTime < 0
	local as = currentTime - startTime > 0
	local be = currentTime - endTime < 0
	local ae = currentTime - endTime > 0
	if beforeStart then
		bs = (currentTime - startTime) * beforeStart.rate < -beforeStart.frames
	end
	if afterStart then
		as = (currentTime - startTime) * afterStart.rate > afterStart.frames
	end
	if beforeEnd then
		be = (currentTime - endTime) * beforeEnd.rate < -beforeEnd.frames
	end
	if afterEnd then
		ae = (currentTime - endTime) * afterEnd.rate > afterEnd.frames
	end

	-- check < <= > >=
	local animation
	if bs or ae then
		animation = nil
	elseif beforeStart and (currentTime - startTime) * beforeStart.rate < 0 then
		animation = beforeStart
	elseif afterStart and (currentTime - startTime) * afterStart.rate < math.min(afterStart.frames, (endTime - startTime) / 2) then
		animation = afterStart
	elseif between and as and be then
		animation = between
	elseif beforeEnd and (currentTime - endTime) * beforeStart.rate < 0 then
		animation = beforeEnd
	elseif afterEnd and (currentTime - endTime) * beforeStart.rate < afterEnd.frames then
		animation = afterEnd
	end

	local time
	if animation == beforeStart or animation == afterStart then
		time = startTime
	elseif animation == between then
		time = startTime - afterStart.frames / afterStart.rate
	elseif animation == beforeEnd or animation == afterEnd then
		time = endTime
	end

	if not animation then
		return
	end

	return animation, currentTime - time
end

---@param animations table
---@param timeState table
---@return string?
---@return number?
local function getAnimationImage(animations, timeState)
	local animation, deltaTime = getAnimation(animations, timeState)
	if not animation then
		return
	end
	return animation.image, getFrame(animation, deltaTime)
end

---@param params table
function NoteSkinVsrg:setAnimation(params)
	params.frames = math.abs(params.range[2] - params.range[1]) + 1
	local note = {
		Head = {
			x = function(timeState, _, column) return self.columns[column] + getAnimation(params.animations, timeState).x end,
			y = function(timeState) return self.hitposition + getAnimation(timeState).y end,
			w = function(timeState) return getAnimation(timeState).w end,
			h = function(timeState) return getAnimation(timeState).h end,
			ox = 0,
			oy = 0,
			r = 0,
			color = function() return colors.clear end,
			image = function(timeState)
				return getAnimationImage(params.animations, timeState)
			end,
		}
	}
	if not params.long then
		self.notes.ShortNoteAnimation = note
	else
		self.notes.LongNoteAnimation = note
	end
end

return NoteSkinVsrg
