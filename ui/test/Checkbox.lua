local Checkbox = require("ui.views.Checkbox")
local Slider = require("ui.views.Slider")
local Textbox = require("ui.views.Textbox")
local coloredRect = require("ui.test.ColoredRect")

---@type ui.test.TestCase
local case = {
	name = "checkbox",
	build = function(root)
		local bg = coloredRect(0.08, 0.08, 0.1)
		bg.anchor_max = {1, 1}
		root:add(bg)

		local c1 = Checkbox({text = "Enable feature"})
		c1.offset_min = {200, 200}
		c1.offset_max = {200 + c1.width, 200 + c1.height}
		root:add(c1)

		local c2 = Checkbox({text = "Show notifications", checked = true})
		c2.offset_min = {200, 250}
		c2.offset_max = {200 + c2.width, 250 + c2.height}
		root:add(c2)

		local slider = Slider({
			value = 0.5,
			on_change = function(value)
				print("slider value", value)
			end,
		})
		slider.offset_min = {200, 300}
		slider.offset_max = {200 + slider.width, 300 + slider.height}
		root:add(slider)

		local textbox = Textbox({text = "Type here"})
		textbox.offset_min = {200, 350}
		textbox.offset_max = {200 + textbox.width, 350 + textbox.height}
		root:add(textbox)

		local second_textbox = Textbox({text = "And here"})
		second_textbox.offset_min = {200, 400}
		second_textbox.offset_max = {200 + second_textbox.width, 400 + second_textbox.height}
		root:add(second_textbox)
	end,
}

return case
