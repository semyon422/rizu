local class = require("class")
local Settings = require("rizu.config.Settings")

---@class rizu.editor.EditorSettings
---@field audioOffset number
---@field waveformOffset number
---@field speed number
---@field snap integer
---@field lockSnap boolean
---@field showTimings boolean
---@field time number
---@field tool string
---@field waveform {opacity: number, scale: number}

---@class rizu.editor.EditorSettingsService
---@operator call: rizu.editor.EditorSettingsService
local EditorSettingsService = class()

---@class rizu.editor.EditorSettingsContext
---@field getConfig fun(self: rizu.editor.EditorSettingsContext): rizu.config.Config
---@field getMaxSnap fun(self: rizu.editor.EditorSettingsContext): number

local editor_keys = Settings.keys.editor
local editor_fields = {
	audioOffset = editor_keys.audio_offset,
	waveformOffset = editor_keys.waveform_offset,
	speed = editor_keys.speed,
	snap = editor_keys.snap,
	lockSnap = editor_keys.lock_snap,
	showTimings = editor_keys.show_timings,
	time = editor_keys.time,
	tool = editor_keys.tool,
}

local audio_keys = Settings.keys.audio
local volume_fields = {
	master = audio_keys.volume_master,
	music = audio_keys.volume_music,
	keysounds = audio_keys.volume_keysounds,
	metronome = audio_keys.volume_metronome,
}

---@param config rizu.config.Config
---@param fields {[string]: string}
---@return table
local function configProxy(config, fields)
	return setmetatable({}, {
		__index = function(_, field)
			local key = fields[field]
			return key and config:get(key) or nil
		end,
		__newindex = function(_, field, value)
			local key = assert(fields[field], "unknown settings field: " .. tostring(field))
			config:set(key, value)
		end,
	})
end

---@param editor rizu.editor.EditorSettings
---@param maxSnap number
---@return rizu.editor.EditorSettings
function EditorSettingsService:normalizeEditorSettings(editor, maxSnap)
	if editor.speed <= 0 then editor.speed = 1 end
	editor.snap = math.min(math.max(editor.snap, 1), maxSnap)
	return editor
end

---@param config rizu.config.Config
---@param maxSnap number
---@return rizu.editor.EditorSettings
function EditorSettingsService:getSettings(config, maxSnap)
	local waveform = configProxy(config, {
		opacity = editor_keys.waveform_opacity,
		scale = editor_keys.waveform_scale,
	})
	local proxy = configProxy(config, editor_fields)
	return setmetatable({}, {
		__index = function(_, field)
			if field == "waveform" then return waveform end
			local value = proxy[field]
			if field == "snap" then
				return math.min(math.max(value, 1), maxSnap)
			end
			return value
		end,
		__newindex = function(_, field, value)
			if field == "snap" then
				value = math.min(math.max(value, 1), maxSnap)
			end
			proxy[field] = value
		end,
	}) --[[@as rizu.editor.EditorSettings]]
end

---@param context rizu.editor.EditorSettingsContext
---@param editor rizu.editor.EditorSettings
---@return rizu.editor.EditorSettings
function EditorSettingsService:normalizeContextEditorSettings(context, editor)
	return self:normalizeEditorSettings(editor, context:getMaxSnap())
end

---@param context rizu.editor.EditorSettingsContext
---@return rizu.editor.EditorSettings
function EditorSettingsService:getEditorSettings(context)
	return self:getSettings(context:getConfig(), context:getMaxSnap())
end

---@param config rizu.config.Config
---@return rizu.editor.EditorAudioSettings
function EditorSettingsService:getAudioSettings(config)
	local volume = configProxy(config, volume_fields)
	local mode = configProxy(config, {
		primary = audio_keys.mode_primary,
		secondary = audio_keys.mode_secondary,
	})
	return setmetatable({}, {
		__index = function(_, field)
			if field == "volume" then return volume end
			if field == "mode" then return mode end
			if field == "volumeType" then return config:getChoice(audio_keys.volume_type) end
		end,
		__newindex = function(_, field, value)
			if field == "volumeType" then
				config:setChoice(audio_keys.volume_type, value)
			else
				error("unknown audio settings field: " .. tostring(field))
			end
		end,
	}) --[[@as rizu.editor.EditorAudioSettings]]
end

---@param context rizu.editor.EditorSettingsContext
---@return rizu.editor.EditorAudioSettings
function EditorSettingsService:getEditorAudioSettings(context)
	return self:getAudioSettings(context:getConfig())
end

---@param editor rizu.editor.EditorSettings
---@return number
function EditorSettingsService:getLogSpeed(editor)
	return math.floor(10 * math.log(editor.speed, 2) + 0.5)
end

---@param context rizu.editor.EditorSettingsContext
---@return number
function EditorSettingsService:getEditorLogSpeed(context)
	return self:getLogSpeed(self:getEditorSettings(context))
end

---@param editor rizu.editor.EditorSettings
---@param logSpeed number
function EditorSettingsService:setLogSpeed(editor, logSpeed)
	editor.speed = 2 ^ (logSpeed / 10)
end

---@param context rizu.editor.EditorSettingsContext
---@param logSpeed number
function EditorSettingsService:setEditorLogSpeed(context, logSpeed)
	self:setLogSpeed(self:getEditorSettings(context), logSpeed)
end

---@param editor rizu.editor.EditorSettings
---@param maxSnap number
function EditorSettingsService:incSnap(editor, maxSnap)
	editor.snap = math.min(editor.snap * 2, maxSnap)
end

---@param context rizu.editor.EditorSettingsContext
function EditorSettingsService:incEditorSnap(context)
	self:incSnap(self:getEditorSettings(context), context:getMaxSnap())
end

---@param editor rizu.editor.EditorSettings
---@param maxSnap number
function EditorSettingsService:decSnap(editor, maxSnap)
	editor.snap = math.max(math.floor(editor.snap / 2), 1)
end

---@param context rizu.editor.EditorSettingsContext
function EditorSettingsService:decEditorSnap(context)
	self:decSnap(self:getEditorSettings(context), context:getMaxSnap())
end

---@param editor rizu.editor.EditorSettings
---@param j number|chart.Fraction
---@return integer
function EditorSettingsService:getSnap(editor, j)
	local snap = editor.snap
	---@type number
	local position
	if type(j) == "table" then
		position, snap = 16 * j:tonumber(), 16
	else
		position = j
	end
	---@type integer
	local k
	for i = 1, 16 do
		if snap % i == 0 and position % (snap / i) == 0 then
			k = i
			break
		end
	end
	return k
end

---@param context rizu.editor.EditorSettingsContext
---@param j number|chart.Fraction
---@return number
function EditorSettingsService:getEditorSnap(context, j)
	return self:getSnap(self:getEditorSettings(context), j)
end

return EditorSettingsService
