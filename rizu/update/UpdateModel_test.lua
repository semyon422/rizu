local Updater = require("rizu.update.Updater")
local class = require("class")
local json = require("json")
local table_util = require("table_util")

local FakeUIO = class()

function FakeUIO:new()
	self.downloaded = {}
	self.removed = {}
	self.hashed = {}
	self.crc32_by_path = {}
	self.data_by_url = {}
end

function FakeUIO:downloadAsync(url, path)
	if not path then
		return self.data_by_url[url]
	end
	table.insert(self.downloaded, {url, path})
	return true
end

function FakeUIO:removeAsync(path)
	table.insert(self.removed, path)
	return true
end

function FakeUIO:crc32Async(path)
	table.insert(self.hashed, path)
	return self.crc32_by_path[path]
end

local test = {}

function test.clean_download(t)
	local uio = FakeUIO()

	local server_files = {
		{path = "a", hash = 0, url = "/a"},
		{path = "b", hash = 1, url = "/b"},
	}
	uio.data_by_url["/files.json"] = json.encode(server_files)

	local updater = Updater(uio)
	local ok, files = updater:updateFilesAsync("/files.json", {})

	t:eq(ok, true)
	t:tdeq(files, server_files)
	t:tdeq(uio.downloaded, {
		{"/a", "a"},
		{"/b", "b"},
	})
	t:eq(#uio.removed, 0)
	t:tdeq(uio.hashed, {
		"a",
		"b",
	})
end

function test.no_update(t)
	local uio = FakeUIO()

	local server_files = {
		{path = "a", hash = 0, url = "/a"},
		{path = "b", hash = 1, url = "/a"},
	}
	uio.data_by_url["/files.json"] = json.encode(server_files)
	uio.crc32_by_path = {
		a = 0,
		b = 1,
	}

	local updater = Updater(uio)
	local ok, files = updater:updateFilesAsync("/files.json", {
		{path = "a", hash = 0},
		{path = "b", hash = 1},
	})

	t:assert(not ok)
	t:eq(#uio.downloaded, 0)
	t:eq(#uio.removed, 0)
	t:eq(#uio.hashed, 0)
end

function test.add_remove_keep(t)
	local uio = FakeUIO()

	local server_files = {
		{path = "b", hash = 1, url = "/b"},
		{path = "c", hash = 2, url = "/c"},
	}
	uio.data_by_url["/files.json"] = json.encode(server_files)
	uio.crc32_by_path = {
		a = 0,
		b = 1,
	}

	local updater = Updater(uio)
	local ok, files = updater:updateFilesAsync("/files.json", {
		{path = "a", hash = 0, url = "/a"},
		{path = "b", hash = 1, url = "/b"},
	})

	t:tdeq(uio.downloaded, {
		{"/c", "c"},
	})
	t:tdeq(uio.removed, {
		"a",
	})
	t:tdeq(uio.hashed, {
		"c",
	})
end

function test.empty_local_list(t)
	local uio = FakeUIO()

	local server_files = {
		{path = "b", hash = 1, url = "/b"},
		{path = "c", hash = 2, url = "/c"},
	}
	uio.data_by_url["/files.json"] = json.encode(server_files)
	uio.crc32_by_path = {
		a = 0,
		b = 1,
	}

	local updater = Updater(uio)
	local ok, files = updater:updateFilesAsync("/files.json", {})

	t:tdeq(uio.downloaded, {
		{"/c", "c"},
	})
	t:eq(#uio.removed, 0)
	t:tdeq(uio.hashed, {
		"b",
		"c",
	})
end

function test.empty_local_list_wrong_hash(t)
	local uio = FakeUIO()

	local server_files = {
		{path = "b", hash = 1, url = "/b"},
		{path = "c", hash = 2, url = "/c"},
	}
	uio.data_by_url["/files.json"] = json.encode(server_files)
	uio.crc32_by_path = {
		b = 2,  -- <--
	}

	local updater = Updater(uio)
	local ok, files = updater:updateFilesAsync("/files.json", {})

	t:tdeq(uio.downloaded, {
		{"/b", "b"},
		{"/c", "c"},
	})
	t:eq(#uio.removed, 0)
	t:tdeq(uio.hashed, {
		"b",
		"c",
	})
end

return test
