local mappings = {}

mappings["5key1scratch"] = {
	scratch = {1},
	key = {2, 3, 4, 5, 6},
	keymode = 6
}

mappings["7key1scratch"] = {
	scratch = {1},
	key = {2, 3, 4, 5, 6, 7, 8},
	keymode = 8
}

mappings["10key2scratch"] = {
	scratch = {1, 12},
	key = {2, 3, 4, 5, 6, 7, 8, 9, 10, 11},
	keymode = 12
}

mappings["14key2scratch"] = {
	scratch = {1, 14},
	key = {2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13},
	keymode = 16
}

mappings["4bt2fx2laserleft2laserright"] = {
	bt = {3, 4, 7, 8},
	fx = {5, 6},
	laserleft = {1, 9},
	laserright = {2, 10},
	keymode = 10
}

return mappings
