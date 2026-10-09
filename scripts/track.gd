class_name Track
extends RefCounted
## The road as a lookup table: point(d, off) is the spot `d` metres along
## the road, `off` metres to the right of the walking direction. Sampled
## every STEP metres from a smoothed curve, so lookups are cheap.

const STEP := 0.1

var length := 0.0
var _pts := PackedVector3Array()
var _right := PackedVector3Array()


func _init(points: Array) -> void:
	var curve := Curve3D.new()
	curve.bake_interval = 0.05
	for i in points.size():
		var p: Vector3 = points[i]
		var prev: Vector3 = points[maxi(i - 1, 0)]
		var next: Vector3 = points[mini(i + 1, points.size() - 1)]
		var h := (next - prev) * 0.22  # Catmull-Rom-like handles
		curve.add_point(p, -h, h)
	length = curve.get_baked_length()
	var n := int(length / STEP) + 1
	_pts.resize(n)
	_right.resize(n)
	for i in n:
		_pts[i] = curve.sample_baked(minf(i * STEP, length))
	for i in n:
		var t := (_pts[mini(i + 1, n - 1)] - _pts[maxi(i - 1, 0)])
		t.y = 0.0
		t = t.normalized()
		_right[i] = Vector3(-t.z, 0.0, t.x)


func _index(d: float) -> int:
	return clampi(int(d / STEP), 0, _pts.size() - 1)


## Blends the two nearest table entries (snapping to the 0.1 m table made
## walkers visibly step). Past the end it carries straight on.
func point(d: float, off := 0.0) -> Vector3:
	var last := _pts.size() - 1
	if d >= last * STEP:
		var r := _right[last]
		return _pts[last] + Vector3(r.z, 0.0, -r.x) * (d - last * STEP) + r * off
	var f := maxf(d, 0.0) / STEP
	var i := int(f)
	var a := f - i
	return _pts[i].lerp(_pts[i + 1], a) + _right[i].lerp(_right[i + 1], a) * off


## Unit vector along the walking direction at `d`.
func forward(d: float) -> Vector3:
	var r := _right[_index(d)]
	return Vector3(r.z, 0.0, -r.x)


func right(d: float) -> Vector3:
	return _right[_index(d)]


## Road distance of the centre-line point nearest to `p` (brute force).
func closest_d(p: Vector3) -> float:
	var best := INF
	var best_i := 0
	for i in _pts.size():
		var q := _pts[i]
		var dd := (q.x - p.x) * (q.x - p.x) + (q.z - p.z) * (q.z - p.z)
		if dd < best:
			best = dd
			best_i = i
	return best_i * STEP


## Horizontal distance from `p` to the road centre line.
func distance_to(p: Vector3) -> float:
	var q := point(closest_d(p))
	return Vector2(q.x - p.x, q.z - p.z).length()


func points() -> PackedVector3Array:
	return _pts
