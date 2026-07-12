local NetworkDiagnostics = require("rizu.net.NetworkDiagnostics")

local test = {}

---@param t testing.T
function test.increment_and_fail_update_snapshot(t)
	local diagnostics = NetworkDiagnostics()

	diagnostics:increment("dns_requests")
	diagnostics:fail("http_failures", "request failed")

	local snapshot = diagnostics:snapshot()
	t:eq(snapshot.dns_requests, 1)
	t:eq(snapshot.http_failures, 1)
	t:eq(snapshot.last_error, "request failed")
end

---@param t testing.T
function test.snapshot_is_copy(t)
	local diagnostics = NetworkDiagnostics()

	local snapshot = diagnostics:snapshot()
	snapshot.dns_requests = 100

	t:eq(diagnostics:snapshot().dns_requests, 0)
end

return test
