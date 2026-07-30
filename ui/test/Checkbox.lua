local Checkbox = require("ui.views.form.Checkbox")
local Textbox = require("ui.views.form.Textbox")
local Slider = require("ui.views.form.Slider")
local DropdownHost = require("ui.views.DropdownHost")
local Colors = require("ui.Colors")
local coloredRect = require("ui.test.ColoredRect")

---@type ui.test.TestCase
local case = {
	name = "checkbox",
	build = function(root)
		local bg = coloredRect(Colors.panel[1], Colors.panel[2], Colors.panel[3])
		bg:anchorFill(0, 0, 0, 0)
		root:add(bg)

		local host = DropdownHost()
		host.arrange_strategy = nil
		host:anchorFill(0, 0, 0, 0)
		root:add(host)

		local c1 = Checkbox({text = "Enable feature"})
		c1:setPosition(200, 200)
		host:add(c1)

		local c2 = Checkbox({text = "Show notifications", checked = true})
		c2:setPosition(200, 250)
		host:add(c2)

		local c3 = Checkbox({text = "Automatically update"})
		c3:setPosition(200, 300)
		host:add(c3)

		local textbox = Textbox({
			label = "Display name",
			placeholder = "Enter your display name",
			width = 300,
		})
		textbox:setPosition(200, 350)
		host:add(textbox)

		local slider = Slider({
			label = "Music volume",
			value = 0.6,
			width = 300,
		})
		slider:setPosition(200, 435)
		host:add(slider)

		local below_checkbox = Checkbox({text = "This should be below the dropdown"})
		below_checkbox:setPosition(200, 590)
		host:add(below_checkbox)

		local below_slider = Slider({
			label = "Effects volume",
			value = 0.35,
			width = 300,
		})
		below_slider:setPosition(200, 640)
		host:add(below_slider)

		local below_textbox = Textbox({
			label = "Notes",
			placeholder = "Text under dropdown",
			width = 300,
		})
		below_textbox:setPosition(200, 706)
		host:add(below_textbox)
	end,
}

return case
