local etlua = require("web.etlua")
local io_util = require("io_util")

local test = {}

---@param t testing.T
function test.profile_imports_render_accuracy_without_legacy_modules(t)
	local source = assert(io_util.read_file("sea/access/http/user.etlua"))
	local imports = assert(source:match("^(.-)<div"))
	local render = assert(etlua.compile(imports .. [[Accuracy: <%= math.floor(erfunc.erf(0.032 / (0.016 * math.sqrt(2))) * 100 + 0.5) %>]]))
	---@param name string
	---@return any
	local function release_require(name)
		assert(not name:match("^libchart%."), "legacy chart modules are not shipped in server releases")
		return require(name)
	end
	local html, err = render({require = release_require})
	t:assert(html, err)
	t:ne(assert(html):find("Accuracy: 95", 1, true), nil)
end

return test
