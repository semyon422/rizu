local class = require("class")
local PlayfieldRenderer = require("rizu.gameplay.views.PlayfieldRenderer")
local path_util = require("path_util")
local Snap = require("chart.model.convert.Snap")
local IniParser = require("rizu.skin.IniParser")
local InputMode = require("chart.core.InputMode")

local lg = love.graphics

---@class rizu.gameplay.views.StepmaniaRenderer : rizu.gameplay.views.PlayfieldRenderer
---@operator call: rizu.gameplay.views.StepmaniaRenderer
---@field directory_path string
---@field input_mode string
---@field screen rizu.skin.Screen
---@field images {[string]: love.Image}
---@field elements {[string]: {image: love.Image?, actor: table?}}
---@field files {[string]: string}
---@field scripts {[string]: string}
---@field timing_chart chart.Chart?
---@field timing_points chart.AbsolutePoint[]?
---@field grids {[string]: {columns: integer, rows: integer}}
---@field note_color_frames {[string]: boolean}
---@field receptor_pulse {from: number, to: number, duration: number}?
---@field receptor_press_states boolean[]
---@field receptor_pulse_times number[]
---@field hold_body_start_offset number
---@field hold_body_end_offset number
---@field note_skin table?
---@field snap chart.Snap
---@field loaded boolean
local StepmaniaRenderer = PlayfieldRenderer + {}

local directions = {
	[4] = {"Left", "Down", "Up", "Right"},
	[7] = {"Key1", "Key2", "Key3", "Key4", "Key5", "Key6", "Key7"},
}
local rotations = {Left = math.pi / 2, Down = 0, Up = math.pi, Right = -math.pi / 2}

local function key(name)
	return name:lower():gsub("%.[^%.]+$", ""):gsub(" %d+x%d+$", "")
end

---@param game sphere.GameController
---@param directory_path string
---@param input_mode string
---@param screen rizu.skin.Screen
function StepmaniaRenderer:new(game, directory_path, input_mode, screen)
	PlayfieldRenderer.new(self, game)
	self.directory_path = directory_path
	self.input_mode = input_mode
	self.screen = screen
	self.images = {}
	self.elements = {}
	self.files = {}
	self.scripts = {}
	self.timing_chart = nil
	self.timing_points = nil
	self.grids = {}
	self.note_color_frames = {}
	self.receptor_pulse = nil
	self.receptor_press_states = {}
	self.receptor_pulse_times = {}
	self.hold_body_start_offset = 0
	self.hold_body_end_offset = 0
	self.note_skin = nil
	self.columns = assert(tonumber(input_mode:match("^(%d+)key$")), "StepMania skins require a key input mode")
	self.input_map = InputMode(input_mode):getInputMap()
	self.directions = assert(directions[self.columns], "unsupported StepMania keymode: " .. input_mode)
	self.snap = Snap()
	self.loaded = false
end

---@param button string
---@param element string
---@return {button: string, element: string}
local function note_skin_path(button, element)
	return {button = button, element = element}
end

-- NoteSkin.lua is StepMania Lua, not ordinary Lua. Execute only its resolver
-- in an empty environment with the small actor API used to select assets.
function StepmaniaRenderer:loadNoteSkin()
	local source = self.game.fs:read(path_util.join(self.directory_path, "NoteSkin.lua"))
		or self.game.fs:read(path_util.join(self.directory_path, "Noteskin.lua"))
	if not source then return end
	local variables = {}
	local env = {
		Var = function(name) return variables[name] end,
		NOTESKIN = {GetPath = function(_, button, element) return note_skin_path(button, element) end},
		LoadActor = function(path) return path end,
		Def = setmetatable({}, {__index = function() return function(actor) return actor end end}),
		string = string,
		table = table,
		math = math,
		pairs = pairs,
		ipairs = ipairs,
		type = type,
		tonumber = tonumber,
		tostring = tostring,
		select = select,
	}
	local chunk = loadstring(source, "@" .. self.directory_path .. "/NoteSkin.lua")
	if not chunk then return end
	setfenv(chunk, env)
	local ok, skin = pcall(chunk)
	if ok and type(skin) == "table" and type(skin.Load) == "function" then
		self.note_skin = skin
		self.note_skin_variables = variables
	end
end

