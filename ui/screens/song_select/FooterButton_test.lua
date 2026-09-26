local FooterButton = require("ui.screens.song_select.FooterButton")

local test = {}

local function newButton()
	local button = setmetatable({
		large = false,
		badge = nil,
		text = "MODS",
		padding_x = 17,
		min_width = 0,
		button_height = 46,
		font = {getWidth = function(_, text) return #text * 10 end},
		setSize = function(self, width, height)
			self.width = width
			self.height = height
		end,
	}, {__index = FooterButton})
	button:updateSize()
	return button
end

---@param t testing.T
function test.text_changes_resize_button_and_layout_track(t)
	local button = newButton()
	t:eq(button:getPreferredWidth(), 24 + 9 + 40 + 34)

	button:setText("MUTATORS")
	t:eq(button:getPreferredWidth(), 24 + 9 + 80 + 34)

	button:setBadge("1")
	t:eq(button:getPreferredWidth(), 24 + 9 + 80 + 9 + 20 + 34)
end

return test
