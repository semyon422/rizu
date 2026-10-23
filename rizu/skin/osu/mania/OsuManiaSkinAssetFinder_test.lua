local Finder = require("rizu.skin.osu.mania.OsuManiaSkinAssetFinder")
local BatchPlan = require("rizu.skin.osu.mania.OsuManiaBatchPlan")

local test = {}

function test.finds_playfield_and_standalone_assets(t)
	local finder = Finder({
		section = {
			NoteImage0 = "custom/note",
			KeyImage0 = "custom/key",
			StageHint = "custom/hint",
			StageBottom = "custom/bottom",
		},
		columns = 1,
		column_suffixes = {"1"},
	})
	local requests = finder:find()
	local by_name = {}
	for _, request in ipairs(requests) do by_name[request.name or request.fallback] = request end

	t:eq(by_name["custom/note"].role, "note")
	t:eq(by_name["custom/key"].role, "key")
	t:eq(by_name["custom/bottom"].role, "stage_decoration")
	t:assert(by_name["mania-note1L"].animation)
	t:eq(by_name["score-0"], nil) -- HUD elements request their own textures
end

function test.batch_plan_is_the_atlas_boundary(t)
	local plan = BatchPlan()
	local assets = plan:build({
		{name = "note", animation = true, role = "note"},
		{name = "stage", animation = false, role = "stage_decoration"},
	})
	t:eq(assets[1].group, "playfield")
	t:eq(assets[2].group, "standalone")
	t:eq(plan:getGroup("lighting"), "standalone")
	t:eq(pcall(plan.getGroup, plan, "score_font"), false)
end

return test