function StepmaniaRenderer:load()
	if self.loaded then return end
	self.loaded = true
	for _, name in ipairs(self.game.fs:getDirectoryItems(self.directory_path)) do
		local path = path_util.join(self.directory_path, name)
		local info = self.game.fs:getInfo(path)
		if info and info.type == "file" then
			local file_key = key(name)
			if name:lower():match("%.png$") then
				self.files[file_key] = path
				local columns, rows = name:match(" (%d+)x(%d+)%.png$")
				if columns and rows then
					self.grids[file_key] = {columns = tonumber(columns), rows = tonumber(rows)}
				end
			elseif name:lower():match("%.lua$") then
				self.scripts[file_key] = path
			end
		end
	end
	self:loadNoteSkin()
	local metrics = IniParser.parse(self.game.fs:read(path_util.join(self.directory_path, "metrics.ini")) or "")
	local note_display = metrics.NoteDisplay or {}
	for part, spacing in pairs(note_display) do
		local name = part:match("^(%a+)NoteColorTextureCoordSpacingY$")
		if name and tonumber(spacing) ~= 0 then
			self.note_color_frames[name] = true
		end
	end
	self.hold_body_start_offset = tonumber(note_display.StartDrawingHoldBodyOffsetFromHead) or 0
	self.hold_body_end_offset = tonumber(note_display.StopDrawingHoldBodyOffsetFromTail) or 0
	local receptor_command = (metrics.ReceptorArrow or {}).NoneCommand or ""
	local from, duration, to = receptor_command:match("zoom%s*,%s*([%d%.%-]+)%s*;%s*linear%s*,%s*([%d%.]+)%s*;%s*zoom%s*,%s*([%d%.%-]+)")
	if from and duration and to then
		self.receptor_pulse = {from = tonumber(from), duration = tonumber(duration), to = tonumber(to)}
	end
end

function StepmaniaRenderer:unload()
	self.images = {}
	self.elements = {}
	self.files = {}
	self.scripts = {}
	self.timing_chart = nil
	self.timing_points = nil
	self.grids = {}
	self.note_color_frames = {}
	self.receptor_pulse = nil
	self.receptor_press_states = {}
	self.receptor_pulse_times = {}
	self.hold_body_start_offset = 0
	self.hold_body_end_offset = 0
	self.note_skin = nil
	self.note_skin_variables = nil
	self.loaded = false
end

---@param name string
---@return love.Image?
function StepmaniaRenderer:getImage(name)
	local image = self.images[name]
	if image then return image end
	local path = self.files[key(name)]
	if not path then return end
	local source = self.game.fs:read(path)
	if not source then return end
	local ok, data = pcall(love.filesystem.newFileData, source, path)
	if not ok then return end
	ok, image = pcall(lg.newImage, data)
	if not ok then return end
	image:setFilter("linear", "linear")
	image:setWrap("clamp", "repeat")
	self.images[name] = image
	return image
end

---@param image love.Image
---@param columns integer
---@param rows integer
---@param frame integer
---@return love.Quad
local function frame_quad(image, columns, rows, frame)
	local width, height = image:getDimensions()
	local column = frame % columns
	local row = math.floor(frame / columns) % rows
	return lg.newQuad(column * width / columns, row * height / rows, width / columns, height / rows, width, height)
end

---@param image love.Image
---@param x number
---@param y number
---@param width number
---@param height number
---@param frame integer?
---@param columns integer?
---@param rows integer?
---@param rotation number?
---@param flip_y boolean?
local function draw_image(image, x, y, width, height, frame, columns, rows, rotation, flip_y)
	local image_width, image_height = image:getDimensions()
	columns, rows = columns or 1, rows or 1
	local frame_width, frame_height = image_width / columns, image_height / rows
	local quad = frame_quad(image, columns, rows, frame or 0)
	local sy = height / frame_height
	-- LÖVE applies the origin before scaling, so it must be in source-pixel
	-- coordinates. This keeps actor zoom and rotation centered on the receptor.
	lg.draw(image, quad, x, y, rotation or 0, width / frame_width, flip_y and -sy or sy, frame_width / 2, frame_height / 2)
end

-- StepMania hold bodies repeat their texture; scaling one image across the
-- entire hold distorts its pattern. x/y denote the body's first endpoint.
local function draw_hold_body(image, x, a, b, width)
	local image_width, image_height = image:getDimensions()
	local scale = width / image_width
	local y, height = math.min(a, b), math.abs(b - a)
	if height == 0 then return end
	local quad = lg.newQuad(0, 0, image_width, height / scale, image_width, image_height)
	lg.draw(image, quad, x - width / 2, y, 0, scale, scale)
