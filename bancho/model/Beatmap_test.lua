--- Tests for bancho model Beatmap.

local Beatmap = require("bancho.model.Beatmap")
local RankedStatus = require("bancho.constants.RankedStatus")

local test = {}

function test.beatmap_creation(t)
	local b = Beatmap()
	t:eq(b.md5, "")
	t:eq(b.id, 0)
	t:eq(b.status, RankedStatus.PENDING)
	t:eq(b.mode, 0)
	t:eq(b:fullName(), " -  []")
end

function test.beatmap_fullName(t)
	local b = Beatmap()
	b.artist = "TestArtist"
	b.title = "TestTitle"
	b.version = "Easy"
	t:eq(b:fullName(), "TestArtist - TestTitle [Easy]")
end

function test.beatmap_hasLeaderboard(t)
	local b = Beatmap()

	b.status = RankedStatus.PENDING
	t:eq(b:hasLeaderboard(), false)

	b.status = RankedStatus.RANKED
	t:eq(b:hasLeaderboard(), true)

	b.status = RankedStatus.APPROVED
	t:eq(b:hasLeaderboard(), true)

	b.status = RankedStatus.LOVED
	t:eq(b:hasLeaderboard(), true)
end

function test.beatmap_awardsRankedPP(t)
	local b = Beatmap()

	b.status = RankedStatus.PENDING
	t:eq(b:awardsRankedPP(), false)

	b.status = RankedStatus.RANKED
	t:eq(b:awardsRankedPP(), true)

	b.status = RankedStatus.APPROVED
	t:eq(b:awardsRankedPP(), true)

	b.status = RankedStatus.LOVED
	t:eq(b:awardsRankedPP(), false)
end

return test
