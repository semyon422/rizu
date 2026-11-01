local View = require("gui.View")
local MenuButton = require("ui.screens.main_menu_v2.MenuButton")

---A fixed-width row of MenuButtons. At rest they share it equally; the hovered one widens to
---reveal its label while the others narrow, so the row's edges never move.
---@class ui.screens.main_menu_v2.MenuRow : gui.View
---@operator call: ui.screens.main_menu_v2.MenuRow
---@field gap number
---@field children ui.screens.main_menu_v2.MenuButton[]
local MenuRow = View + {}

-- A revealed button takes at most this share of the room the narrowest buttons leave.
local MAX_SHARE = 0.95

---@param gap number
function MenuRow:new(gap)
	View.new(self)
	self.gap = gap
end

---Room above the narrowest width that the buttons share.
---@return number
function MenuRow:getSpare()
	local n = #self.children
	return math.max(0, self.width - self.gap * (n - 1) - MenuButton.SIZE * n)
end

---@param dt number
function MenuRow:update(dt)
	local animating = false
	for _, button in ipairs(self.children) do
		local reveal = button.reveal
		reveal:set(button.mouse_over and 1 or 0)
		if reveal:isAnimating() then
			reveal:update(dt)
			animating = true
		end
	end
	-- shortcut: relayouts the screen every frame of a reveal, move widths to the visual channel if that shows up in frame times
	if animating then self:invalidate() end
end

function MenuRow:onLayoutChanged()
	local cap = MenuButton.SIZE + self:getSpare() * MAX_SHARE
	for _, button in ipairs(self.children) do
		button:fitLabel(cap)
	end
end

---Widths are SIZE plus a weighted share of the spare room. A button's weight grows with its reveal
---so that, revealed alone, it is exactly as wide as its label needs.
function MenuRow:arrange()
	local n = #self.children
	local spare = self:getSpare()
	local weights = {} ---@type number[]
	local total = 0
	for i, button in ipairs(self.children) do
		local share = spare > 0 and math.min(MAX_SHARE, (button.full_width - MenuButton.SIZE) / spare) or 0
		local k = math.max(0, (share * n - 1) / (1 - share))
		weights[i] = 1 + math.max(0, button.reveal:get()) * k
		total = total + weights[i]
	end
	local x = 0 ---@type number
	for i, button in ipairs(self.children) do
		local width = MenuButton.SIZE + spare * weights[i] / total ---@type number
		button.arranged = {x, 0, width, self.height}
		x = x + width + self.gap
	end
end

return MenuRow
