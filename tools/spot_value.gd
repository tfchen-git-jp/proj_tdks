extends SceneTree
## Tactical value of every tower spot: metres of each lane's road (inside
## the hero's area, past the start line) within reach R of the spot.
##   godot --headless --path . --script res://tools/spot_value.gd [-- --r=7]
func _init() -> void:
	var r := 7.0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--r="):
			r = float(a.get_slice("=", 1))
	var tracks: Array[Track] = []
	for pts in Level.LANES:
		tracks.push_back(Track.new(pts))
	var rows := []
	for sp in Level.SPOTS:
		var per := []
		for ln in tracks.size():
			var t: Track = tracks[ln]
			var entry := Horde.start_line(t)
			var m := 0.0
			var dd := entry
			while dd < t.length:
				if t.point(dd).distance_to(sp.pos) <= r:
					m += 0.25
				dd += 0.25
			per.push_back(m)
		var lanes := 0
		for m in per:
			if m >= 4.0:
				lanes += 1
		var tot: float = per[0] + per[1] + per[2]
		rows.push_back([sp.id, sp.kind, int(sp.get("lv", 1)), lanes, tot, per, sp.pos])
	rows.sort_custom(func(a, b): return a[4] > b[4])
	for row in rows:
		print("%-7s %-5s lv%2d  lanes %d  total %5.1f m  W %4.1f C %4.1f E %4.1f  at (%.1f, %.1f)" % [row[0], row[1], row[2], row[3], row[4],
			row[5][0], row[5][1], row[5][2], row[6].x, row[6].z])
	quit()
