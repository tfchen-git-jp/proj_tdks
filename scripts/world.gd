class_name World
extends RefCounted
## The level's scenery, after the reference ad: a flat grass plateau with
## the road painted on (ground shader + baked distance field), tall grey
## rock slabs walling the north, slab cliffs dropping east into a gorge,
## dark pines clustered along the edges, boulders, and the lodge.

const CLIFF := Color(0.53, 0.56, 0.62)
const CLIFF_DARK := Color(0.45, 0.48, 0.55)
const CLIFF_TOP := Color(0.74, 0.71, 0.66)
const WOOD := Color(0.55, 0.37, 0.22)
const STONE := Color(0.62, 0.63, 0.66)
const PINE := Color(0.2, 0.5, 0.34)
const BARK := Color(0.42, 0.28, 0.19)

## Map extent (also the road distance texture's extent).
const X0 := -24.0
const X1 := 16.0
const Z0 := -24.0
const Z1 := 44.0
const GORGE_Y := -5.0
const PX_PER_M := 8.0
const MAX_DIST := 4.0
const ROAD_DIST := "res://assets/terrain/road_dist.res"
const GROUND_SHADER := preload("res://shaders/ground.gdshader")

const PINES := ["tree_pineRoundA", "tree_pineRoundC", "tree_pineRoundE",
	"tree_pineDefaultA", "tree_pineDefaultB", "tree_pineTallA"]
const ROCKS := ["res://assets/props/forest/Rock_1_A_Color1.gltf",
	"res://assets/props/forest/Rock_2_A_Color1.gltf", "res://assets/props/forest/Rock_1_D_Color1.gltf"]


static func vertex_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.roughness = 0.9
	return m


## The plateau's east edge (where the cliff drops into the gorge) at z.
static func east_edge(z: float) -> float:
	return Level.CLIFF_X + 0.2 * sin(z * 0.45) + 0.15 * sin(z * 1.3 + 1.0)


## The plateau's north edge (foot of the rock wall) at x.
static func north_edge(x: float) -> float:
	return -15.5 + 0.6 * sin(x * 0.5) + 0.3 * sin(x * 1.7)


## Identifies the roads the distance texture was baked for.
static func road_hash() -> int:
	return var_to_str(Level.LANES).hash()


static func build(root: Node3D, tracks: Array[Track]) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	root.add_child(_ground())
	root.add_child(_cliffs(rng))
	root.add_child(_trees_and_rocks(tracks, rng))
	root.add_child(_keep())


# --- ground --------------------------------------------------------------

static func _ground() -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	# Plateau: a grid whose east and north borders follow the cliff edges.
	var nu := 48
	var nv := 96
	var grid: Array[PackedVector3Array] = []
	for j in nv + 1:
		var row := PackedVector3Array()
		for i in nu + 1:
			var u := float(i) / nu
			var xa := lerpf(X0, Level.CLIFF_X, u)
			var z := lerpf(north_edge(xa) - 1.5, Z1, float(j) / nv)
			row.push_back(Vector3(lerpf(X0, east_edge(z), u), 0.0, z))
		grid.push_back(row)
	st.set_color(Color.WHITE)
	for j in nv:
		for i in nu:
			_quad(st, grid[j][i], grid[j][i + 1], grid[j + 1][i + 1], grid[j + 1][i])
	# Gorge floor, darker.
	st.set_color(Color(0.6, 0.66, 0.68))
	var gz := 34
	for j in gz:
		var za := lerpf(Z0, Z1, float(j) / gz)
		var zb := lerpf(Z0, Z1, float(j + 1) / gz)
		_quad(st, Vector3(east_edge(za) - 0.5, GORGE_Y, za), Vector3(X1 + 4.0, GORGE_Y, za),
			Vector3(X1 + 4.0, GORGE_Y, zb), Vector3(east_edge(zb) - 0.5, GORGE_Y, zb))
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.name = "Ground"
	mi.material_override = ground_material()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


