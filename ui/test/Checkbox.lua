local Checkbox = require("ui.views.Checkbox")
local Slider = require("ui.views.Slider")
local Textbox = require("ui.views.Textbox")
local coloredRect = require("ui.test.ColoredRect")

---@type ui.test.TestCase
local case = {
	name = "checkbox",
	build = function(root)
		local bg = coloredRect(0.08, 0.08, 0.1)
		bg:anchorFill(0, 0, 0, 0)
		root:add(bg)

		local c1 = Checkbox({text = "Enable feature"})
		c1:setPosition(200, 200)
		root:add(c1)

		local c2 = Checkbox({text = "Show notifications", checked = true})
		c2:setPosition(200, 250)
		root:add(c2)

		local slider = Slider({
			value = 0.5,
			on_change = function(value)
				print("slider value", value)
			end,
		})
		slider:setPosition(200, 300)
		root:add(slider)

		local textbox = Textbox({text = "Type here"})
		textbox:setPosition(200, 350)
		root:add(textbox)

		local second_textbox = Textbox({text = "And here"})
		second_textbox:setPosition(200, 400)
		root:add(second_textbox)
	end,
}

return case
