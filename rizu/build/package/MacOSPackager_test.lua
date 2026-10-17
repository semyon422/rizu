local MacOSPackager = require("rizu.build.package.MacOSPackager")

local test = {}

---@param t testing.T
function test.portable_library_name(t)
	t:eq(MacOSPackager.getPortableLibraryName("/tmp/libavformat.62.dylib"), "libavformat.dylib")
	t:eq(MacOSPackager.getPortableLibraryName("/tmp/libssl.3.dylib"), "libssl.dylib")
	t:eq(MacOSPackager.getPortableLibraryName("/tmp/libbass.dylib"), "libbass.dylib")
end

return test
