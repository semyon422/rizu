local FakeFilesystem = require("fs.FakeFilesystem")
local OsuManiaSkinGraphics = require("rizu.skin.osu.mania.OsuManiaSkinGraphics")

local test = {}

---@param t testing.T
function test.resolves_skin_assets_case_insensitively_and_keeps_nested_image_maps(t)
	local graphics = OsuManiaSkinGraphics(FakeFilesystem(), {
		path = "skins/example",
		files = {
			"MANIA-KEY1@2X.PNG",
			"Notes/blue.png",
			"Notes/blue-0.png",
			"Notes/blue-1@2x.png",
			"notes/blue-2.png",
			"elsewhere/blue-3.png",
		},
	})

	t:eq(graphics:findAsset("mania-key1"), "skins/example/MANIA-KEY1@2X.PNG")
	t:eq(graphics:findAsset("Notes\\blue"), "skins/example/Notes/blue.png")
	t:tdeq(graphics:findAnimationAssets("Notes\\blue"), {
		{index = 0, path = "skins/example/Notes/blue-0.png", high_density = false},
		{index = 1, path = "skins/example/Notes/blue-1@2x.png", high_density = true},
		{index = 2, path = "skins/example/notes/blue-2.png", high_density = false},
	})
end

function test.preloads_skin_png_assets_once_during_load(t)
	local fs = FakeFilesystem()
	fs:createDirectory("skins/example/notes")
	fs:write("skins/example/notes/blue.png", "blue")
	fs:write("skins/example/mania-key1@2x.PNG", "key")
	fs:write("skins/example/ui-button.png", "ui")
	fs:write("skins/example/hitsound.wav", "sound")
	local graphics = OsuManiaSkinGraphics(fs, {
		path = "skins/example",
		files = {"notes/blue.png", "mania-key1@2x.PNG", "ui-button.png", "hitsound.wav"},
	})

	local previous_new_image = love.graphics.newImage
	local previous_new_file_data = love.filesystem.newFileData
	local loaded = {}
	love.filesystem.newFileData = function(content) return content end
	love.graphics.newImage = function(data)
		loaded[#loaded + 1] = data
		return {
			getWidth = function() return 16 end,
			getHeight = function() return 16 end,
			release = function() end,
		}
	end

	local ok, err = xpcall(function()
		graphics:load({{name = "mania-key1"}, {name = "notes/blue"}})
		t:tdeq(loaded, {"key", "blue"})
		t:eq(graphics.images["skins/example/mania-key1@2x.PNG"]:getWidth(), 16)
		local before = #loaded
		graphics:getFrames("notes/blue")
		graphics:getFrames("mania-key1")
		t:eq(#loaded, before)
		t:eq(graphics.images["skins/example/ui-button.png"], nil)
	end, debug.traceback)

	love.graphics.newImage = previous_new_image
	love.filesystem.newFileData = previous_new_file_data
	graphics:unload()
	if not ok then error(err) end
end

return test
