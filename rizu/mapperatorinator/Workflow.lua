local class = require("class")
local digest = require("digest")
local LinuxFilesystem = require("fs.LinuxFilesystem")
local path_util = require("path_util")
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

---@param audio_path string
---@param config rizu.config.Config
---@return boolean started
---@return string? error_message
function Workflow:start(audio_path, config)
	if self:isBusy() then
		return false, "Mapperatorinator is already busy."
	end
	if jit.os ~= "Linux" then
		return false, "The Mapperatorinator prototype currently supports Linux only."
	end
	local info = self.host_fs:getInfo(audio_path)
	if not info or info.type ~= "file" then
		return false, "The selected audio file no longer exists."
	end

	local repository_path = config:getString("mapperatorinator.repository_path")
	local python_path = config:getString("mapperatorinator.python_path")
	if not self.host_fs:getInfo(repository_path .. "/inference.py") then
		return false, "Mapperatorinator inference.py was not found."
	end
	if not self.host_fs:getInfo(python_path) then
		return false, "The configured Mapperatorinator Python executable was not found."
	end

	local output_base = "userdata/charts/mapperatorinator/"
	local output_id = os.time()
	local output_relative = output_base .. output_id
	while self.game.fs:getInfo(output_relative) do
		output_id = output_id + 1
		output_relative = output_base .. output_id
	end
	local suffix = audio_path:match("%.([^./]+)$") or "audio"
	local audio_relative = path_util.join(output_relative, "audio." .. suffix:lower())
	if not self.game.fs:createDirectory(output_relative) then
		return false, "Could not create the Mapperatorinator output directory."
	end
	local audio, read_err = self.host_fs:read(audio_path)
	if not audio then
		return false, "Could not read selected audio: " .. tostring(read_err)
	end
	local written, write_err = self.game.fs:write(audio_relative, audio)
	if not written then
		return false, "Could not copy selected audio: " .. tostring(write_err)
	end

	local root = self.game.fs:getWorkingDirectory()
	self.output_relative = output_relative
	self.output_absolute = path_util.join(root, output_relative)
	self.transport:start({
		repository_path = repository_path,
		python_path = python_path,
		audio_path = path_util.join(root, audio_relative),
		output_path = self.output_absolute,
		gamemode = assert(GAMEMODES[config:getChoice("mapperatorinator.gamemode")]),
		difficulty = config:getNumber("mapperatorinator.difficulty"),
		keycount = config:getNumber("mapperatorinator.keycount"),
		year = config:getNumber("mapperatorinator.year"),
	})
	self.state = "generating"
	self.status = "Generating chart… this can take several minutes."
	return true
end

---@private
---@return string? path
function Workflow:findGeneratedChart()
	for _, name in ipairs(self.game.fs:getDirectoryItems(self.output_relative)) do
		if name:lower():match("%.osu$") then
			return path_util.join(self.output_relative, name)
		end
	end
end

---@private
function Workflow:finishGeneration()
	local chart_path = self:findGeneratedChart()
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
