local class = require("class")
local PlayfieldRenderer = require("rizu.gameplay.views.PlayfieldRenderer")
local path_util = require("path_util")
local Snap = require("chart.model.convert.Snap")
local IniParser = require("rizu.skin.IniParser")
local InputMode = require("chart.core.InputMode")
local Actor = require("rizu.skin.stepmania.Actor")
local Environment = require("rizu.skin.stepmania.Environment")

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
---@field redirs {[string]: string}
---@field timing_chart chart.Chart?
---@field timing_points chart.AbsolutePoint[]?
---@field grids {[string]: {columns: integer, rows: integer}}
---@field note_color_frames {[string]: boolean}
---@field metrics table
---@field receptor_actors {[integer]: rizu.skin.stepmania.Actor}
---@field receptor_press_states boolean[]
---@field actor_time number?
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
	-- Parenthesized suffixes such as "(stretch)" and "(res 64x64)" are
	-- StepMania filename hints, not part of the noteskin element name.
	return name:lower():gsub("%.[^%.]+$", ""):gsub("%s*%b()", ""):gsub(" %d+x%d+$", "")
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
	self.redirs = {}
	self.timing_chart = nil
	self.timing_points = nil
	self.grids = {}
	self.note_color_frames = {}
	self.metrics = {}
	self.receptor_actors = {}
	self.receptor_press_states = {}
	self.actor_time = nil
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

---@param path {button: string, element: string}
---@return string
local function actor_path_key(path)
	return key(path.button == "" and path.element or path.button .. " " .. path.element)
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
			elseif name:lower():match("%.redir$") then
				self.redirs[file_key] = (self.game.fs:read(path) or ""):match("^%s*(.-)%s*$")
			end
		end
	end
	self:loadNoteSkin()
	self.metrics = IniParser.parse(self.game.fs:read(path_util.join(self.directory_path, "metrics.ini")) or "")
	local note_display = self.metrics.NoteDisplay or {}
	for part, spacing in pairs(note_display) do
		local name = part:match("^(%a+)NoteColorTextureCoordSpacingY$")
		if name and tonumber(spacing) ~= 0 then
			self.note_color_frames[name] = true
		end
	end
	self.hold_body_start_offset = tonumber(note_display.StartDrawingHoldBodyOffsetFromHead) or 0
	self.hold_body_end_offset = tonumber(note_display.StopDrawingHoldBodyOffsetFromTail) or 0
end

function StepmaniaRenderer:unload()
	self.images = {}
	self.elements = {}
	self.files = {}
	self.scripts = {}
	self.redirs = {}
	self.timing_chart = nil
	self.timing_points = nil
	self.grids = {}
	self.note_color_frames = {}
	self.metrics = {}
	self.receptor_actors = {}
	self.receptor_press_states = {}
	self.actor_time = nil
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
local function draw_hold_body(image, x, a, b, width, frame, columns, rows)
	local image_width, image_height = image:getDimensions()
	columns, rows = columns or 1, rows or 1
	local frame_width, frame_height = image_width / columns, image_height / rows
	local scale = width / frame_width
	local y, height = math.min(a, b), math.abs(b - a)
	if height == 0 then return end
	local column = (frame or 0) % columns
	local row = math.floor((frame or 0) / columns) % rows
	-- Repeat only the selected animation cell, never the complete atlas.
	local quad = lg.newQuad(column * frame_width, row * frame_height, frame_width, height / scale, image_width, image_height)
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
---@return table?
function StepmaniaRenderer:getActorTexture(path, depth)
	if (depth or 0) >= 16 then return end
	local path_key = actor_path_key(path)
	local source_path = self.scripts[path_key]
	if not source_path then
		local target = self.redirs[path_key]
		if target and target ~= "" then
			local target_key = key(target)
			source_path = self.scripts[target_key]
			if not source_path and self.files[target_key] then return {button = "", element = target} end
		end
		if not source_path and self.files[path_key] then return path end
		if not source_path then return end
	end
	local source = self.game.fs:read(source_path)
	if not source then return end

	local actor = Environment.load(source, source_path, self.note_skin_variables,
		function(actor_path, actor_depth) return self:getActorTexture(actor_path, actor_depth) end,
		function(button, element) return self:resolveElement(button, element) end,
		function(group, name) return (self.metrics[group] or {})[name] or "" end,
		depth)
	if not actor then return end
	local texture = actor.Texture
	if type(texture) == "table" then
		local resolved_texture, resolved_actor = self:getActorTexture(texture, (depth or 0) + 1)
		return resolved_texture, resolved_actor
	end
	if texture then return texture, actor end

	-- ActorFrames are tables whose numeric entries are child actors. Use the
	-- first drawable child until the renderer draws actor trees directly.
	for _, child in ipairs(actor) do
		if type(child) == "table" then
			local child_texture = self:getActorTextureFromActor(child, depth)
			-- Preserve the ActorFrame definition so the StepMania Actor runtime
			-- can construct and draw all of its children, not just this first one.
			if child_texture then return child_texture, actor end
		end
	end
