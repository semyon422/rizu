local ComboView = require("rizu.skin.views.ComboView")

local test = {}

local font = {
	getWidth = function(_, text) return #text * 8 end,
	getHeight = function() return 20 end,
}

---@param t testing.T
function test.displays_current_combo_and_resizes(t)
	local combo_source = {getCombo = function() return 42 end}
	local game = {rhythm_engine = {score_engine = {comboSource = combo_source}}}
	local view = ComboView(font)
	view:load(game)

	t:eq(view.text, "42")
	t:eq(view.width, 16)
	t:eq(view.height, 20)
	t:eq(view.anchor, "center")

	combo_source.getCombo = function() return 7 end
	view:update(0, game)
	t:eq(view.text, "7")
	t:eq(view.width, 8)
end

---@param t testing.T
function test.empty_when_combo_source_is_missing(t)
	local view = ComboView(font)
	view:update(0, {rhythm_engine = {score_engine = {}}})
	t:eq(view.text, "")
	t:eq(view.width, 0)
end

return test
