local digest = require("digest")
local TableStorage = require("sea.chart.storage.TableStorage")
local ContentAddressedStorage = require("sea.chart.storage.ContentAddressedStorage")

local test = {}

---@param t testing.T
function test.validates_and_preserves_content(t)
	local base = TableStorage()
	local storage = ContentAddressedStorage(base)
	local value = "hello"
	local key = digest.hash("md5", value, true)

	t:assert(storage:set(key, value))
	t:eq(storage:get(key), value)
	t:assert(storage:set(key, value))

	base:set(key, "corrupt")
	local ok, err = storage:set(key, value)
	t:eq(ok, nil)
	t:eq(err, "stored content mismatch")
	t:eq(storage:get(key), "corrupt")
end

---@param t testing.T
function test.rejects_wrong_key(t)
	local storage = ContentAddressedStorage(TableStorage())
	local ok, err = storage:set("00000000000000000000000000000000", "hello")
	t:eq(ok, nil)
	t:eq(err, "content hash mismatch")
end

return test