end

---@param actor table
---@param depth integer?
---@return {button: string, element: string}?
---@return table?
function StepmaniaRenderer:getActorTextureFromActor(actor, depth)
	local texture = actor.Texture
	if type(texture) == "table" then
		return self:getActorTexture(texture, (depth or 0) + 1)
	end
	if texture then return texture, actor end
	-- LoadActor("asset") uses a direct string texture; NOTESKIN:GetPath uses
	-- a path table. Both are valid Sprite texture forms.
	if type(actor.__loaded_asset) == "string" then
		return {button = "", element = actor.__loaded_asset}, actor
	end
end

---@param direction string
---@param element string
---@param texture {button: string, element: string}
---@return love.Image?
---@return integer
---@return integer
function StepmaniaRenderer:resolveActorImage(texture)
	local image = self:getImage(actor_path_key(texture))
	if not image then return nil, 1, 1 end
	local columns, rows = self:getGrid(image)
	return image, columns, rows
end

---@return love.Image?
---@return table?
function StepmaniaRenderer:getElementActor(direction, element)
	local cache_key = direction .. "\0" .. element
	local cached = self.elements[cache_key]
	if cached then return cached.image, cached.actor end

	local button, resolved_element = self:resolveElement(direction, element)
	local candidates = {
		note_skin_path(button, resolved_element),
		note_skin_path("_" .. button, resolved_element),
		note_skin_path("Down", resolved_element),
		note_skin_path("_Down", resolved_element),
	}
	local texture, actor
	for _, candidate in ipairs(candidates) do
		texture, actor = self:getActorTexture(candidate)
		if texture then break end
	end
	local image
	if texture then
		image = self:getImage(actor_path_key(texture))
	else
		-- A plain image does not have an actor script. Preserve the same button
		-- fallback order used for actor resolution.
		for _, candidate in ipairs(candidates) do
			image = self:getImage(actor_path_key(candidate))
			if image then break end
		end
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
				local body, body_actor = self:getElementActor(note_direction, "Hold Body " .. hold_state)
				if body then
					local body_columns, body_rows = self:getGrid(body)
					local frame = self:getNoteAnimationFrame(body, body_actor, "HoldBody", note.linked_note.startNote:getBeatModulo())
					draw_hold_body(body, x, body_start, body_end, 64, frame, body_columns, body_rows)
				end
				local cap, cap_actor = self:getElementActor(note_direction, "Hold BottomCap " .. hold_state)
				if cap then
					local cap_columns, cap_rows = self:getGrid(cap)
					local cap_width, cap_height = cap:getDimensions()
					local height = cap_height / cap_rows * 64 / (cap_width / cap_columns)
					local frame = self:getNoteAnimationFrame(cap, cap_actor, "HoldBottomCap", note.linked_note.startNote:getBeatModulo())
					draw_image(cap, x, body_end + direction * height / 2, 64, height, frame, cap_columns, cap_rows, nil, true)
				end
				local tail, tail_actor = self:getElementActor(note_direction, "Hold Tail " .. hold_state)
				if tail then
					local tail_columns, tail_rows = self:getGrid(tail)
					local frame = self:getNoteAnimationFrame(tail, tail_actor, "HoldTail", note.linked_note.startNote:getBeatModulo())
					draw_image(tail, x, tail_y, 64, 64, frame, tail_columns, tail_rows, rotations[note_direction])
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
			local image, actor = note.type == "long"
				and self:getElementActor(direction, "Hold Head " .. self:getHoldState(note))
				or self:getElementActor(direction, "Tap Note")
			if image then
				local image_columns, image_rows = self:getGrid(image)
				-- StepMania sheets are columns × snap rows: columns animate, while
				-- NoteColorTextureCoordSpacing selects a vertical snap row.
				local frame = self:getFrame(part, note) * image_columns
				frame = frame + self:getNoteAnimationFrame(image, actor, part, note.linked_note.startNote:getBeatModulo()) % image_columns
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
	local columns = self:getGrid(image)
	-- NoteDisplay stores animation frames across the sheet and note colors in
	-- rows. Animating every cell makes an 8×9 note sheet run nine times faster.
	local frame_count = columns
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

