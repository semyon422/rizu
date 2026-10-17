local LocationDirectoryOpener = require("rizu.select.services.LocationDirectoryOpener")

local test = {}

---@param t testing.T
function test.absolute_path(t)
	local opened
	local opener = LocationDirectoryOpener(
		function()
			return "/game"
		end,
		function()
			return "/base"
		end,
		function(url)
			opened = url
		end
	)

	opener:open({path = "/songs"}, "pack/chart")

	t:eq(opened, "/songs/pack/chart")
end

---@param t testing.T
function test.relative_path_uses_source_directory(t)
	local opener = LocationDirectoryOpener(
		function()
			return "/game"
		end,
		function()
			return "/base"
		end,
		function() end
	)

	t:eq(opener:getPath({path = "songs"}, "pack/chart"), "/game/songs/pack/chart")
end

---@param t testing.T
function test.love_bundle_uses_source_base_directory(t)
	local opener = LocationDirectoryOpener(
		function()
			return "/game/soundsphere.love"
		end,
		function()
			return "/base"
		end,
		function() end
	)

	t:eq(opener:getPath({path = "songs"}, "pack/chart"), "/base/songs/pack/chart")
end

return test
