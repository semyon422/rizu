local assertions = require("rizu.build.deps.actions.assertions")

local test = {}

---@param t testing.T
function test.assert_file_accepts_symlinked_file(t)
	local fs = {}
	function fs:getInfo(path)
		if path == "lib/libavcodec.so.62" then
			return {type = "symlink"}
		end
	end

	local result = assertions.assert_file({ctx = {fs = fs}, bin_dirs = {}}, {path = "lib/libavcodec.so.62"})

	t:eq(result.ok, true)
end

return test
