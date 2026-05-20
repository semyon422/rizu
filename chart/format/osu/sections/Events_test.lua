local Events = require("chart.format.osu.sections.Events")

local test = {}

function test.basic(t)
	local events = Events()

	local lines = {
		"//Background and Video events",
		'0,0,"bg.jpg",0,0',
		'Video,1000,"bga.mpg"',
		"//Break Periods",
		"//Storyboard Layer 0 (Background)",
		"//Storyboard Layer 1 (Fail)",
		"//Storyboard Layer 2 (Pass)",
		"//Storyboard Layer 3 (Foreground)",
		"//Storyboard Layer 4 (Overlay)",
		"//Storyboard Sound Samples",
		'Sample,1000,0,"sample1.wav",100',
		'Sample,1000,0,"sample2.wav",100',
	}

	local lines_out = {
		'0,0,"bg.jpg",0,0',
		'1,1000,"bga.mpg"',
		'5,1000,0,"sample1.wav",100',
		'5,1000,0,"sample2.wav",100',
	}

	events:decode(lines)

	t:eq(events.background, "bg.jpg")
	t:tdeq(events.video, {time = 1000, name = "bga.mpg"})
	t:tdeq(events.samples[1], {time = 1000, name = "sample1.wav", volume = 100})
	t:tdeq(events:encode(), lines_out)
end

return test
