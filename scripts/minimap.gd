class_name Minimap
extends Control
## Bottom-right overview: the three lanes, the keep, buildings, standing
## gates, enemies (small dots, big dots for brutes), the hero and the part
## of the map the camera shows. Redrawn every frame from the Sim.

const AREA := Rect2(-15.0, -14.0, 23.5, 52.0)  # world x, z shown
const W := 120.0
const BG := Color(0.06, 0.1, 0.08, 0.72)
const ROAD := Color(0.86, 0.76, 0.58, 0.85)
const ENEMY := Color(1.0, 0.25, 0.2)
const RUNNER := Color(1.0, 0.75, 0.15)
const HERO := Color(0.3, 1.0, 0.45)
const TOWER := Color(0.55, 0.8, 1.0)
const GATE := Color(0.35, 0.75, 1.0)

var sim: Sim
var cam: Camera3D
var _lanes: Array[PackedVector2Array] = []


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(W, W * AREA.size.y / AREA.size.x)
	size = custom_minimum_size


func set_sim(s: Sim, c: Camera3D) -> void:
	sim = s
	cam = c
	_lanes.clear()
	# Lanes start beyond the shown area (enemies walk in from off the map):
	# keep only the part inside the frame.
	var frame := PackedVector2Array([Vector2(2, 2), Vector2(size.x - 2, 2), size - Vector2(2, 2), Vector2(2, size.y - 2)])
	for t in sim.tracks:
		var line := PackedVector2Array()
		var pts: PackedVector3Array = t.points()
		for i in range(0, pts.size(), 10):
			line.push_back(_to(pts[i]))
		line.push_back(_to(pts[pts.size() - 1]))
		for part in Geometry2D.intersect_polyline_with_polygon(line, frame):
			_lanes.push_back(part)


func _to(p: Vector3) -> Vector2:
	return Vector2((p.x - AREA.position.x) / AREA.size.x, (p.z - AREA.position.y) / AREA.size.y) * size


func _process(_delta: float) -> void:
	if visible and sim:
		queue_redraw()


func _draw() -> void:
	if sim == null:
		return
	draw_rect(Rect2(Vector2.ZERO, size), BG)
	draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, 0.5), false, 2.0)
	for line in _lanes:
		draw_polyline(line, ROAD, 4.0)
	# Keep
	var k := _to(Level.KEEP_POS)
	draw_rect(Rect2(k - Vector2(7, 6), Vector2(14, 12)), Color(0.35, 0.55, 1.0))
	# Buildings
	for b in sim.buildings.values():
		var p := _to(b.pos)
		match String(b.kind):
			"gate":
				if not b.broken:
					var t: Track = sim.tracks[int(b.spot.lane)]
					var gd: float = sim.horde.gate_d[int(b.spot.lane)]
					var r := t.right(gd)
					var c := t.point(gd)
					draw_line(_to(c - r * 1.6), _to(c + r * 1.6), GATE, 4.0)
			"farm", "bank":
				draw_rect(Rect2(p - Vector2(3, 3), Vector2(6, 6)), Color(0.9, 0.75, 0.3))
			_:
				draw_rect(Rect2(p - Vector2(3, 3), Vector2(6, 6)), TOWER)
	# Enemies (only those on the map area)
	var h := sim.horde
	for i in h.count():
		var p := _to(h.pos[i])
		if p.y > size.y + 2.0:
			continue
		match h.kind[i]:
			Level.BRUTE: draw_circle(p, 4.0, ENEMY)
			Level.BOSS: draw_circle(p, 6.0, Color(0.75, 0.3, 1.0))
			Level.RUNNER: draw_circle(p, 1.6, RUNNER)
			Level.BAT: draw_circle(p, 2.0, Color(0.75, 0.45, 1.0))
			Level.SIEGE: draw_circle(p, 2.0, Color(0.95, 0.95, 0.85))
			_: draw_circle(p, 1.8, ENEMY)
	# What the camera sees
	if cam:
		var vp := cam.get_viewport().get_visible_rect().size
		var corners := PackedVector2Array()
		for c in [Vector2.ZERO, Vector2(vp.x, 0), vp, Vector2(0, vp.y)]:
			var o := cam.project_ray_origin(c)
			var d := cam.project_ray_normal(c)
			var t := -o.y / d.y if d.y < -0.001 else 60.0
			corners.push_back(_to(o + d * t))
		var frame := PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0), size, Vector2(0, size.y)])
		for poly in Geometry2D.intersect_polygons(corners, frame):
			poly.push_back(poly[0])
			draw_polyline(poly, Color(1, 1, 1, 0.55), 1.5)
	# Hero
	var hp := _to(sim.hero_pos)
	draw_circle(hp, 4.5, Color(0, 0, 0, 0.6))
	draw_circle(hp, 3.5, HERO)
