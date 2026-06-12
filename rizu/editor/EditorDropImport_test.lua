local EditorDropImport = require("rizu.editor.EditorDropImport")
local FakeFilesystem = require("fs.FakeFilesystem")

local test = {}

local function createFile(path, data)
	return {
		getFilename = function()
			return path
		end,
		read = function()
			return data
		end,
	}
end

---@param t testing.T
function test.import_writes_supported_audio_file(t)
	local fs = FakeFilesystem()
	local importer = EditorDropImport(fs, function()
		return 123
	end)

	local path = importer:import(createFile("drop\\song.ogg", "audio-data"))

	t:eq(path, "userdata/charts/editor/123 song/song.ogg")
	t:eq(fs:read(path), "audio-data")
end

---@param t testing.T
function test.import_accepts_file_without_directory(t)
	local fs = FakeFilesystem()
	local importer = EditorDropImport(fs, function()
		return 456
	end)

	local path = importer:import(createFile("song.mp3", "mp3-data"))

	t:eq(path, "userdata/charts/editor/456 song/song.mp3")
	t:eq(fs:read(path), "mp3-data")
end

---@param t testing.T
function test.import_ignores_unsupported_extension(t)
	local fs = FakeFilesystem()
	local importer = EditorDropImport(fs, function()
		return 789
	end)

	local path = importer:import(createFile("drop/song.wav", "wav-data"))

	t:eq(path, nil)
	t:eq(fs:read("userdata/charts/editor/789 song/song.wav"), nil)
end

return test
