local BackgroundModel = require("sphere.ui.BackgroundModel")

local test = {}

---@param t testing.T
function test.http_background_starts_http_load(t)
	local model = BackgroundModel()
	model.path = "https://example.test/bg.jpg"
	model.emptyImage = "empty"

	function model:startHttpLoad(url)
		self.started_url = url
	end

	model:loadBackground()

	t:eq(model.started_url, "https://example.test/bg.jpg")
end

---@param t testing.T
function test.local_background_cancels_pending_http_load(t)
	local model = BackgroundModel()
	model.path = "local.jpg"
	model.http_url = "https://example.test/bg.jpg"
	model.emptyImage = "empty"

	function model:isValidImage()
		return true
	end

	function model:loadImage(path)
		return "image:" .. path
	end

	function model:setBackground(image)
		self.background = image
	end

	model:loadBackground()

	t:eq(model.http_url, nil)
	t:eq(model.background, "image:local.jpg")
end

return test
