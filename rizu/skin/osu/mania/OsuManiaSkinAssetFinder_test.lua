local Finder = require("rizu.skin.osu.mania.OsuManiaSkinAssetFinder")
local BatchPlan = require("rizu.skin.osu.mania.OsuManiaBatchPlan")

local test = {}

function test.finds_playfield_fonts_and_standalone_assets(t)
	local finder = Finder({
		section = {
			NoteImage0 = "custom/note",
			KeyImage0 = "custom/key",
			StageHint = "custom/hint",
			StageBottom = "custom/bottom",
		},
		columns = 1,
		column_suffixes = {"1"},
		score_assets = {"digits-0"},
		accuracy_assets = {"digits-percent"},
		combo_assets = {"combo-0"},
		judge_assets = {{name = "custom/judge", fallback = "mania-hit300g"}},
	})
	local requests = finder:find()
	local by_name = {}
	for _, request in ipairs(requests) do by_name[request.name or request.fallback] = request end

	t:eq(by_name["custom/note"].role, "note")
	t:eq(by_name["custom/key"].role, "key")
	t:eq(by_name["digits-0"].role, "score_font")
	t:eq(by_name["combo-0"].role, "combo_font")
	t:eq(by_name["custom/judge"].role, "judgement")
	t:eq(by_name["custom/bottom"].role, "stage_decoration")
	t:eq(by_name["circularmetre"].role, "progress")
	t:assert(by_name["mania-note1L"].animation)
end

function test.batch_plan_is_the_atlas_boundary(t)
	local plan = BatchPlan()
	local assets = plan:build({
		{name = "note", animation = true, role = "note"},
		{name = "score", animation = false, role = "score_font"},
		{name = "stage", animation = false, role = "stage_decoration"},
	})
	t:eq(assets[1].group, "playfield")
	t:eq(assets[2].group, "font")
	t:eq(assets[3].group, "standalone")
	t:eq(plan:getGroup("judgement"), "playfield")
end

return test
