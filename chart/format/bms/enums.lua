local enums = {}

enums.ChannelEnum = {
	["01"] = {name = "BGM", inputType = "auto", inputIndex = 0},
	["02"] = {name = "Signature"},
	["03"] = {name = "Tempo"},
	["08"] = {name = "ExtendedTempo"},
	["09"] = {name = "Stop"},

	["04"] = {name = "BGA", inputType = "bmsbga", inputIndex = 0x04},
	["06"] = {name = "BGA", inputType = "bmsbga", inputIndex = 0x06},
	["07"] = {name = "BGA", inputType = "bmsbga", inputIndex = 0x07},
	["0A"] = {name = "BGA", inputType = "bmsbga", inputIndex = 0x0A},
	["0B"] = {name = "BGA", inputType = "bmsbga", inputIndex = 0x0B},
	["0C"] = {name = "BGA", inputType = "bmsbga", inputIndex = 0x0C},
	["0D"] = {name = "BGA", inputType = "bmsbga", inputIndex = 0x0D},
	["0E"] = {name = "BGA", inputType = "bmsbga", inputIndex = 0x0E},

	["11"] = {name = "Note", channelBase = "11", inputType = "key", inputIndex = 1},
	["12"] = {name = "Note", channelBase = "12", inputType = "key", inputIndex = 2},
	["13"] = {name = "Note", channelBase = "13", inputType = "key", inputIndex = 3},
	["14"] = {name = "Note", channelBase = "14", inputType = "key", inputIndex = 4},
	["15"] = {name = "Note", channelBase = "15", inputType = "key", inputIndex = 5},
	["18"] = {name = "Note", channelBase = "18", inputType = "key", inputIndex = 6},
	["19"] = {name = "Note", channelBase = "19", inputType = "key", inputIndex = 7},

	["16"] = {name = "Note", channelBase = "16", inputType = "scratch", inputIndex = 1},
	["17"] = {name = "Note", channelBase = "17", inputType = "pedal", inputIndex = 1},

	["21"] = {name = "Note", channelBase = "21", inputType = "key", inputIndex = 8},
	["22"] = {name = "Note", channelBase = "22", inputType = "key", inputIndex = 9},
	["23"] = {name = "Note", channelBase = "23", inputType = "key", inputIndex = 10},
	["24"] = {name = "Note", channelBase = "24", inputType = "key", inputIndex = 11},
	["25"] = {name = "Note", channelBase = "25", inputType = "key", inputIndex = 12},
	["28"] = {name = "Note", channelBase = "28", inputType = "key", inputIndex = 13},
	["29"] = {name = "Note", channelBase = "29", inputType = "key", inputIndex = 14},

	["26"] = {name = "Note", channelBase = "26", inputType = "scratch", inputIndex = 2},
	["27"] = {name = "Note", channelBase = "27", inputType = "pedal", inputIndex = 2},

	["51"] = {name = "Note", channelBase = "11", inputType = "key", inputIndex = 1, long = true},
	["52"] = {name = "Note", channelBase = "12", inputType = "key", inputIndex = 2, long = true},
	["53"] = {name = "Note", channelBase = "13", inputType = "key", inputIndex = 3, long = true},
	["54"] = {name = "Note", channelBase = "14", inputType = "key", inputIndex = 4, long = true},
	["55"] = {name = "Note", channelBase = "15", inputType = "key", inputIndex = 5, long = true},
	["58"] = {name = "Note", channelBase = "18", inputType = "key", inputIndex = 6, long = true},
	["59"] = {name = "Note", channelBase = "19", inputType = "key", inputIndex = 7, long = true},

	["56"] = {name = "Note", channelBase = "16", inputType = "scratch", inputIndex = 1, long = true},
	["57"] = {name = "Note", channelBase = "17", inputType = "pedal", inputIndex = 1, long = true},

	["61"] = {name = "Note", channelBase = "21", inputType = "key", inputIndex = 8, long = true},
	["62"] = {name = "Note", channelBase = "22", inputType = "key", inputIndex = 9, long = true},
	["63"] = {name = "Note", channelBase = "23", inputType = "key", inputIndex = 10, long = true},
	["64"] = {name = "Note", channelBase = "24", inputType = "key", inputIndex = 11, long = true},
	["65"] = {name = "Note", channelBase = "25", inputType = "key", inputIndex = 12, long = true},
	["68"] = {name = "Note", channelBase = "28", inputType = "key", inputIndex = 13, long = true},
	["69"] = {name = "Note", channelBase = "29", inputType = "key", inputIndex = 14, long = true},

	["66"] = {name = "Note", channelBase = "26", inputType = "scratch", inputIndex = 2, long = true},
	["67"] = {name = "Note", channelBase = "27", inputType = "pedal", inputIndex = 2, long = true},

	["D1"] = {name = "Note", channelBase = "11", inputType = "key", inputIndex = 1, mine = true},
	["D2"] = {name = "Note", channelBase = "12", inputType = "key", inputIndex = 2, mine = true},
	["D3"] = {name = "Note", channelBase = "13", inputType = "key", inputIndex = 3, mine = true},
	["D4"] = {name = "Note", channelBase = "14", inputType = "key", inputIndex = 4, mine = true},
	["D5"] = {name = "Note", channelBase = "15", inputType = "key", inputIndex = 5, mine = true},
	["D8"] = {name = "Note", channelBase = "18", inputType = "key", inputIndex = 6, mine = true},
	["D9"] = {name = "Note", channelBase = "19", inputType = "key", inputIndex = 7, mine = true},

	["D6"] = {name = "Note", channelBase = "16", inputType = "scratch", inputIndex = 1, mine = true},
	["D7"] = {name = "Note", channelBase = "17", inputType = "pedal", inputIndex = 1, mine = true},

	["E1"] = {name = "Note", channelBase = "21", inputType = "key", inputIndex = 8, mine = true},
	["E2"] = {name = "Note", channelBase = "22", inputType = "key", inputIndex = 9, mine = true},
	["E3"] = {name = "Note", channelBase = "23", inputType = "key", inputIndex = 10, mine = true},
	["E4"] = {name = "Note", channelBase = "24", inputType = "key", inputIndex = 11, mine = true},
	["E5"] = {name = "Note", channelBase = "25", inputType = "key", inputIndex = 12, mine = true},
	["E8"] = {name = "Note", channelBase = "28", inputType = "key", inputIndex = 13, mine = true},
	["E9"] = {name = "Note", channelBase = "29", inputType = "key", inputIndex = 14, mine = true},

	["E6"] = {name = "Note", channelBase = "26", inputType = "scratch", inputIndex = 2, mine = true},
	["E7"] = {name = "Note", channelBase = "27", inputType = "pedal", inputIndex = 2, mine = true},

	["31"] = {name = "Note", channelBase = "11", inputType = "key", inputIndex = 1, invisible = true},
	["32"] = {name = "Note", channelBase = "12", inputType = "key", inputIndex = 2, invisible = true},
	["33"] = {name = "Note", channelBase = "13", inputType = "key", inputIndex = 3, invisible = true},
	["34"] = {name = "Note", channelBase = "14", inputType = "key", inputIndex = 4, invisible = true},
	["35"] = {name = "Note", channelBase = "15", inputType = "key", inputIndex = 5, invisible = true},
	["38"] = {name = "Note", channelBase = "18", inputType = "key", inputIndex = 6, invisible = true},
	["39"] = {name = "Note", channelBase = "19", inputType = "key", inputIndex = 7, invisible = true},

	["36"] = {name = "Note", channelBase = "16", inputType = "scratch", inputIndex = 1, invisible = true},
	["37"] = {name = "Note", channelBase = "17", inputType = "pedal", inputIndex = 1, invisible = true},

	["41"] = {name = "Note", channelBase = "21", inputType = "key", inputIndex = 8, invisible = true},
	["42"] = {name = "Note", channelBase = "22", inputType = "key", inputIndex = 9, invisible = true},
	["43"] = {name = "Note", channelBase = "23", inputType = "key", inputIndex = 10, invisible = true},
	["44"] = {name = "Note", channelBase = "24", inputType = "key", inputIndex = 11, invisible = true},
	["45"] = {name = "Note", channelBase = "25", inputType = "key", inputIndex = 12, invisible = true},
	["48"] = {name = "Note", channelBase = "28", inputType = "key", inputIndex = 13, invisible = true},
	["49"] = {name = "Note", channelBase = "29", inputType = "key", inputIndex = 14, invisible = true},

	["46"] = {name = "Note", channelBase = "26", inputType = "scratch", inputIndex = 2, invisible = true},
	["47"] = {name = "Note", channelBase = "27", inputType = "pedal", inputIndex = 2, invisible = true},
}

