local class = require("class")

---@class rizu.PackageRequire
---@operator call: rizu.PackageRequire
local PackageRequire = class()

---@param pkgs rizu.Package[]
function PackageRequire:require(pkgs)
	for _, pkg in ipairs(pkgs) do
		require(pkg.types.require)
	end
end

return PackageRequire
