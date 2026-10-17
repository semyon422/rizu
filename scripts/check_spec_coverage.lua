#!/usr/bin/env luajit

--[[
	Spec-to-Code Traceability Tool
	This script finds all spec.md files, extracts SPEC tags from their text,
	and checks if they are referenced in source files or tests.
]]

---@class util.SpecItem
---@field id string
---@field covered boolean
---@field locations string[]

---@class util.SpecFile
---@field path string
---@field items {[string]: util.SpecItem}

---@return {[string]: util.SpecFile}
local function get_specs()
	---@type {[string]: util.SpecFile}
	local specs = {}
	local handle = assert(io.popen('find . -name "spec.md"'))
	for path in handle:lines() do
		local clean_path = path:gsub("^%./", "")
		local file = io.open(path, "r")
		if file then
			local content = file:read("*a")
			file:close()

			local spec_file = {
				path = clean_path,
				items = {},
			}

			-- Search for [SPEC-*] in the text
			for spec_id in content:gmatch("%[(SPEC%-[^%]]+)%]") do
				spec_file.items[spec_id] = {
					id = spec_id,
					covered = false,
					locations = {},
				}
			end
			specs[clean_path] = spec_file
		end
	end
	handle:close()
	return specs
end

---@param specs {[string]: util.SpecFile}
local function check_coverage(specs)
	-- Search in all .lua files
	local handle = assert(io.popen('find . -name "*.lua"'))
	local unknown_refs = {}

	for file_path in handle:lines() do
		local file = io.open(file_path, "r")
		if file then
			local content = file:read("*a")
			file:close()

			-- Search for [SPEC-MOD-ID] or @spec spec_path#[SPEC-ID]
			for spec_id in content:gmatch("%[(SPEC%-[^%]]+)%]") do
				local found_in_any = false
				for _, spec in pairs(specs) do
					if spec.items[spec_id] then
						spec.items[spec_id].covered = true
						table.insert(spec.items[spec_id].locations, file_path)
						found_in_any = true
					end
				end

				if not found_in_any then
					table.insert(unknown_refs, {file = file_path, ref = spec_id, reason = "SPEC ID not found in any spec.md"})
				end
			end

			-- Support for the legacy/explicit @spec tag if needed
			for spec_ref in content:gmatch("@spec%s+([^\r\n%s]+)") do
				local spec_path, spec_id = spec_ref:match("([^#]+)#(.*)")
				if spec_path and spec_id then
					local spec = specs[spec_path]
					if spec then
						local item = spec.items[spec_id]
						if item then
							item.covered = true
							table.insert(item.locations, file_path)
						else
							table.insert(unknown_refs, {file = file_path, ref = spec_ref, reason = "SPEC ID not found in " .. spec_path})
						end
					else
						table.insert(unknown_refs, {file = file_path, ref = spec_ref, reason = "Spec file not found: " .. spec_path})
					end
				end
			end
		end
	end
	handle:close()
	return unknown_refs
end

---@param specs {[string]: util.SpecFile}
---@param unknown_refs table[]
local function report(specs, unknown_refs)
	local total = 0
	local covered = 0
	print("\n=== Specification Traceability Report ===")

	local sorted_paths = {}
	for path in pairs(specs) do table.insert(sorted_paths, path) end
	table.sort(sorted_paths)

	for _, path in ipairs(sorted_paths) do
		local spec = specs[path]
		print(string.format("\nFile: %s", path))

		local sorted_items = {}
		for _, item in pairs(spec.items) do table.insert(sorted_items, item) end
		table.sort(sorted_items, function(a, b) return a.id < b.id end)

		for _, item in ipairs(sorted_items) do
			total = total + 1
			if item.covered then
				covered = covered + 1
				print(string.format("  [OK] %s", item.id))
			else
				print(string.format("  [!!] %s (NOT FOUND IN CODE/TESTS)", item.id))
			end
		end
	end

	if #unknown_refs > 0 then
		print("\n=== Invalid SPEC References ===")
		-- Deduplicate unknown refs by file+ref
		local seen = {}
		for _, ref in ipairs(unknown_refs) do
			local key = ref.file .. ":" .. ref.ref
			if not seen[key] then
				print(string.format("  [ERR] %s in %s (%s)", ref.ref, ref.file, ref.reason))
				seen[key] = true
			end
		end
	end

	print("\n" .. string.rep("-", 40))
	print(string.format("Total Specifications: %d", total))
	print(string.format("Covered:              %d (%.1f%%)", covered, total > 0 and (covered / total) * 100 or 0))
	print(string.rep("-", 40) .. "\n")

	if covered < total or #unknown_refs > 0 then
		os.exit(1)
	end
end

local specs = get_specs()
local unknown_refs = check_coverage(specs)
report(specs, unknown_refs)
