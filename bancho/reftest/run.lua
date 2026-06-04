#!/usr/bin/env luajit
--- Bancho Reftest Runner
---
--- Runs all reference server tests against configured servers.
--- Usage: ./luajit bancho/reftest/run.lua

local reftest = require("bancho.reftest.init")
reftest.setup_modules()
reftest.ensure_deps()

-- Import test modules.
local login_test = require("bancho.reftest.login_reftest")
local score_test = require("bancho.reftest.score_reftest")
local presence_test = require("bancho.reftest.presence_reftest")
local lobby_test = require("bancho.reftest.lobby_reftest")
local chat_test = require("bancho.reftest.chat_reftest")
local social_test = require("bancho.reftest.social_reftest")
local match_test = require("bancho.reftest.match_reftest")
local match_advanced_test = require("bancho.reftest.match_advanced_reftest")
local spectating_test = require("bancho.reftest.spectating_reftest")
local messaging_test = require("bancho.reftest.messaging_reftest")
local http_test = require("bancho.reftest.http_reftest")
local web_test = require("bancho.reftest.web_reftest")

-- ============================================================================
-- Server runner
-- ============================================================================

local function run_tests_for_server(srv)
	reftest.current_server = srv.name
	io.write(string.format("\n========== Testing %s (%s://%s:%s) ==========\n",
		srv.name, srv.scheme, srv.host, srv.port))

	-- Register users.
	local u1, _, p1 = reftest.register_user(srv)
	if not u1 then
		io.write(string.format("  [SKIP] Could not register user on %s\n", srv.name))
		return
	end
	io.write(string.format("  Registered: %s\n", u1))

	local u2, _, p2 = reftest.register_user(srv)
	if not u2 then
		io.write(string.format("  Warning: Could not register second user\n"))
	end

	-- Third user for two-player host (avoids session conflict on bancho.py).
	local u3, _, p3 = reftest.register_user(srv)
	if u3 then
		io.write(string.format("  Registered: %s\n", u3))
	end

	-- Login and login packets.
	local c1, uid1 = login_test.run(srv, u1, p1)

	-- Single-player tests.
	if c1 then
		presence_test.run(c1)
		lobby_test.run(c1)
		chat_test.run(c1)
		social_test.run(c1, u1, uid1)
	end

	-- Two-player tests.
	-- Use u3 (fresh user) as host to avoid session conflict on bancho.py.
	if not u2 or not c1 then
		io.write(string.format("  [DEBUG] Skipping two-player tests: u2=%s c1=%s\n", tostring(u2), tostring(c1 ~= nil)))
	else
		match_test.run_complete_fail(c1)
		local c2, uid2, err2 = reftest.login(srv, u2, p2)
		if not c2 then
			io.write(string.format("  [DEBUG] c2 login failed for %s: %s\n", srv.name, tostring(err2)))
		else
			-- Use u3 as host (fresh session, no conflict).
			local c1_fresh, uid1_fresh, err1
			if u3 then
				c1_fresh, uid1_fresh, err1 = reftest.login(srv, u3, p3)
			else
				-- Fallback: re-login u1 (may fail on bancho.py).
				c1:logout()
				os.execute("sleep 11")
				c1_fresh, uid1_fresh, err1 = reftest.login(srv, u1, p1)
			end
			if not c1_fresh then
				io.write(string.format("  [DEBUG] c1 re-login failed for %s: %s\n", srv.name, tostring(err1)))
			else
				match_test.run_lifecycle(c1_fresh, c2)
				spectating_test.run(c1_fresh, c2)
				messaging_test.run(c1_fresh, c2)
				match_advanced_test.run_password(c1_fresh, c2)
				match_advanced_test.run_mods_team(c1_fresh, c2)
				match_advanced_test.run_skip(c1_fresh, c2)
				match_advanced_test.run_invite(c1_fresh, c2)
				match_advanced_test.run_transfer_host(c1_fresh, c2)
				match_advanced_test.run_states(c1_fresh, c2)
			end
		end
	end

	-- HTTP and web tests (pass MD5 hash for auth).
	http_test.run(srv, u1, reftest.md5.sumhexa(p1))
	web_test.run(srv)

	-- Score submission test (needs token from login).
	if c1 then
		score_test.run(srv, u1, reftest.md5.sumhexa(p1))
	end
end

-- ============================================================================
-- Report
-- ============================================================================

local function print_report()
	io.write("\n\n")
	io.write("============================================\n")
	io.write("           TEST REPORT SUMMARY              \n")
	io.write("============================================\n\n")

	for _, srv in ipairs(reftest.servers) do
		io.write(string.format("--- %s ---\n", srv.name))
		local pass, fail, skip = 0, 0, 0
		local fail_details = {}

		for _, r in ipairs(reftest.results) do
			if r.server ~= srv.name then goto continue end
			if r.status == "PASS" then pass = pass + 1
			elseif r.status == "FAIL" then
				fail = fail + 1
				table.insert(fail_details, r)
			else
				skip = skip + 1
			end
			::continue::
		end

		io.write(string.format("  PASS: %d  FAIL: %d  SKIP: %d  Total: %d\n",
			pass, fail, skip, pass + fail + skip))

		if #fail_details > 0 then
			io.write("\n  Failed tests:\n")
			for _, f in ipairs(fail_details) do
				io.write(string.format("    - %s: %s\n", f.name, f.detail))
			end
		end
		io.write("\n")
	end

	-- Comparison matrix.
	io.write("============================================\n")
	io.write("           COMPARISON MATRIX                \n")
	io.write("============================================\n\n")

	local features = {}
	for _, r in ipairs(reftest.results) do
		if not features[r.name] then features[r.name] = {} end
		features[r.name][r.server] = r.status
	end

	io.write(string.format("%-30s %s %s\n", "Feature", "our_server", "bancho.py"))
	io.write(string.rep("-", 65) .. "\n")

	for name, statuses in pairs(features) do
		local our = statuses["our_server"] or "-"
		local bancho = statuses["bancho.py"] or "-"
		local diff = (our == bancho) and "" or " <-- DIFF"
		io.write(string.format("%-30s %-10s %-10s%s\n", name, our, bancho, diff))
	end

	io.write("\n")
	io.write(string.rep("=", 65) .. "\n")
	io.write("Legend: PASS = works, FAIL = broken, SKIP = skipped\n")
	io.write("        <-- DIFF = behavior differs between servers\n")
	io.write(string.rep("=", 65) .. "\n")
end

-- ============================================================================
-- Entry point
-- ============================================================================

local function main()
	io.write("=== Bancho Feature Test Suite ===\n")
	io.write(string.format("Started: %s\n", os.date("%Y-%m-%d %H:%M:%S")))

	for _, srv in ipairs(reftest.servers) do
		run_tests_for_server(srv)
	end

	print_report()
	io.write(string.format("\nCompleted: %s\n", os.date("%Y-%m-%d %H:%M:%S")))
	io.write(string.format("Total tests run: %d\n", reftest.test_num))
end

main()
