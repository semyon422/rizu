local dirs = {}

local dirs_list = {
	"userdata",
	"userdata/pkg",
	"userdata/skins",
	"userdata/dlc",
	"userdata/dlc/skins_rizu",
	"userdata/dlc/skins_stepmania",
	"userdata/dlc/skins_osu",
	"userdata/dlc/skins_stepmania/dance",
	"userdata/dlc/skins_stepmania/kb7",
	"userdata/dlc/skins_stepmania/popn",
	"userdata/dlc/skins_stepmania/pump",
	"userdata/dlc/skins_stepmania/beat",
	"userdata/charts",
	"userdata/charts/downloads",
	"userdata/charts/mapperatorinator",
	"userdata/export",
	"userdata/hitsounds",
	"userdata/replays",
	"userdata/score_systems",
	"userdata/screenshots",
}

function dirs.create()
	for _, path in ipairs(dirs_list) do
		if not love.filesystem.getInfo(path) then
			love.filesystem.createDirectory(path)
		end
	end
end

return dirs