---@param image love.Image
---@param actor table?
---@param part string
---@param note_beat number
---@param current_beat number?
---@param current_time number?
---@return integer
function StepmaniaRenderer:getNoteAnimationFrame(image, actor, part, note_beat, current_beat, current_time)
	local metrics = self.metrics.NoteDisplay or {}
	local length = tonumber(metrics[part .. "AnimationLength"]) or 0
	if length == 0 then return 0 end
	local position
	if tonumber(metrics.AnimationIsBeatBased) ~= 0 then
		position = (current_beat or self:getCurrentBeat()) / length
	else
		position = (current_time or self.game.rhythm_engine.visual_info.time) / length
	end
	if tonumber(metrics[part .. "AnimationIsVivid"]) ~= 0 then
		position = position + math.floor((note_beat % 1) * length) / length
	end
	return self:getAnimationFrame(image, actor, position % 1)
end

---@return number
function StepmaniaRenderer:getCurrentBeat()
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
	return (time - point.tempo.point.absoluteTime) / point.tempo:getBeatDuration() + measure_offset
end

---@return number
function StepmaniaRenderer:getCurrentBeatModulo()
	return self:getCurrentBeat() % 1
end

---@param columns integer
---@param receptor_y number
---@param beat_modulo number?
function StepmaniaRenderer:drawReceptors(columns, receptor_y, beat_modulo)
	beat_modulo = beat_modulo or self:getCurrentBeatModulo()
	local engine = self.game.rhythm_engine
	local time = engine.visual_info.time
	local dt = self.actor_time and math.max(time - self.actor_time, 0) or 0
	self.actor_time = time
	for column = 1, columns do
		local pressed = engine:isColumnPressed(column)
		local direction = self:getDirection(column)
		local image, definition = self:getElementActor(direction, "Receptor")
		if not image then image, definition = self:getElementActor(direction, "Go Receptor Go") end
		if image then
			local image_columns, image_rows = self:getGrid(image)
			local actor = self.receptor_actors[column]
			if not actor or actor.definition ~= definition then
				-- An ActorFrame has no texture of its own. Its image only establishes
				-- that at least one child resolved successfully.
				local root_image = image
				if definition and #definition > 0 then root_image = nil end
				actor = Actor(root_image, definition, image_columns, image_rows, function(texture)
					return self:resolveActorImage(texture)
				end)
				self.receptor_actors[column] = actor
			end
			local was_pressed = self.receptor_press_states[column]
			-- Match StepMania's ReceptorArrow: Press and Lift are dispatched on
			-- input edges. Keep NoneCommand as a compatibility fallback for older
			-- skins that put their press effect in ReceptorArrow metrics.
			if pressed and not was_pressed then
				actor:play("Press")
				actor:playCommand((self.metrics.ReceptorArrow or {}).PressCommand)
				actor:playCommand((self.metrics.ReceptorArrow or {}).NoneCommand)
			elseif was_pressed and not pressed then
				actor:play("Lift")
				actor:playCommand((self.metrics.ReceptorArrow or {}).LiftCommand)
			end
			self.receptor_press_states[column] = pressed
			actor:update(dt, beat_modulo)
			local x = (column - 0.5) * 64
			actor:draw(x, receptor_y, 64, 64, rotations[direction])
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
	local current_beat = preview:getBeatAtTime(time)
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
					local body, body_actor = self:getElementActor(direction, "Hold Body Active")
					if body then
						local body_columns, body_rows = self:getGrid(body)
						local frame = self:getNoteAnimationFrame(body, body_actor, "HoldBody", note.beat, current_beat, time)
						draw_hold_body(body, (column - .5) * 64, body_start, body_end, 64, frame, body_columns, body_rows)
					end
					local cap, cap_actor = self:getElementActor(direction, "Hold BottomCap Active")
					if cap then
						local cap_columns, cap_rows = self:getGrid(cap)
						local cap_width, cap_height = cap:getDimensions()
						local height = cap_height / cap_rows * 64 / (cap_width / cap_columns)
						local frame = self:getNoteAnimationFrame(cap, cap_actor, "HoldBottomCap", note.beat, current_beat, time)
						-- The cap attaches to the metrics-adjusted body endpoint, not
						-- the unadjusted chart tail. Preview scrolls upward.
						draw_image(cap, (column - .5) * 64, body_end - height / 2, 64, height, frame, cap_columns, cap_rows, nil, true)
					end
				end
				if head_y > top and head_y < bottom then
					local part = note.end_time > note.time and "HoldHead" or "TapNote"
					local image, actor = note.end_time > note.time
						and self:getElementActor(direction, "Hold Active") or self:getElementActor(direction, "Tap Note")
					if image then
						local image_columns, image_rows = self:getGrid(image)
						local snap_frame = self.note_color_frames[part] and self:getColorFrameFromBeat(note.beat) or 0
						-- Horizontal cells are animation frames; snap colors use rows.
						local frame = snap_frame * image_columns + self:getNoteAnimationFrame(image, actor, part, note.beat, current_beat, time) % image_columns
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
