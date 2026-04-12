---@param t {[string]: any|table}
function love.conf(t)
	t.identity = nil
	t.appendidentity = true
	t.console = true
	t.accelerometerjoystick = true
	t.graphics.gammacorrect = false

	t.window = nil

	t.modules.audio = true
	t.modules.event = true
	t.modules.graphics = true
	t.modules.image = true
	t.modules.joystick = true
	t.modules.keyboard = true
	t.modules.math = true
	t.modules.mouse = true
	t.modules.physics = false
	t.modules.sound = true
	t.modules.system = true
	t.modules.timer = true
	t.modules.touch = true
	t.modules.video = true
	t.modules.window = true
	t.modules.thread = true
end
