extends SceneTree
## Bakes the road distance field the ground shader paints the road from:
## assets/terrain/road_dist.res, an L8 image over the map (World.X0..X1,
## World.Z0..Z1) at PX_PER_M, value = distance to the road centre line /
## MAX_DIST (clamped). Re-run whenever Level.ROAD changes; the game and
## tests check the stored hash.
##   godot --headless --path . --script res://tools/bake_terrain.gd

const World_ := preload("res://scripts/world.gd")
const Track_ := preload("res://scripts/track.gd")
const Level_ := preload("res://scripts/level.gd")


func _init() -> void:
	var tracks := []
	for pts in Level_.LANES:
		tracks.push_back(Track_.new(pts))
	var ppm: float = World_.PX_PER_M
	var w := int((World_.X1 - World_.X0) * ppm)
	var h := int((World_.Z1 - World_.Z0) * ppm)
	var dist := PackedFloat32Array()
	dist.resize(w * h)
	dist.fill(World_.MAX_DIST)
	var reach := int(ceil(World_.MAX_DIST * ppm))
	var pts := PackedVector3Array()
	for t in tracks:
		pts.append_array(t.points())
	# Stamp every road sample's neighbourhood with the distance to it; the
	# minimum over all samples is the distance to the nearest road.
	for i in range(0, pts.size()):
		var p := pts[i]
		var cx := int((p.x - World_.X0) * ppm)
		var cz := int((p.z - World_.Z0) * ppm)
		for z in range(maxi(cz - reach, 0), mini(cz + reach + 1, h)):
			var wz := World_.Z0 + (z + 0.5) / ppm
			for x in range(maxi(cx - reach, 0), mini(cx + reach + 1, w)):
				var wx := World_.X0 + (x + 0.5) / ppm
				var dd := sqrt((wx - p.x) * (wx - p.x) + (wz - p.z) * (wz - p.z))
				var k := z * w + x
				if dd < dist[k]:
					dist[k] = dd
	var img := Image.create_empty(w, h, false, Image.FORMAT_L8)
	for z in h:
		for x in w:
			var v: float = dist[z * w + x] / World_.MAX_DIST
			img.set_pixel(x, z, Color(v, v, v))
	var tex := ImageTexture.create_from_image(img)
	tex.set_meta("road_hash", World_.road_hash())
	ResourceSaver.save(tex, World_.ROAD_DIST)
	print("[terrain] road distance %dx%d -> %s" % [w, h, World_.ROAD_DIST])
	quit()
