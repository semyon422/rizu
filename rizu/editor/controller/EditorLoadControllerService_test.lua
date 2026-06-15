local EditorLoadControllerService = require("rizu.editor.controller.EditorLoadControllerService")

local test = {}

---@param topPriority boolean
---@return sphere.ConfigModel
local function createConfigModel(topPriority)
	return {
		configs = {
			settings = {
				gameplay = {
					skin_resources_top_priority = topPriority,
				},
			},
		},
	}
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

	t:tdeq(service:getResourcePaths(createConfigModel(true), chartview, noteSkin), {
		"skin/path",
		"chart/path",
		"userdata/hitsounds",
		"userdata/hitsounds/midi",
	})
	t:tdeq(service:getResourcePaths(createConfigModel(false), chartview, noteSkin), {
		"chart/path",
		"skin/path",
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
