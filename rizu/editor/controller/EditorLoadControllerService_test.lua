local EditorLoadControllerService = require("rizu.editor.controller.EditorLoadControllerService")
local FakeFilesystem = require("fs.FakeFilesystem")
local Settings = require("rizu.config.Settings")

local test = {}

---@param top_priority boolean
---@return rizu.config.Config
local function createSettings(top_priority)
	local settings = Settings.createConfig(FakeFilesystem())
	settings:setBoolean(Settings.keys.gameplay.skin_resources_top_priority, top_priority)
	return settings
end

---@param t testing.T
function test.resource_paths_follow_priority_setting(t)
	local service = EditorLoadControllerService()
	local chartview = {
		location_dir = "chart/path",
	}
	local noteSkin = {
		directoryPath = "skin/path",
	}

	t:tdeq(service:getResourcePaths(createSettings(true), chartview, noteSkin), {
		"skin/path",
		"chart/path",
		"userdata/hitsounds",
		"userdata/hitsounds/midi",
	})
	t:tdeq(service:getResourcePaths(createSettings(false), chartview, noteSkin), {
		"chart/path",
		"skin/path",
		"userdata/hitsounds",
		"userdata/hitsounds/midi",
	})
end

---@param t testing.T
function test.iidx_resource_paths_include_movie_directory(t)
	local service = EditorLoadControllerService()
	local fs = FakeFilesystem()
	fs:createDirectory("data")
	fs:createDirectory("data/movie")
	local chartview = {
		format = "iidx",
		location_prefix = "data",
		location_dir = "data/sound/01234.ifs",
	}
	local noteSkin = {
		directoryPath = "skin/path",
	}

	t:tdeq(service:getResourcePaths(createSettings(false), chartview, noteSkin, fs), {
		"data/sound/01234.ifs",
		"skin/path",
		"data/movie",
		"userdata/hitsounds",
		"userdata/hitsounds/midi",
	})
end

---@param t testing.T
function test.load_resource_paths_resets_and_adds_to_both_finders(t)
	local service = EditorLoadControllerService()
	local calls = {}
	local fileFinder = {
		reset = function()
			table.insert(calls, "file-reset")
		end,
		addPath = function(_, path)
			table.insert(calls, "file:" .. path)
		end,
	}
	local resourceFinder = {
		reset = function()
			table.insert(calls, "resource-reset")
		end,
		addPath = function(_, path)
			table.insert(calls, "resource:" .. path)
		end,
	}

	service:loadResourcePaths(fileFinder, resourceFinder, {"a", "b"})

	t:tdeq(calls, {
		"file-reset",
		"resource-reset",
		"file:a",
		"resource:a",
		"file:b",
		"resource:b",
	})
end

return test