enums.ChannelEnum5Keys = {
	["21"] = {name = "Note", inputType = "key", inputIndex = 6},
	["22"] = {name = "Note", inputType = "key", inputIndex = 7},
	["23"] = {name = "Note", inputType = "key", inputIndex = 8},
	["24"] = {name = "Note", inputType = "key", inputIndex = 9},
	["25"] = {name = "Note", inputType = "key", inputIndex = 10},

	["61"] = {name = "Note", inputType = "key", inputIndex = 6, long = true},
	["62"] = {name = "Note", inputType = "key", inputIndex = 7, long = true},
	["63"] = {name = "Note", inputType = "key", inputIndex = 8, long = true},
	["64"] = {name = "Note", inputType = "key", inputIndex = 9, long = true},
	["65"] = {name = "Note", inputType = "key", inputIndex = 10, long = true},

	["E1"] = {name = "Note", inputType = "key", inputIndex = 6, mine = true},
	["E2"] = {name = "Note", inputType = "key", inputIndex = 7, mine = true},
	["E3"] = {name = "Note", inputType = "key", inputIndex = 8, mine = true},
	["E4"] = {name = "Note", inputType = "key", inputIndex = 9, mine = true},
	["E5"] = {name = "Note", inputType = "key", inputIndex = 10, mine = true},
}

