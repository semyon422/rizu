local pkg = require("aqua.pkg")

-- Common paths
pkg.addc()
pkg.addc("3rd-deps/lib")
pkg.addc("bin/lib")
pkg.addc("tree/lib/lua/5.1")

pkg.add() -- Root folder
pkg.add("3rd-deps/lua")
pkg.add("aqua")
pkg.add("ncdk")
pkg.add("chartbase")
pkg.add("libchart")
pkg.add("tree/share/lua/5.1")

-- Platform specific binaries
if jit then
	if jit.os == "Windows" then
		pkg.addc("bin/win64")
	elseif jit.os == "Linux" then
		pkg.addc("bin/linux64")
	elseif jit.os == "OSX" then
		pkg.addc("bin/mac64")
		pkg.addc("../Frameworks")
	end
end

pkg.export_lua()
if love and love.filesystem then
	pkg.export_love()
end
