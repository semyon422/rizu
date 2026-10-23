local HudElementPicker = require("ui.modals.hud_element_picker.HudElementPicker")

local test = {}

---@param layers table[]
---@return table modal
---@return table state
local function new_modal(layers)
	local state = {added = {}, closed = 0}
	local modal = setmetatable({
		gameplay = {
			getHudElementTypes = function()
				return {{name = "score", label = "Score"}, {name = "combo", label = "Combo"}}
			end,
			getHudLayers = function() return layers end,
			addHudElement = function(_, name, layer)
				state.added[#state.added + 1] = {name, layer}
				return layer .. ":7"
			end,
		},
		localization = {get = function(_, key) return key end},
		on_close = function() state.closed = state.closed + 1 end,
		list = {
			anchorFixed = function() end,
			setItems = function(_, items, path) state.items, state.path = items, path end,
		},
		add_button = {setEnabled = function(_, enabled) state.add_enabled = enabled end},
		newLayerControl = function(_, params)
			return setmetatable({setPosition = function() end}, {__index = params})
		end,
		add = function(_, view) state.layer_control = view return view end,
		remove = function() end,
	}, {__index = HudElementPicker})
	return modal, state
end

---@param t testing.T
function test.adds_the_selected_type_to_the_only_layer(t)
	local modal, state = new_modal({{name = "screen", label = "Screen"}})
	local added_id
	modal:open(function(id) added_id = id end)
	t:tdeq(state.items, {{name = "Score", path = "score"}, {name = "Combo", path = "combo"}})
	t:eq(state.path, "score")
	t:eq(state.add_enabled, true)
	t:eq(state.layer_control, nil) -- nothing to choose

	modal:select(2)
	t:eq(modal.list.selected_path, "combo")
	modal:confirm()
	t:tdeq(state.added, {{"combo", "screen"}})
	t:eq(state.closed, 1)
	t:eq(added_id, "screen:7")
end

---@param t testing.T
function test.offers_a_layer_choice_when_there_is_a_conveyor(t)
	local modal, state = new_modal({{name = "screen", label = "Screen"}, {name = "conveyor", label = "Conveyor"}})
	modal:open(function() end)
	t:assert(state.layer_control)
	t:tdeq(state.layer_control.options, {"screen", "conveyor"})
	state.layer_control.on_change("conveyor")
	modal:confirm()
	t:tdeq(state.added, {{"score", "conveyor"}})
end

---@param t testing.T
function test.cannot_add_without_a_hud(t)
	local modal, state = new_modal({})
	modal:open(function() end)
	t:eq(state.add_enabled, false)
	modal:confirm()
	t:eq(#state.added, 0)
	t:eq(state.closed, 0)
end

return test
