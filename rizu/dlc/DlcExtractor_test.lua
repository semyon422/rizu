local DlcExtractor = require("rizu.dlc.DlcExtractor")
local ZipFilesystem = require("fs.ZipFilesystem")
local FakeFilesystem = require("fs.FakeFilesystem")

local test = {}

---@param t testing.T
function test.extract_flat(t)
	local fs = FakeFilesystem()
	
	-- Create a zip with files at root
	local zfs = ZipFilesystem()
	zfs:write("file1.txt", "content1")
	zfs:write("file2.txt", "content2")
	local zip_data = zfs:save()
	
	local zip_path = "test.zip"
	fs:write(zip_path, zip_data)
	
	local extract_path = "extracted"
	fs:createDirectory(extract_path)
	
	local ok, err = DlcExtractor.extract(zip_path, extract_path, fs)
	t:assert(ok, err)
	
	t:assert(fs:getInfo("extracted/file1.txt"))
	t:assert(fs:getInfo("extracted/file2.txt"))
end

---@param t testing.T
function test.extract_nested(t)
	local fs = FakeFilesystem()
	
	-- Create a zip with 1 folder at root
	local zfs = ZipFilesystem()
	zfs:createDirectory("InnerFolder")
	zfs:write("InnerFolder/file1.txt", "content1")
	zfs:write("InnerFolder/file2.txt", "content2")
	local zip_data = zfs:save()
	
	local zip_path = "nested.zip"
	fs:write(zip_path, zip_data)
	
	local extract_path = "extracted"
	fs:createDirectory(extract_path)
	
	local ok, err = DlcExtractor.extract(zip_path, extract_path, fs)
	t:assert(ok, err)
	
	-- Should extract contents of InnerFolder directly into extract_path
	t:assert(fs:getInfo("extracted/file1.txt"), "file1.txt should be in root of extract_path")
	t:assert(fs:getInfo("extracted/file2.txt"), "file2.txt should be in root of extract_path")
	t:assert(not fs:getInfo("extracted/InnerFolder"), "InnerFolder should have been flattened")
end

return test
