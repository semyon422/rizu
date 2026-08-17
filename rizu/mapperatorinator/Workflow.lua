local class = require("class")
local digest = require("digest")
local LinuxFilesystem = require("fs.LinuxFilesystem")
local ZipFilesystem = require("fs.ZipFilesystem")
local path_util = require("path_util")
local MapperatorinatorConfig = require("rizu.mapperatorinator.Config")
local GenerationTransport = require("rizu.mapperatorinator.GenerationTransport")

---@alias rizu.mapperatorinator.WorkflowState "idle"|"generating"|"caching"|"error"

---@class rizu.mapperatorinator.Workflow
---@operator call: rizu.mapperatorinator.Workflow
---@field state rizu.mapperatorinator.WorkflowState
---@field status string
local Workflow = class()

local GAMEMODES = {
	["osu!standard"] = 0,
	["osu!taiko"] = 1,
	["osu!catch"] = 2,
	["osu!mania"] = 3,
}

---@param value string
---@return number?
local function optionalNumber(value)
	value = value:match("^%s*(.-)%s*$")
	if value == "" then
		return nil
	end
	return tonumber(value)
end

---@param value string
---@return string[]?
local function parseList(value)
	local result = {}
	local seen = {}
	for item in value:gmatch("[^,\n]+") do
		item = item:match("^%s*(.-)%s*$")
		if item ~= "" and not seen[item] then
			result[#result + 1] = item
			seen[item] = true
		end
	end
	return #result > 0 and result or nil
end

---@param source_fs fs.IFilesystem
---@param destination_fs fs.IFilesystem
---@param source string
---@param destination string
---@return boolean success
---@return string? error_message
local function copyFile(source_fs, destination_fs, source, destination)
	local content, read_err = source_fs:read(source)
	if not content then
		return false, "Could not read " .. source .. ": " .. tostring(read_err)
	end
	local written, write_err = destination_fs:write(destination, content)
	if not written then
		return false, "Could not copy " .. source .. ": " .. tostring(write_err)
	end
	return true
end

---@param game sphere.GameController
---@param ui ui.UserInterface
---@param transport rizu.mapperatorinator.GenerationTransport?
---@param host_fs fs.IFilesystem?
function Workflow:new(game, ui, transport, host_fs)
	self.game = game
	self.ui = ui
	self.transport = transport or GenerationTransport()
	self.host_fs = host_fs or LinuxFilesystem()
	self.state = "idle"
	self.status = "Choose an audio file from the command palette."
end

---@return boolean
function Workflow:isBusy()
	return self.state == "generating" or self.state == "caching"
end

---@param config rizu.config.Config
---@return boolean valid
---@return string? error_message
function Workflow:validateOptionalNumbers(config)
	local keys = MapperatorinatorConfig.keys
	local constraints = {
		{keys.seed, "Seed", true},
		{keys.mapper_id, "Mapper ID", true},
		{keys.beatmap_id, "Beatmap ID", true},
		{keys.preview_time, "Preview time", true},
		{keys.start_time, "Start time", true},
		{keys.end_time, "End time", true},
		{keys.hold_note_ratio, "Hold note ratio", false},
		{keys.scroll_speed_ratio, "Scroll speed ratio", false},
	}
	for _, item in ipairs(constraints) do
		local text = config:getString(item[1])
		local value = optionalNumber(text)
		if text:match("^%s*(.-)%s*$") ~= "" and not value then
			return false, item[2] .. " must be a number or blank."
		end
		if value and item[3] and value ~= math.floor(value) then
			return false, item[2] .. " must be a whole number."
		end
	end
	local start_time = optionalNumber(config:getString(keys.start_time))
	local end_time = optionalNumber(config:getString(keys.end_time))
	if start_time and end_time and start_time >= end_time then
		return false, "End time must be greater than start time."
	end
	return true
end

---@param audio_path string
---@param config rizu.config.Config
---@return boolean started
---@return string? error_message
function Workflow:start(audio_path, config)
	if self:isBusy() then
		return false, "Mapperatorinator is already busy."
	end
	if jit.os ~= "Linux" then
		return false, "Mapperatorinator currently supports Linux only."
	end
	local info = self.host_fs:getInfo(audio_path)
	if not info or info.type ~= "file" then
		return false, "The selected audio file no longer exists."
	end
	local valid, number_err = self:validateOptionalNumbers(config)
	if not valid then
		return false, number_err
	end

	local keys = MapperatorinatorConfig.keys
	local model = config:getChoice(keys.model)
	local year = config:getNumber(keys.year)
	if model ~= "v32" and year > 2023 then
		return false, "Style year must be 2023 or earlier for " .. model .. "."
	end
	local repository_path = config:getString(keys.repository_path)
	local python_path = config:getString(keys.python_path)
	if not self.host_fs:getInfo(repository_path .. "/inference.py") then
		return false, "Mapperatorinator inference.py was not found."
	end
	if not self.host_fs:getInfo(python_path) then
		return false, "The configured Mapperatorinator Python executable was not found."
	end
	local lora_path = config:getString(keys.lora_path)
	if lora_path ~= "" and not self.host_fs:getInfo(lora_path) then
		return false, "The configured LoRA path was not found."
	end
	local reference_path = config:getString(keys.reference_path)
	if reference_path ~= "" then
		local reference_info = self.host_fs:getInfo(reference_path)
		if not reference_info or reference_info.type ~= "file" or not reference_path:lower():match("%.osu$") then
			return false, "The reference beatmap must be an existing .osu file."
		end
	end
	local background_path = config:getString(keys.background_path)
	if background_path ~= "" then
		local background_info = self.host_fs:getInfo(background_path)
		if not background_info or background_info.type ~= "file" then
			return false, "The background image was not found."
		end
	end
	if (config:getBoolean(keys.add_to_beatmap)
		or config:getBoolean(keys.overwrite_reference_beatmap)
		or config:getBoolean(keys.context_timing)
		or config:getBoolean(keys.context_kiai)
		or config:getBoolean(keys.context_gd)
		or config:getBoolean(keys.context_no_hs)) and reference_path == ""
	then
		return false, "Reference-map options require a reference beatmap."
	end

	local output_base = "userdata/charts/mapperatorinator/"
	local output_id = os.time()
	local output_relative = output_base .. output_id
	while self.game.fs:getInfo(output_relative) do
		output_id = output_id + 1
		output_relative = output_base .. output_id
	end
	if not self.game.fs:createDirectory(output_relative) then
		return false, "Could not create the Mapperatorinator output directory."
	end

	local root = self.game.fs:getWorkingDirectory()
	local suffix = audio_path:match("%.([^./]+)$") or "audio"
	local audio_relative = path_util.join(output_relative, "audio." .. suffix:lower())
	local audio_absolute = path_util.join(root, audio_relative)
	local copied, copy_err = copyFile(self.host_fs, self.game.fs, audio_path, audio_relative)
	if not copied then
		self.game.fs:remove(output_relative)
		return false, copy_err
	end

	local reference_absolute
	if reference_path ~= "" then
		local reference_relative = path_util.join(output_relative, "reference.osu")
		reference_absolute = path_util.join(root, reference_relative)
		copied, copy_err = copyFile(self.host_fs, self.game.fs, reference_path, reference_relative)
		if not copied then
			self.game.fs:remove(output_relative)
			return false, copy_err
		end
	end
	local background_absolute
	if background_path ~= "" then
		local extension = background_path:match("%.([^./]+)$") or "jpg"
		local background_relative = path_util.join(output_relative, "background." .. extension:lower())
		background_absolute = path_util.join(root, background_relative)
		copied, copy_err = copyFile(self.host_fs, self.game.fs, background_path, background_relative)
		if not copied then
			self.game.fs:remove(output_relative)
			return false, copy_err
		end
	end

	local in_context = {}
	if config:getBoolean(keys.context_timing) then in_context[#in_context + 1] = "TIMING" end
	if config:getBoolean(keys.context_kiai) then in_context[#in_context + 1] = "KIAI" end
	if config:getBoolean(keys.context_gd) then in_context[#in_context + 1] = "GD" end
	if config:getBoolean(keys.context_no_hs) then in_context[#in_context + 1] = "NO_HS" end
	if #in_context == 0 then in_context = nil end

	self.output_relative = output_relative
	self.output_absolute = path_util.join(root, output_relative)
	self.transport:start({
		repository_path = repository_path,
		python_path = python_path,
		audio_path = audio_absolute,
		output_path = self.output_absolute,
		beatmap_path = reference_absolute,
		lora_path = lora_path ~= "" and lora_path or nil,
		background = background_absolute,
		model = model,
		gamemode = assert(GAMEMODES[config:getChoice(keys.gamemode)]),
		difficulty = config:getNumber(keys.difficulty),
		keycount = config:getNumber(keys.keycount),
		year = year,
		beatmap_id = optionalNumber(config:getString(keys.beatmap_id)),
		mapper_id = optionalNumber(config:getString(keys.mapper_id)),
		hitsounded = config:getBoolean(keys.hitsounded),
		hp_drain_rate = config:getNumber(keys.hp_drain_rate),
		circle_size = config:getNumber(keys.circle_size),
		overall_difficulty = config:getNumber(keys.overall_difficulty),
		approach_rate = config:getNumber(keys.approach_rate),
		slider_multiplier = config:getNumber(keys.slider_multiplier),
		slider_tick_rate = config:getNumber(keys.slider_tick_rate),
		hold_note_ratio = optionalNumber(config:getString(keys.hold_note_ratio)),
		scroll_speed_ratio = optionalNumber(config:getString(keys.scroll_speed_ratio)),
		descriptors = parseList(config:getString(keys.descriptors)),
		negative_descriptors = parseList(config:getString(keys.negative_descriptors)),
		seed = optionalNumber(config:getString(keys.seed)),
		device = config:getChoice(keys.device),
		precision = config:getChoice(keys.precision),
		attn_implementation = config:getChoice(keys.attn_implementation),
		add_to_beatmap = config:getBoolean(keys.add_to_beatmap),
		overwrite_reference_beatmap = config:getBoolean(keys.overwrite_reference_beatmap),
		export_osz = config:getBoolean(keys.export_osz),
		start_time = optionalNumber(config:getString(keys.start_time)),
		end_time = optionalNumber(config:getString(keys.end_time)),
		in_context = in_context,
		cfg_scale = config:getNumber(keys.cfg_scale),
		temperature = config:getNumber(keys.temperature),
		top_p = config:getNumber(keys.top_p),
		super_timing = config:getBoolean(keys.super_timing),
		generate_positions = config:getBoolean(keys.generate_positions),
		title = config:getString(keys.title),
		title_unicode = config:getString(keys.title_unicode),
		artist = config:getString(keys.artist),
		artist_unicode = config:getString(keys.artist_unicode),
		creator = config:getString(keys.creator),
		version = config:getString(keys.version),
		source = config:getString(keys.source),
		tags = config:getString(keys.tags),
		preview_time = optionalNumber(config:getString(keys.preview_time)),
	})
	self.state = "generating"
	self.status = "Generating chart… this can take several minutes."
	return true
end

---@private
---@return string? path
function Workflow:findGeneratedChart()
	for _, name in ipairs(self.game.fs:getDirectoryItems(self.output_relative)) do
		if name:lower():match("%.osu$") and name ~= "reference.osu" then
			return path_util.join(self.output_relative, name)
		end
	end
	-- Overwrite-reference mode writes back to the managed reference copy.
	local reference = path_util.join(self.output_relative, "reference.osu")
	if self.game.fs:getInfo(reference) then
		return reference
	end
end

---@private
---@return string? path
function Workflow:extractPackagedChart()
	for _, name in ipairs(self.game.fs:getDirectoryItems(self.output_relative)) do
		if name:lower():match("%.osz$") then
			local data = self.game.fs:read(path_util.join(self.output_relative, name))
			if data then
				local ok, archive = pcall(ZipFilesystem, data)
				if ok then
					---@cast archive fs.ZipFilesystem
					for _, entry in ipairs(archive:getDirectoryItems("")) do
						if entry:lower():match("%.osu$") then
							local content = archive:read(entry)
							if content then
								local output = path_util.join(self.output_relative, "packaged-" .. entry:match("([^/]+)$"))
								if self.game.fs:write(output, content) then return output end
							end
						end
					end
				end
			end
		end
	end
end

---@private
function Workflow:finishGeneration()
	local chart_path = self:findGeneratedChart() or self:extractPackagedChart()
	if not chart_path then
		self.state = "error"
		self.status = "Generation finished, but no .osu file was produced."
		return
	end
	local content, err = self.game.fs:read(chart_path)
	if not content then
		self.state = "error"
		self.status = "Could not read generated chart: " .. tostring(err)
		return
	end
	self.generated_hash = digest.hash("md5", content, true)
	self.game.library:computeLocation(self.output_relative:gsub("^userdata/charts/", ""), 1)
	self.state = "caching"
	self.status = "Generation complete. Caching chart…"
end

---@private
function Workflow:openGeneratedChart()
	self.game.chartSelector:findChartmeta(self.generated_hash, 1)
	self.find_deadline = love.timer.getTime() + 15
	self.status = "Cached. Opening generated chart…"
end

---@param dt number
function Workflow:update(dt)
	if self.state == "generating" then
		local event = self.transport:pop()
		if not event then
			if not self.transport:isRunning() then
				self.transport:finish()
				self.state = "error"
				self.status = "Mapperatorinator stopped without returning a result."
			end
			return
		end
		self.transport:finish()
		if event.type == "error" then
			self.state = "error"
			self.status = event.error or "Mapperatorinator generation failed."
			return
		end
		self:finishGeneration()
	elseif self.state == "caching" and not self.game.library.isProcessing then
		if not self.find_deadline then
			self:openGeneratedChart()
		elseif self.game.chartSelector.chartview
			and self.game.chartSelector.chartview.hash == self.generated_hash
		then
			self.state = "idle"
			self.status = "Generated chart opened in the editor."
			self.find_deadline = nil
			self.ui.modal_manager:detachMapperatorinator()
			self.ui:setScreen(self.ui.editor)
		elseif love.timer.getTime() >= self.find_deadline then
			self.state = "error"
			self.status = "The chart was cached, but could not be selected."
			self.find_deadline = nil
		end
	end
end

return Workflow