static func ground_material() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = GROUND_SHADER
	var tex: Texture2D = load(ROAD_DIST) if ResourceLoader.exists(ROAD_DIST) else null
	if tex == null or int(tex.get_meta("road_hash", 0)) != road_hash():
		push_warning("road_dist.res is missing or stale: run tools/bake_terrain.gd")
	m.set_shader_parameter("road_dist", tex)
	m.set_shader_parameter("map_origin", Vector2(X0, Z0))
	m.set_shader_parameter("map_size", Vector2(X1 - X0, Z1 - Z0))
	m.set_shader_parameter("max_dist", MAX_DIST)
	m.set_shader_parameter("road_half", Level.ROAD_HALF_WIDTH)
	m.set_shader_parameter("noise_tex", load("res://assets/terrain/noise.png"))
	return m


## Two triangles a-b-c, a-c-d (a..d clockwise seen from above).
static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	for v in [a, b, c, a, c, d]:
		st.add_vertex(v)


# --- cliffs ---------------------------------------------------------------

## The north wall (three rows of tall slabs) and the east gorge cliff
## (slabs from the gorge floor up to the plateau rim). One mesh.
static func _cliffs(rng: RandomNumberGenerator) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# North wall, front row first; each row further back is taller.
	var rows := [[0.0, 5.0, 8.0], [3.2, 7.5, 10.5], [6.6, 9.5, 12.0]]
	for r in rows:
		var x := X0 - 2.0
		while x < X1 + 2.0:
			var w := rng.randf_range(1.6, 3.4)
			var cx := x + w * 0.5
			var front := north_edge(cx) - float(r[0]) + rng.randf_range(-0.35, 0.25)
			var dpt := rng.randf_range(2.6, 3.8)
			var h := rng.randf_range(r[1], r[2])
			_slab(st, Vector3(cx, -0.5, front - dpt * 0.5), w * 0.5 + 0.05, dpt * 0.5, h,
				rng.randf_range(-0.08, 0.08), rng)
			x += w * rng.randf_range(0.85, 1.0)
	# East cliff: slab faces from below the gorge floor to the plateau rim.
	var z := Z0
	while z < Z1 + 2.0:
		var w := rng.randf_range(1.3, 2.6)
		var cz := z + w * 0.5
		var out := east_edge(cz) + rng.randf_range(-0.05, 0.45)
		var top := -0.03  # just under the grass: the plateau runs to the drop
		# Turned well off the edge line so the faces catch the light and
		# show from the camera instead of being seen edge-on.
		_slab(st, Vector3(out - 1.0, GORGE_Y - 0.5, cz), 1.0, w * 0.5 + 0.05, top - GORGE_Y + 0.5,
			rng.randf_range(-0.45, 0.45), rng)
		z += w * rng.randf_range(0.85, 1.0)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = vertex_material()
	mi.name = "Cliffs"
	return mi


## One rock slab: a box (half sizes hx, hz; height h from base.y) with a
## bevelled light cap, turned by `yaw`.
static func _slab(st: SurfaceTool, base: Vector3, hx: float, hz: float, h: float, yaw: float,
		rng: RandomNumberGenerator) -> void:
	var b := Basis(Vector3.UP, yaw)
	var side := CLIFF.lerp(CLIFF_DARK, rng.randf())
	var top_y := base.y + h
	var bev := minf(0.22, minf(hx, hz) * 0.3)
	var c := base + Vector3(0, h * 0.5, 0)
	var lo := [Vector3(-hx, 0, -hz), Vector3(hx, 0, -hz), Vector3(hx, 0, hz), Vector3(-hx, 0, hz)]
	var p0: Array[Vector3] = []  # bottom
	var p1: Array[Vector3] = []  # top of the sides
	var p2: Array[Vector3] = []  # cap, inset
	for q in lo:
		p0.push_back(base + b * q)
		p1.push_back(base + b * q + Vector3(0, h - bev, 0))
		var inset: Vector3 = q - Vector3(signf(q.x), 0, signf(q.z)) * bev
		p2.push_back(base + b * inset + Vector3(0, h, 0))
	for i in 4:
		var j := (i + 1) % 4
		_flat(st, p0[i], p1[i], p1[j], side, c)
		_flat(st, p0[i], p1[j], p0[j], side, c)
		_flat(st, p1[i], p2[i], p2[j], CLIFF_TOP.darkened(0.08), c)
		_flat(st, p1[i], p2[j], p1[j], CLIFF_TOP.darkened(0.08), c)
	var topc := Vector3(c.x, top_y - 1.0, c.z)
	_flat(st, p2[0], p2[1], p2[2], CLIFF_TOP, topc)
	_flat(st, p2[0], p2[2], p2[3], CLIFF_TOP, topc)


