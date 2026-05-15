package.loaded["libchart.erfunc"] = require("erfunc")
local normalscore = require("normalscore2")

local ns = normalscore()

local function r()
	return math.random() * 2 - 1
end

do
	local time = os.time()
	for i = 1, 3 do -- 0 seconds
		ns:press(r(), {r(), r()})
	end
	print(os.time() - time)

	time = os.time()
	for i = 1, 1e9 do -- 1 seconds
		ns:update()
	end
	print(os.time() - time)
end

do
	local time = os.time()
	for i = 1, 1e4 do -- 0 seconds
		ns:press(r(), {r(), r()})
	end
	print(os.time() - time)

	time = os.time()
	for i = 1, 1e2 do -- 1 seconds
		ns:update()
	end
	print(os.time() - time)
end
