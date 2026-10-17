local Slider = require("ui.views.form.Slider")

local test = {}

---@param t testing.T
function test.form_keys_adjust_value_by_step(t)
	local notified
	local slider = {
		min = 0,
		max = 10,
		value = 5,
		step = 2,
		setValue = Slider.setValue,
		on_change = function(value)
			notified = value
		end,
	}

	t:eq(Slider.onFormKeyDown(slider, {key = "right"}), true)
	t:eq(slider.value, 7)
	t:eq(notified, 7)
	t:eq(Slider.onFormKeyDown(slider, {key = "left"}), true)
	t:eq(slider.value, 5)
	t:eq(Slider.onFormKeyDown(slider, {key = "up"}), false)
end

---@param t testing.T
function test.form_keys_clamp_value(t)
	local slider = {
		min = 0,
		max = 1,
		value = 1,
		step = 0.25,
		setValue = Slider.setValue,
	}

	t:eq(Slider.onFormKeyDown(slider, {key = "right"}), true)
	t:eq(slider.value, 1)
end

return test
