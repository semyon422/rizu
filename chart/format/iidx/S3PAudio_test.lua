local S3P = require("chart.format.iidx.S3P")
local S3PAudio = require("chart.format.iidx.S3PAudio")
local Fixtures = require("chart.format.iidx.TestFixtures")

local test = {}

local asf_header = string.char(
	0x30, 0x26, 0xb2, 0x75, 0x8e, 0x66, 0xcf, 0x11,
	0xa6, 0xd9, 0x00, 0xaa, 0x00, 0x62, 0xce, 0x6c
)

---@param t testing.T
function test.decodes_wma_payload_with_video_module(t)
	local old_video = package.loaded.video
	package.loaded.video = {
		decode_audio = function(data)
			return "RIFF" .. data
		end,
	}

	local pack = S3P.parse(Fixtures.s3p({asf_header .. "payload"}))
	local payload = S3PAudio.payload_by_id(pack, 1)

	package.loaded.video = old_video

	t:eq(payload, "RIFF" .. asf_header .. "payload")
	t:eq(S3PAudio.payload_by_id(pack, 1), payload)
end

return test