# --- trees and rocks -----------------------------------------------------------

## Dark pines clustered along the wall foot, the cliff rim, the gorge and
## the west margin, a few small groups in the open; boulders between.
static func _trees_and_rocks(tracks: Array[Track], rng: RandomNumberGenerator) -> Node3D:
	var node := Node3D.new()
	node.name = "Trees"
	var placed: Array[Vector3] = []
	var pine_xf: Array = []
	for i in PINES.size():
		pine_xf.push_back([])
	var rock_xf: Array = [[], [], []]

	# Zone x / z: a range, or "foot" (wall foot), "rim" (cliff top), "gorge".
	var zones := [
		{n = 70, x = [X0, X1], z = "foot", gap = 0.9},
		{n = 55, x = "rim", z = [Z0 + 6.0, Z1], gap = 1.0},
		{n = 110, x = "gorge", z = [Z0 + 4.0, Z1], gap = 1.1},
		{n = 70, x = [X0, -15.0], z = [-14.0, Z1], gap = 1.0},
	]
	for zone in zones:
		var tries := 0
		var got := 0
		while got < int(zone.n) and tries < int(zone.n) * 12:
			tries += 1
			var z: float
			var x: float
			var in_gorge: bool = zone.x is String and zone.x == "gorge"
			if zone.z is String:
				x = rng.randf_range(zone.x[0], zone.x[1])
				z = north_edge(x) + rng.randf_range(0.3, 2.6)
			else:
				z = rng.randf_range(zone.z[0], zone.z[1])
				if zone.x is String and zone.x == "rim":
					x = east_edge(z) - rng.randf_range(0.5, 2.2)
				elif in_gorge:
					x = rng.randf_range(east_edge(z) + 1.2, X1 + 2.0)
				else:
					x = rng.randf_range(zone.x[0], zone.x[1])
			var p := Vector3(x, GORGE_Y if in_gorge else 0.0, z)
			if not _free(p, tracks, placed, float(zone.gap)):
				continue
			placed.push_back(p)
			got += 1
			_add_tree_or_rock(p, rng, pine_xf, rock_xf)
	# A few small groups out in the open, like the reference.
	for g in 9:
		var c := Vector3(rng.randf_range(-14.0, 6.0), 0, rng.randf_range(-12.0, 34.0))
		for k in rng.randi_range(1, 3):
			var p := c + Vector3(rng.randf_range(-1.2, 1.2), 0, rng.randf_range(-1.2, 1.2))
			if _free(p, tracks, placed, 0.9):
				placed.push_back(p)
				_add_tree_or_rock(p, rng, pine_xf, rock_xf, 0.0)

	for i in PINES.size():
		node.add_child(_mm(_pine_mesh(PINES[i]), pine_xf[i]))
	for i in ROCKS.size():
		node.add_child(_mm(Models.mesh_of(ROCKS[i]), rock_xf[i]))
	return node


