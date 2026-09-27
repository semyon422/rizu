local ChartPreviewView = require("ui.screens.song_select.ChartPreviewView")

local test = {}
local skins_by_path = {}

local function newPanel()
	local loads = {}
	local registry = {
		loadSkin = function(_, skin, game, input_mode, screen)
			loads[#loads + 1] = {skin = skin, input_mode = input_mode, screen = screen}
			local renderer = {unload_count = 0}
			function renderer:unload()
				self.unload_count = self.unload_count + 1
			end
			return renderer
		end,
		getSkinForInputMode = function(_, _, _, path)
			return path and skins_by_path[path]
		end,
	}
	local panel = setmetatable({
		game = {skinRegistry = registry},
		preview_renderer_cache = {mania = {}},
	}, {__index = ChartPreviewView})
	return panel, loads
end

---@param t testing.T
function test.reuses_preview_renderer_per_keymode_and_skin(t)
	local panel, loads = newPanel()
	local skin = {path = "skin-a", format = "lua"}
	local four_key = panel:getPreviewRenderer("4key", skin)
	t:eq(panel:getPreviewRenderer("4key", skin), four_key)
	t:eq(#loads, 1)
	t:eq(loads[1].screen, "preview")

	local seven_key = panel:getPreviewRenderer("7key", skin)
	t:assert(seven_key ~= four_key)
	t:eq(#loads, 2)

	local other_skin = {path = "skin-b", format = "lua"}
	local replacement = panel:getPreviewRenderer("4key", other_skin)
	t:assert(replacement ~= four_key)
	t:eq(four_key.unload_count, 1)
	t:eq(#loads, 3)

	panel:clearPreviewRendererCache()
	t:eq(replacement.unload_count, 1)
	t:eq(seven_key.unload_count, 1)
	t:eq(panel.playfield_renderer, nil)
	t:tdeq(panel.preview_renderer_cache, {mania = {}})
end

---@param t testing.T
function test.invalidates_only_the_keymode_whose_resolved_skin_changed(t)
	local panel, loads = newPanel()
	local skin_four = {path = "skin-four", format = "lua"}
	local skin_seven_a = {path = "skin-seven-a", format = "lua"}
	local skin_seven_b = {path = "skin-seven-b", format = "lua"}
	skins_by_path = {
		[skin_four.path] = skin_four,
		[skin_seven_a.path] = skin_seven_a,
		[skin_seven_b.path] = skin_seven_b,
	}
	local four_renderer = panel:getPreviewRenderer("4key", skin_four)
	local seven_renderer = panel:getPreviewRenderer("7key", skin_seven_a)

	panel:invalidateChangedPreviewRenderers({
		["mania/4key"] = skin_four.path,
		["mania/7key"] = skin_seven_b.path,
	}, {
		["mania/4key"] = skin_four.path,
		["mania/7key"] = skin_seven_a.path,
	})

	t:eq(four_renderer.unload_count, 0)
	t:eq(seven_renderer.unload_count, 1)
	t:eq(panel.preview_renderer_cache.mania["4key"].renderer, four_renderer)
	t:eq(panel.preview_renderer_cache.mania["7key"], nil)
	t:eq(#loads, 2)
end

---@param t testing.T
function test.loads_osu_skin_renderer_through_registry_for_preview(t)
	local panel, loads = newPanel()
	local skin = {path = "osu-skin", format = "osu"}
	skins_by_path[skin.path] = skin
	local renderer = panel:getPreviewRenderer("4key", skin)
	t:eq(renderer, loads[1] and panel.preview_renderer_cache.mania["4key"].renderer)
	t:eq(#loads, 1)
	t:eq(loads[1].skin, skin)
	t:eq(loads[1].input_mode, "4key")
	t:eq(loads[1].screen, "preview")
end

return test
