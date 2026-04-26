local Dd32Spec = require("rizu.build.deps.spec.common.Dd32Spec")

local MacOSCross = {}

MacOSCross.DARWIN_CC = "x86_64-apple-darwin22.2-clang"
MacOSCross.DARWIN_TRIPLE = "x86_64-apple-darwin22.2"
MacOSCross.TOOLCHAIN_BIN = "${root_abs}/build/deps/osxcross/target/bin"

---@param tc_bin string
---@return string
function MacOSCross.cc(tc_bin)
	return tc_bin .. "/" .. MacOSCross.DARWIN_CC
end

---@param tc_bin string
---@return {[string]: string}
function MacOSCross.env(tc_bin)
	return {
		PATH = tc_bin .. ":$PATH",
		CC = MacOSCross.cc(tc_bin),
		AR = tc_bin .. "/" .. MacOSCross.DARWIN_TRIPLE .. "-ar",
		RANLIB = tc_bin .. "/" .. MacOSCross.DARWIN_TRIPLE .. "-ranlib",
	}
end

---@param tc_bin string
---@return {[string]: string}
function MacOSCross.envWithDd(tc_bin)
	return Dd32Spec.extendEnv(MacOSCross.env(tc_bin))
end

return MacOSCross