end

---@param column integer
---@return string
function StepmaniaRenderer:getDirection(column)
	return self.directions[(column - 1) % #self.directions + 1]
end

---@param direction string
---@param element string
---@return string button
---@return string resolved_element
function StepmaniaRenderer:resolveElement(direction, element)
	local skin, variables = self.note_skin, self.note_skin_variables
	if skin and variables then
		variables.Button, variables.Element, variables.SpriteOnly = direction, element, false
		local ok, path = pcall(skin.Load)
		if ok and type(path) == "table" and type(path.button) == "string" and type(path.element) == "string" then
			return path.button, path.element
		end
	end
	return direction, element
end

-- Execute the small actor scripts that NoteSkins use to compose elements.
-- We only need their Texture fields, so unsupported actor commands remain inert.
---@param path {button: string, element: string}
---@param depth integer?
---@return {button: string, element: string}?
function StepmaniaRenderer:getActorTexture(path, depth)
	if (depth or 0) >= 16 then return end
	local source_path = self.scripts[key(path.button .. " " .. path.element)]
	if not source_path then
		if self.files[key(path.button .. " " .. path.element)] then return path end
		return
	end
	local source = self.game.fs:read(source_path)
	if not source then return end

	local variables = self.note_skin_variables
	local function load_actor(actor_path, ...)
		local texture, actor
		if type(actor_path) == "table" then
			texture, actor = self:getActorTexture(actor_path, (depth or 0) + 1)
		end
		if texture then return actor or {Texture = texture} end
		for i = 1, select("#", ...) do
			local actor = select(i, ...)
			if type(actor) == "table" and type(actor.Texture) == "table" then return actor end
		end
	end
	local env = {
		Var = function(name) return variables and variables[name] end,
		NOTESKIN = {
			GetPath = function(_, button, element) return note_skin_path(button, element) end,
			LoadActor = function(_, button, element)
				local resolved_button, resolved_element = self:resolveElement(button, element)
				return load_actor(note_skin_path(resolved_button, resolved_element))
			end,
		},
		LoadActor = load_actor,
		Def = setmetatable({}, {__index = function() return function(actor) return actor end end}),
		string = string,
		table = table,
		math = math,
		pairs = pairs,
		ipairs = ipairs,
		type = type,
		tonumber = tonumber,
		tostring = tostring,
		select = select,
	}
	local chunk = loadstring(source, "@" .. source_path)
	if not chunk then return end
	setfenv(chunk, env)
	local ok, actor = pcall(chunk)
	if not ok or type(actor) ~= "table" then return end
	local texture = actor.Texture
	if type(texture) == "table" then
		local resolved_texture, resolved_actor = self:getActorTexture(texture, (depth or 0) + 1)
		return resolved_texture, resolved_actor
	end
	return texture, actor
end

---@param direction string
---@param element string
---@return love.Image?
---@return table?
function StepmaniaRenderer:getElementActor(direction, element)
	local cache_key = direction .. "\0" .. element
	local cached = self.elements[cache_key]
	if cached then return cached.image, cached.actor end

	local button, resolved_element = self:resolveElement(direction, element)
	local texture, actor = self:getActorTexture(note_skin_path(button, resolved_element))
	local image
	if texture then
		image = self:getImage(texture.button .. " " .. texture.element)
	else
		image = self:getImage(button .. " " .. resolved_element)
			or self:getImage("_" .. button .. " " .. resolved_element)
			or self:getImage("Down " .. resolved_element)
			or self:getImage("_Down " .. resolved_element)
	end
	self.elements[cache_key] = {image = image, actor = actor}
	return image, actor
end

---@param direction string
---@param element string
---@return love.Image?
function StepmaniaRenderer:getElement(direction, element)
	return self:getElementActor(direction, element)
end

---@param image love.Image
---@return integer columns
---@return integer rows
function StepmaniaRenderer:getGrid(image)
	for name, cached in pairs(self.images) do
		if cached == image then
			local grid = self.grids[key(name)]
			if grid then return grid.columns, grid.rows end
			break
		end
	end
	return 1, 1
end

---@param beat number
---@return integer
function StepmaniaRenderer:getColorFrameFromBeat(beat)
	local denom = self.snap:bestDenom(beat % 1)
	local frames = {[1] = 0, [2] = 1, [3] = 2, [4] = 3, [6] = 4, [8] = 5, [12] = 6, [16] = 7}
	return frames[denom] or 7
end

---@param note rizu.VisualNote
---@return integer
function StepmaniaRenderer:getColorFrame(note)
	return self:getColorFrameFromBeat(note.linked_note.startNote:getBeatModulo())
end

---@param part string
---@param note rizu.VisualNote
---@return integer
function StepmaniaRenderer:getFrame(part, note)
	if self.note_color_frames[part] then
		return self:getColorFrame(note)
	end
	return 0
end

---@param note rizu.VisualNote
---@return integer?
function StepmaniaRenderer:getColumn(note)
	return self.input_map[note:getColumn()]
end

---@param note rizu.VisualNote
---@return boolean
function StepmaniaRenderer:isLongNoteVisible(note)
	local state = note:getState()
	if state:find("^end") then
		return false
	end

	-- Our scoring may not transition a held LN to an end state immediately.
	-- StepMania removes it when its tail reaches the current absolute time.
	return state ~= "startPassedPressed"
		or note.linked_note:getEndTime() > note.cvp.point.absoluteTime
end

---@param note rizu.VisualNote
---@return boolean
function StepmaniaRenderer:isNoteVisible(note)
	if note.type == "long" then
		return self:isLongNoteVisible(note)
	end
	return note:getState() == "clear"
end

---@param note rizu.VisualNote
---@return boolean
function StepmaniaRenderer:isNoteHeadVisible(note)
	if note.type == "long" then
		return self:isLongNoteVisible(note)
	end
	return note:getState() == "clear"
end

---@param note rizu.VisualNote
---@return boolean
function StepmaniaRenderer:isNoteHeadHeld(note)
	return note.type == "long" and note:getState() == "startPassedPressed"
end

---@param note rizu.VisualNote
---@return "Active"|"Inactive"
function StepmaniaRenderer:getHoldState(note)
	return self:isNoteHeadHeld(note) and "Active" or "Inactive"
end

---@param note rizu.VisualNote
---@param y number
---@param receptor_y number
---@return number
function StepmaniaRenderer:clampHeldNoteY(note, y, receptor_y)
	if self:isNoteHeadHeld(note) then
		return math.min(receptor_y, y)
	end
	return y
end

---@param note rizu.VisualNote
---@param y number
---@param receptor_y number
---@return number
function StepmaniaRenderer:clampHeldTailY(note, y, receptor_y)
	if self:isNoteHeadHeld(note) then
		-- Tail sprites are centered on their position. Cap their center half a
		-- receptor above the target so their lower edge stays at the receptor.
		return math.min(receptor_y, y)
	end
	return y
end

---@param notes rizu.VisualNote[]
---@param columns integer
---@param time_scale number
---@param receptor_y number
function StepmaniaRenderer:drawNotes(notes, columns, time_scale, receptor_y)
	-- Hold bodies are behind heads and receptors, matching NoteDisplay's normal layering.
	for _, note in ipairs(notes) do
		if note.type == "long" and self:isNoteVisible(note) then
			local column = self:getColumn(note)
			if column and column <= columns then
				local x = (column - 0.5) * 64
				local head_y = self:clampHeldNoteY(note, receptor_y + note.start_dt * time_scale, receptor_y)
				-- A held LN is fully capped at the receptor once its tail reaches it.
				-- The game resolves it at that point, matching Etterna's display.
				local tail_y = self:clampHeldTailY(note, receptor_y + note.end_dt * time_scale, receptor_y)
				local direction = tail_y >= head_y and 1 or -1
				local body_start = head_y + direction * self.hold_body_start_offset
				local body_end = tail_y + direction * self.hold_body_end_offset
				local note_direction = self:getDirection(column)
				local hold_state = self:getHoldState(note)
				local body = self:getElement(note_direction, "Hold Body " .. hold_state)
				if body then draw_hold_body(body, x, body_start, body_end, 64) end
				local cap = self:getElement(note_direction, "Hold BottomCap " .. hold_state)
				if cap then
					local cap_width, cap_height = cap:getDimensions()
					local height = cap_height * 64 / cap_width
					draw_image(cap, x, body_end + direction * height / 2, 64, height, nil, nil, nil, nil, true)
				end
				local tail = self:getElement(note_direction, "Hold Tail " .. hold_state)
				if tail then
					local tail_columns, tail_rows = self:getGrid(tail)
					draw_image(tail, x, tail_y, 64, 64, 0, tail_columns, tail_rows, rotations[note_direction])
				end
			end
		end
	end
	for _, note in ipairs(notes) do
		local column = self:getColumn(note)
		if self:isNoteHeadVisible(note) then
		if column and column <= columns then
			local x = (column - 0.5) * 64
			local y = self:clampHeldNoteY(note, receptor_y + note.start_dt * time_scale, receptor_y)
			local direction = self:getDirection(column)
			local part = note.type == "long" and "HoldHead" or "TapNote"
			local image = note.type == "long"
				and self:getElement(direction, "Hold Head " .. self:getHoldState(note))
				or self:getElement(direction, "Tap Note")
			if image then
				local image_columns, image_rows = self:getGrid(image)
				-- StepMania sheets are columns × snap rows: columns animate, while
				-- NoteColorTextureCoordSpacing selects a vertical snap row.
				local frame = self:getFrame(part, note) * image_columns
				draw_image(image, x, y, 64, 64, frame, image_columns, image_rows, rotations[direction])
			end
		end
		end
	end
end

---@param image love.Image
---@param actor table?
---@param progress number
---@return integer
function StepmaniaRenderer:getAnimationFrame(image, actor, progress)
	local columns, rows = self:getGrid(image)
	local frame_count = columns * rows
	if not actor then return math.floor(progress * frame_count) % frame_count end

	local frames, duration = {}, 0
	for i = 0, frame_count - 1 do
		local frame = actor["Frame" .. string.format("%04d", i)]
		local delay = actor["Delay" .. string.format("%04d", i)]
		if type(frame) ~= "number" or type(delay) ~= "number" then break end
		frames[#frames + 1] = {frame = frame, delay = delay}
		duration = duration + delay
	end
	if duration == 0 then return math.floor(progress * frame_count) % frame_count end

	local time = progress * duration
	for _, entry in ipairs(frames) do
		if time < entry.delay then return entry.frame end
		time = time - entry.delay
	end
	return frames[#frames].frame
end

---@return number
function StepmaniaRenderer:getCurrentBeatModulo()
	local engine = self.game.rhythm_engine
	local chart = engine.chart
	local layer = chart and chart.layers.main
	if not layer then return 0 end
	if self.timing_chart ~= chart then
		self.timing_chart = chart
		self.timing_points = layer:getPointList()
	end
	local points = self.timing_points
	local time = engine.visual_info.time
	local lo, hi = 1, #points
	while lo < hi do
		local mid = math.floor((lo + hi + 1) / 2)
		if points[mid].absoluteTime <= time then lo = mid else hi = mid - 1 end
	end
	local point = points[lo]
	if point.absoluteTime > time then point = nil end
	if not point or not point.tempo then return 0 end
	local measure_offset = point.measure and point.measure.offset or 0
	return ((time - point.tempo.point.absoluteTime) / point.tempo:getBeatDuration() + measure_offset) % 1
end

---@param columns integer
---@param receptor_y number
---@param beat_modulo number?
function StepmaniaRenderer:drawReceptors(columns, receptor_y, beat_modulo)
	beat_modulo = beat_modulo or self:getCurrentBeatModulo()
	local engine = self.game.rhythm_engine
	local time = engine.visual_info.time
	for column = 1, columns do
		local pressed = engine:isColumnPressed(column)
		if pressed and not self.receptor_press_states[column] then
			-- StepMania sends NoneCommand for an unjudged key press. Most skins,
			-- including acessm5 and DivideByZero, use it for this short pulse.
			self.receptor_pulse_times[column] = time
		end
		self.receptor_press_states[column] = pressed
		local direction = self:getDirection(column)
		local image, actor = self:getElementActor(direction, "Receptor")
		if not image then image, actor = self:getElementActor(direction, "Go Receptor Go") end
		if image then
			local image_columns, image_rows = self:getGrid(image)
			-- NoteSkin sprites may assign unequal DelayNNNN values.  Their
			-- effectclock,"beat" animation is still one complete cycle per beat.
			local frame = self:getAnimationFrame(image, actor, beat_modulo)
			local pulse, pulse_time = self.receptor_pulse, self.receptor_pulse_times[column]
			local zoom = 1
			if pulse and pulse_time then
				local progress = (time - pulse_time) / pulse.duration
				if progress < 1 then
					zoom = pulse.from + (pulse.to - pulse.from) * progress
				else
					self.receptor_pulse_times[column] = nil
				end
			end
			draw_image(image, (column - 0.5) * 64, receptor_y, 64 * zoom, 64 * zoom, frame, image_columns, image_rows, rotations[direction])
		end
	end
end

---@param width number
---@param height number
---@param transform love.Transform
function StepmaniaRenderer:draw(width, height, transform)
	local engine = self.game.rhythm_engine
	local visual_engine = engine and engine.visual_engine
	if not visual_engine then return end
	self:load()
	local columns = self.columns
	local scale = math.min(width / 640, height / 480)
	local ox, oy = (width - 640 * scale) / 2, (height - 480 * scale) / 2
	lg.push("all")
	lg.applyTransform(transform)
	lg.translate(ox, oy)
	lg.scale(scale)
	lg.translate((640 - columns * 64) / 2, 0)
	self:drawNotes(visual_engine.visible_notes, columns, 480, 360)
	self:drawReceptors(columns, 360)
	lg.pop()
end

---@param player rizu.preview.NotesPreviewPlayer
---@param width number
---@param height number
function StepmaniaRenderer:drawPreview(player, width, height)
	local preview = player.notes
	if not preview or #preview.columns ~= self.columns then return end
	self:load()
	local scale = math.min(width / 640, height / 480)
	lg.push("all")
	lg.translate((width - 640 * scale) / 2, (height - 480 * scale) / 2)
	lg.scale(scale)
	lg.translate((640 - #preview.columns * 64) / 2, 0)
	local receptor_y, pixels_per_second = 360, 480 * math.max(player.rate, 0.01)
	local top, bottom = 0, 480
	local time = player.time
	-- Include the portion below the receptor, so notes visibly travel past it
	-- rather than disappearing exactly at their absolute time.
	local from_time = time - (bottom - receptor_y) / pixels_per_second
	local until_time = time + (receptor_y - top) / pixels_per_second
	for column, notes in ipairs(preview.columns) do
		local first, last = preview:getVisibleRange(column, from_time, until_time)
		for i = first, last do
			local note = notes[i]
			if note.end_time >= from_time then
				local head_y = receptor_y - (note.time - time) * pixels_per_second
				local tail_y = receptor_y - (note.end_time - time) * pixels_per_second
				local direction = self:getDirection(column)
				if note.end_time > note.time and head_y > tail_y then
					-- Keep the body's natural endpoints, including a tail above the
					-- viewport. Clamping changes its scale and distorts the texture.
					local body_start = head_y - self.hold_body_start_offset
					local body_end = tail_y - self.hold_body_end_offset
					local body = self:getElement(direction, "Hold Body Active")
					if body then draw_hold_body(body, (column - .5) * 64, body_start, body_end, 64) end
					local cap = self:getElement(direction, "Hold BottomCap Active")
					if cap then
						local cap_width, cap_height = cap:getDimensions()
						local height = cap_height * 64 / cap_width
						-- The cap attaches to the metrics-adjusted body endpoint, not
						-- the unadjusted chart tail. Preview scrolls upward.
						draw_image(cap, (column - .5) * 64, body_end - height / 2, 64, height, nil, nil, nil, nil, true)
					end
				end
				if head_y > top and head_y < bottom then
					local image = note.end_time > note.time and self:getElement(direction, "Hold Active") or self:getElement(direction, "Tap Note")
					if image then
						local image_columns, image_rows = self:getGrid(image)
						local snap_frame = self.note_color_frames[note.end_time > note.time and "HoldHead" or "TapNote"]
							and self:getColorFrameFromBeat(note.beat) or 0
						-- Horizontal cells are animation frames; snap colors use rows.
						local frame = snap_frame * image_columns
						draw_image(image, (column - .5) * 64, head_y, 64, 64, frame, image_columns, image_rows, rotations[direction])
					end
				end
			end
		end
	end
	self:drawReceptors(self.columns, receptor_y, preview:getBeatAtTime(time) % 1)
	lg.pop()
end

return StepmaniaRenderer
