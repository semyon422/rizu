local EditorOnsetsService = require("rizu.editor.view.EditorOnsetsService")

local test = {}

local function createContext(fields)
	return {
		getNcbtContext = function()
			return fields.ncbtContext
		end,
		getSessionTime = function()
			return fields.sessionTime
		end,
		getAudioStartTime = function()
			return fields.audioStartTime
		end,
	}
end

---@param t testing.T
function test.get_onsets_state_returns_nil_without_onsets(t)
	local state = EditorOnsetsService():getOnsetsState(createContext({
		ncbtContext = {},
	}), 2)

	t:eq(state, nil)
end

---@param t testing.T
function test.get_onsets_state_finds_visible_start_node(t)
	local node = {
		key = {
			time = 1.25,
		},
	}
	local service = EditorOnsetsService()
	local context = createContext({
		sessionTime = 3,
		audioStartTime = 1,
		ncbtContext = {
			onsets = {
				findex = function(_, time, getTime)
					t:eq(time, 1.5)
					t:eq(getTime(node.key), 1.25)
					return nil, node
				end,
			},
		},
	})

	local state = service:getOnsetsState(context, 2)

	t:ne(state, nil)
	---@cast state -nil
	t:eq(state.node, node)
	t:eq(state.time, 2)
	t:eq(service:isNodeVisible(state, {
		key = {
			time = 2.49,
		},
	}), true)
	t:eq(service:isNodeVisible(state, {
		key = {
			time = 2.5,
		},
	}), false)
end

---@param t testing.T
function test.get_distribution_state_returns_bins_and_distribution(t)
	local onsetsDeltaDist = {}
	local bins = {}
	local state = EditorOnsetsService():getDistributionState(createContext({
		ncbtContext = {
			onsetsDeltaDist = onsetsDeltaDist,
			bins = bins,
			binsSize = 16,
		},
	}))

	t:ne(state, nil)
	---@cast state -nil
	t:eq(state.onsetsDeltaDist, onsetsDeltaDist)
	t:eq(state.bins, bins)
	t:eq(state.binsSize, 16)
end

return test