## Room for a tree at p: off the road, pads, lodge, hero start, others.
static func _free(p: Vector3, tracks: Array[Track], placed: Array[Vector3], gap: float) -> bool:
	if p.y > -1.0:
		if p.x > east_edge(p.z) - 0.4 or p.z < north_edge(p.x) + 0.2:
			return false
		for t in tracks:
			if t.distance_to(p) < Level.ROAD_HALF_WIDTH + 1.0:
				return false
		if p.distance_to(Level.KEEP_POS) < 4.0 or p.distance_to(Level.HERO_START) < 2.0 \
				or p.distance_to(Level.START_SPOT) < 2.0:
			return false
		for s in Level.SPOTS:
			if absf(p.x - s.pos.x) < 2.0 and absf(p.z - s.pos.z) < 2.0:
				return false
	for q in placed:
		if absf(q.x - p.x) < gap and absf(q.z - p.z) < gap:
			return false
	return true


static func _add_tree_or_rock(p: Vector3, rng: RandomNumberGenerator, pine_xf: Array, rock_xf: Array,
		rock_chance := 0.14) -> void:
	if rng.randf() < rock_chance:
		var s := rng.randf_range(0.8, 1.8)
		var b := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.7, 1.1), s))
		rock_xf[rng.randi() % ROCKS.size()].push_back(Transform3D(b, p - Vector3(0, 0.05, 0)))
		return
	var s := rng.randf_range(1.15, 1.75)
	var b := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.95, 1.2), s))
	pine_xf[rng.randi() % PINES.size()].push_back(Transform3D(b, p))


static func _mm(mesh: Mesh, xfs: Array) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xfs.size()
	for i in xfs.size():
		mm.set_instance_transform(i, xfs[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	return mmi


## A Kenney pine with the kit's teal/metallic materials replaced by the
## reference's dark green and brown.
static func _pine_mesh(pine: String) -> Mesh:
	var src := Models.mesh_of("res://assets/props/nature/%s.glb" % pine)
	var mesh := src.duplicate() as Mesh
	for s in mesh.get_surface_count():
		var old := mesh.surface_get_material(s)
		var m := StandardMaterial3D.new()
		var leaf := old != null and String(old.resource_name).begins_with("leaf")
		m.albedo_color = PINE if leaf else BARK
		m.roughness = 0.9
		mesh.surface_set_material(s, m)
	return mesh


# --- mesh helpers (also used for pads) ---------------------------------------

## One flat triangle. Winding and normal are made to face away from
## `inside`, so callers need not care about vertex order.
static func _flat(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, col: Color, inside := Vector3.INF) -> void:
	var n := (c - a).cross(b - a)
	if n.length() < 1e-6:
		return
	n = n.normalized()
	if inside != Vector3.INF and n.dot((a + b + c) / 3.0 - inside) < 0.0:
		var t := b
		b = c
		c = t
		n = -n
	st.set_color(col)
	st.set_normal(n)
	st.add_vertex(a)
	st.add_vertex(b)
	st.add_vertex(c)


## A box with flat faces, centred on `c` (half extents `h`).
static func box(st: SurfaceTool, c: Vector3, h: Vector3, col: Color, b := Basis()) -> void:
	var v: Array[Vector3] = []
	for i in 8:
		var s := Vector3(-1 if i & 1 == 0 else 1, -1 if i & 2 == 0 else 1, -1 if i & 4 == 0 else 1)
		v.push_back(c + b * (s * h))
	var faces := [[0, 1, 3, 2], [4, 6, 7, 5], [0, 4, 5, 1], [2, 3, 7, 6], [0, 2, 6, 4], [1, 5, 7, 3]]
	for f in faces:
		_flat(st, v[f[0]], v[f[1]], v[f[2]], col, c)
		_flat(st, v[f[0]], v[f[2]], v[f[3]], col, c)


static func _keep() -> Node3D:
	var l := Models.lodge()
	l.position = Level.KEEP_POS
	l.name = "Keep"
	return l
