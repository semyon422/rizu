local AsyncDlcInstaller = require("rizu.dlc.AsyncDlcInstaller")

local test = {}

---@param t testing.T
function test.install_delegates_to_async_function(t)
	local called
	local installer = AsyncDlcInstaller(function(id, _type, data, filename, metadata)
		called = {id = id, type = _type, data = data, filename = filename, metadata = metadata}
		return true
	end)

	local metadata = {dest_dir = "userdata/charts/downloads/Song"}
	local ok, err = installer:install(123, "file", "data", "chart.osu", metadata)

	t:eq(err, nil)
	t:eq(ok, true)
	t:tdeq(called, {
		id = 123,
		type = "file",
		data = "data",
		filename = "chart.osu",
		metadata = metadata,
	})
end

---@param t testing.T
function test.install_returns_async_error(t)
	local installer = AsyncDlcInstaller(function()
		return nil, "boom"
	end)

	local ok, err = installer:install(123, "set", "data", "song.osz")

	t:eq(ok, nil)
	t:eq(err, "boom")
end

return test
