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

function test.finds_animated_long_note_frames_starting_at_zero(t)
	local graphics = OsuManiaSkinGraphics(FakeFilesystem(), {
		path = "skins/example",
		files = {"mania-note1L-0.png", "mania-note1L-1.png", "mania-note1L-2.png"},
	})
	t:tdeq(graphics:findAnimationAssets("mania-note1L"), {
		{index = 0, path = "skins/example/mania-note1L-0.png", high_density = false},
		{index = 1, path = "skins/example/mania-note1L-1.png", high_density = false},
		{index = 2, path = "skins/example/mania-note1L-2.png", high_density = false},
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

---@param t testing.T
function test.loads_missing_assets_from_zip_without_overriding_skin_assets(t)
	local ZipFilesystem = require("fs.ZipFilesystem")
	local archive = ZipFilesystem()
	archive:write("mania-key1@2x.png", "default-key")
	archive:write("mania-note1L@2x.png", "default-body")
	archive:write("mania-note1L-0@2x.png", "default-body-0")
	archive:write("mania-note1L-1@2x.png", "default-body-1")
	archive:write("mania-hit300g-0@2x.png", "default-judge")
	archive:write("mania-stage-left@2x.png", "default-stage")
	archive:write("score-0@2x.png", "default-digit")
	local archive_data = archive:save()
	local fs = FakeFilesystem()
	fs:createDirectory("skins/example")
	fs:write("skins/example/MANIA-KEY1.PNG", "skin-key")
	fs:write("skins/example/mania-hit300g.png", "skin-static-judge")
	fs:write("skins/example/mania-note1L-0.png", "skin-body-0")
	fs:write("skins/example/mania-note1L-1.png", "skin-body-1")
	local skin = {path = "skins/example", files = {
		"MANIA-KEY1.PNG", "mania-hit300g.png", "mania-note1L-0.png", "mania-note1L-1.png",
	}}
	local graphics = OsuManiaSkinGraphics(fs, skin)
	local previous_read = love.filesystem.read
	local previous_new_image = love.graphics.newImage
	local previous_new_file_data = love.filesystem.newFileData
	local reads, loaded, released = 0, {}, 0
	love.filesystem.read = function(path)
		t:eq(path, "test-mania-fallback.zip")
		reads = reads + 1
		return archive_data
	end
	love.filesystem.newFileData = function(content) return content end
	love.graphics.newImage = function(data)
		loaded[#loaded + 1] = data
		return {
			data = data,
			getWidth = function() return 16 end,
			getHeight = function() return 16 end,
			release = function() released = released + 1 end,
		}
	end
	local ok, err = xpcall(function()
		graphics:setFallbackArchive("test-mania-fallback.zip")
		t:eq(reads, 1)
		t:eq(graphics:findAsset("mania-key1"), "skins/example/MANIA-KEY1.PNG")
		t:eq(graphics:findAsset("mania-stage-left"), "test-mania-fallback.zip/mania-stage-left@2x.png")
		graphics:load({{name = "mania-key1"}, {name = "mania-note1L", animation = true},
			{name = "mania-hit300g", animation = true},
			{name = "missing-custom-stage", fallback = "mania-stage-left"},
			{name = "custom-0", fallback = "score-0"}})
		t:tdeq(loaded, {"skin-key", "skin-body-0", "skin-body-1", "skin-static-judge", "default-stage", "default-digit"})
		local key = graphics:getFrames("mania-key1")[1]
		local stage = graphics:getFrames("missing-custom-stage", "mania-stage-left")[1]
		t:eq(graphics:getImageDensity(key), 1)
		t:eq(graphics:getImageDensity(stage), 2)
		t:eq(#graphics:getAnimationFrames("mania-note1L"), 2)
		t:eq(#graphics:getAnimationFrames("mania-hit300g"), 1)
		t:eq(#graphics:getFrames("not-in-skin-or-archive"), 0)
		t:eq(#loaded, 6)
		graphics:unload()
		t:eq(released, 6)
		graphics:setSkin(nil)
		graphics:load({{name = "mania-hit300g", animation = true}, {name = "mania-key1"}})
		t:eq(loaded[7], "default-judge")
		t:eq(loaded[8], "default-key")
		t:eq(reads, 1)
		local second = OsuManiaSkinGraphics(fs)
		second:setFallbackArchive("test-mania-fallback.zip")
		t:eq(reads, 1)
	end, debug.traceback)
	love.filesystem.read = previous_read
	love.graphics.newImage = previous_new_image
	love.filesystem.newFileData = previous_new_file_data
	graphics:unload()
	if not ok then error(err) end
end

function test.loads_oversized_skin_hold_body_instead_of_falling_back(t)
	local fs = FakeFilesystem()
	fs:createDirectory("skins/example")
	fs:write("skins/example/mania-note1L.png", "body")
	local graphics = OsuManiaSkinGraphics(fs, {
		path = "skins/example",
		files = {"mania-note1L.png"},
	})
	local image = {
		getDimensions = function() return 128, 16384 end,
		release = function() end,
	}
	local decoded = {
		getDimensions = function() return 128, 40000 end,
		getWidth = function() return 128 end,
		getHeight = function() return 40000 end,
		release = function() end,
	}
	local limited = {
		getDimensions = function() return 128, 16384 end,
		getWidth = function() return 128 end,
		getHeight = function() return 16384 end,
		paste = function() end,
		release = function() end,
	}
	local previous = {
		newFileData = love.filesystem.newFileData,
		newImage = love.graphics.newImage,
		newImageData = love.image.newImageData,
		getSystemLimits = love.graphics.getSystemLimits,
	}
	love.filesystem.newFileData = function() return {kind = "file"} end
	love.graphics.newImage = function(data)
		if data.kind == "file" then error("texture is too large") end
		return image
	end
	love.image.newImageData = function(width_or_data)
		if type(width_or_data) == "number" then return limited end
		return decoded
	end
	love.graphics.getSystemLimits = function() return {texturesize = 16384} end

	local ok, err = xpcall(function()
		local frames = graphics:getAnimationFrames("mania-note1L")
		t:eq(frames[1], image)
	end, debug.traceback)
	for name, value in pairs(previous) do
		if name == "newFileData" then love.filesystem[name] = value
		else love.graphics[name] = value end
	end
	graphics:unload()
	if not ok then error(err) end
end

return test
