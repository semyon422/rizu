local BackgroundModel = require("sphere.ui.BackgroundModel")

local test = {}

---@param t testing.T
function test.network_is_required(t)
	local ok, err = pcall(function()
		BackgroundModel()
	end)

	t:eq(ok, false)
	t:assert(tostring(err):find("network is required", 1, true))
end

---@param t testing.T
function test.http_image_uses_network_request(t)
	local old_love = love
	love = {
		graphics = {
			newImage = function(image_data)
				return {image_data = image_data}
			end,
		},
	}

	local requested_url
	local network = {
		request = function(_, url)
			requested_url = url
			return {status = 200, body = "image-body"}
		end,
	}

	local decoded
	local model = BackgroundModel(network --[[@as any]], function(body, url)
		decoded = {body = body, url = url}
		return "image-data" --[[@as any]]
	end)

	local ok, image = pcall(function()
		return model:loadImage("https://example.test/bg.jpg", "http")
	end)
	love = old_love
	if not ok then
		error(image, 0)
	end

	t:eq(requested_url, "https://example.test/bg.jpg")
	t:tdeq(decoded, {body = "image-body", url = "https://example.test/bg.jpg"})
	t:tdeq(image, {image_data = "image-data"})
end

---@param t testing.T
function test.http_image_ignores_http_errors(t)
	local network = {
		request = function()
			return {status = 404, body = "missing"}
		end,
	}
	local model = BackgroundModel(network --[[@as any]], function()
		error("decoder should not be called")
	end)

	t:eq(model:loadImage("https://example.test/missing.jpg", "http"), nil)
end

---@param t testing.T
function test.stale_background_search_is_ignored(t)
	local model = BackgroundModel({} --[[@as any]])
	model.path = "old"
	model.background_finder = function()
		coroutine.yield()
		return "old/bg.jpg"
	end
	model.loadImage = function() error("obsolete image must not be loaded") end
	local co = coroutine.create(function() model:loadBackground() end)
	t:assert(coroutine.resume(co))
	model.path = "new"
	model.generation = model.generation + 1
	t:assert(coroutine.resume(co))
	t:eq(coroutine.status(co), "dead")
	t:eq(model.path, "new")
end

return test
