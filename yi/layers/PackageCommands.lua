local repo = require("rizu.pkg.repo")

---@param game sphere.GameController
---@return yi.command_palette.Fuzzy.Candidate[] choices
local function getInstalledPackageChoices(game)
	---@type yi.command_palette.Fuzzy.Candidate[]
	local choices = {}
	for _, pkg in ipairs(game.packageManager:getPackages()) do
		table.insert(choices, {
			title = ("%s v%s by %s"):format(pkg.display_name, pkg.version, pkg.creator),
			value = pkg.name,
		})
	end
	return choices
end

---@return yi.command_palette.Fuzzy.Candidate[] choices
local function getRemotePackageChoices()
	---@type yi.command_palette.Fuzzy.Candidate[]
	local choices = {}
	for _, pkg_info in ipairs(repo) do
		table.insert(choices, {
			title = pkg_info.display_name,
			value = pkg_info,
		})
	end
	return choices
end

---@param game sphere.GameController
---@return yi.command_palette.Command[]
return function(game)
	return {
		{
			id = "packages.open_folder",
			title = "Packages: Open Folder",
			description = "Opens the package directory",
			callback = function()
				love.system.openURL(game.packageManager.pkgs_path)
			end,
		},
		{
			id = "packages.open_installed_folder",
			title = "Packages: Open Installed Package",
			description = "Opens an installed package folder",
			arguments = {
				{
					name = "package",
					type = "string",
					prompt = "Select package:",
					choices = function()
						return getInstalledPackageChoices(game)
					end,
				},
			},
			callback = function(args)
				local path = game.packageManager:getPackageRealPath(args.package)
				if path then
					love.system.openURL(path)
				end
			end,
		},
		{
			id = "packages.download",
			title = "Packages: Download",
			description = "Downloads a known remote package",
			arguments = {
				{
					name = "package",
					type = "string",
					prompt = "Select package:",
					choices = getRemotePackageChoices(),
				},
			},
			callback = function(args)
				game.packageManager.packageDownloader:download(args.package)
			end,
		},
		{
			id = "packages.open_source",
			title = "Packages: Open Source",
			description = "Opens a known remote package source URL",
			arguments = {
				{
					name = "package",
					type = "string",
					prompt = "Select package:",
					choices = getRemotePackageChoices(),
				},
			},
			callback = function(args)
				love.system.openURL(args.package.source)
			end,
		},
	}
end
