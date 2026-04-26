local Downloader = require("rizu.build.Downloader")

local test = {}

---@param t testing.T
function test.download_writes_temp_file_then_moves_to_dest(t)
	local commands = {}
	local shell = {}
	function shell:execute(cmd)
		table.insert(commands, cmd)
		return true
	end

	local downloader = Downloader(shell)
	downloader:download("https://example.invalid/file.tar.gz", "build/downloads/file.tar.gz")

	t:eq(#commands, 1)
	t:assert(commands[1]:find("build/downloads/file.tar.gz.tmp", 1, true) ~= nil)
	t:assert(commands[1]:find("curl %-fL"))
	t:assert(commands[1]:find("mv %-f"))
end

return test