enums.ChannelEnum9Keys = {
	["22"] = {name = "Note", inputType = "key", inputIndex = 6},
	["23"] = {name = "Note", inputType = "key", inputIndex = 7},
	["24"] = {name = "Note", inputType = "key", inputIndex = 8},
	["25"] = {name = "Note", inputType = "key", inputIndex = 9},

	["62"] = {name = "Note", inputType = "key", inputIndex = 6, long = true},
	["63"] = {name = "Note", inputType = "key", inputIndex = 7, long = true},
	["64"] = {name = "Note", inputType = "key", inputIndex = 8, long = true},
	["65"] = {name = "Note", inputType = "key", inputIndex = 9, long = true},

	["E2"] = {name = "Note", inputType = "key", inputIndex = 6, mine = true},
	["E3"] = {name = "Note", inputType = "key", inputIndex = 7, mine = true},
	["E4"] = {name = "Note", inputType = "key", inputIndex = 8, mine = true},
	["E5"] = {name = "Note", inputType = "key", inputIndex = 9, mine = true},
}

enums.ChannelEnumPMS5Keys = {
	["13"] = {name = "Note", inputType = "key", inputIndex = 1},
	["14"] = {name = "Note", inputType = "key", inputIndex = 2},
	["15"] = {name = "Note", inputType = "key", inputIndex = 3},
	["22"] = {name = "Note", inputType = "key", inputIndex = 4},
	["23"] = {name = "Note", inputType = "key", inputIndex = 5},

	["53"] = {name = "Note", inputType = "key", inputIndex = 1, long = true},
	["54"] = {name = "Note", inputType = "key", inputIndex = 2, long = true},
	["55"] = {name = "Note", inputType = "key", inputIndex = 3, long = true},
	["62"] = {name = "Note", inputType = "key", inputIndex = 4, long = true},
	["63"] = {name = "Note", inputType = "key", inputIndex = 5, long = true},

	["D3"] = {name = "Note", inputType = "key", inputIndex = 1, mine = true},
	["D4"] = {name = "Note", inputType = "key", inputIndex = 2, mine = true},
	["D5"] = {name = "Note", inputType = "key", inputIndex = 3, mine = true},
	["E2"] = {name = "Note", inputType = "key", inputIndex = 4, mine = true},
	["E3"] = {name = "Note", inputType = "key", inputIndex = 5, mine = true},
}

enums.ChannelEnumDsc = {
	["26"] = {name = "Note", inputType = "pedal", inputIndex = 1},
	["66"] = {name = "Note", inputType = "pedal", inputIndex = 1, long = true},
	["E6"] = {name = "Note", inputType = "pedal", inputIndex = 1, mine = true},
}

enums.BackChannelEnum = {
	["BGM"] = "01",
	["Signature"] = "02",
	["Tempo"] = "03",
	["ExtendedTempo"] = "08",
	["Stop"] = "09",
}

return enums
