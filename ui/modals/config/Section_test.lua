local Section = require("ui.modals.config.Section")

local test = {}

---@param t testing.T
function test.build_uses_state_and_invalidation(t)
	local invalidated = false
	local section = Section({
		name = "Audio",
		icon = {}, ---@diagnostic disable-line
		build = function(current)
			return {current.state.mode}
		end,
	})
	section.state.mode = "linear"
	section:setInvalidator(function() invalidated = true end)

	t:tdeq(section:build(), {"linear"})
	section:invalidate()
	t:eq(invalidated, true)
end

return test
