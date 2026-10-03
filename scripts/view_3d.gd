class_name View3D
extends BoardView
## 3D view: lit glass tubes on stepped shelves, seen through a perspective camera
## that is framed to fit the screen. Liquid sloshing lives in Bottle3D.

const TOP_MARGIN := 76.0
const BOTTOM_MARGIN := 100.0
const SIDE_MARGIN := 12.0
const SPACING := 1.0 ## distance between bottle centers in a row
const ROW_RISE := 2.5 ## each row further back sits this much higher...
const ROW_DEPTH := 1.3 ## ...and this much further away
const LIFT := 0.4
const CAMERA_PITCH := -0.2 ## radians, looking slightly down
const CAMERA_FOV := 24.0
## Height of the space a bottle may use, including the lift and cork.
const BOX_TOP := Bottle3D.HEIGHT + LIFT + 0.4

var bottles: Array[Bottle3D] = []
var homes: Array[Vector3] = []

var _root := Node3D.new()
var _bottle_root := Node3D.new()
var _shelf_root := Node3D.new()
var _camera := Camera3D.new()
var _stream := MeshInstance3D.new()
var _stream_material := StandardMaterial3D.new()
var _splash := CPUParticles3D.new()
var _shelf_material := StandardMaterial3D.new()
var _pour_from: Bottle3D
var _pour_to: Bottle3D
var _pour_level := 0


func _ready() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = ProjectSettings.get_setting("rendering/environment/defaults/default_clear_color")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.55, 0.65, 0.85)
	environment.ambient_light_energy = 0.7
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	_root.add_child(world_environment)

	var key_light := DirectionalLight3D.new()
	key_light.rotation = Vector3(-0.9, -0.5, 0.0)
	key_light.light_energy = 1.1
	_root.add_child(key_light)
	var rim_light := DirectionalLight3D.new()
	rim_light.rotation = Vector3(-0.3, 2.6, 0.0)
	rim_light.light_energy = 0.5
	rim_light.light_color = Color(0.7, 0.85, 1.0)
	_root.add_child(rim_light)

	_camera.fov = CAMERA_FOV
	_camera.rotation.x = CAMERA_PITCH
	_root.add_child(_camera)

	_shelf_material.albedo_color = Color(0.13, 0.19, 0.29)
	_shelf_material.roughness = 0.7
	_root.add_child(_shelf_root)
	_root.add_child(_bottle_root)

	var stream_mesh := CylinderMesh.new()
	stream_mesh.top_radius = 0.035
	stream_mesh.bottom_radius = 0.035
	stream_mesh.height = 1.0
	stream_mesh.radial_segments = 12
	stream_mesh.rings = 1
	_stream.mesh = stream_mesh
	_stream.material_override = _stream_material
	_stream.visible = false
	_stream_material.roughness = 0.2
	_root.add_child(_stream)

	var drop := SphereMesh.new()
	drop.radius = 0.5
	drop.height = 1.0
	drop.radial_segments = 8
	drop.rings = 4
	var drop_material := StandardMaterial3D.new()
	drop_material.vertex_color_use_as_albedo = true
	drop_material.roughness = 0.2
	drop.material = drop_material
	_splash.mesh = drop
	_splash.emitting = false
	_splash.amount = 24
	_splash.lifetime = 0.35
	_splash.direction = Vector3.UP
	_splash.spread = 40.0
	_splash.initial_velocity_min = 0.8
	_splash.initial_velocity_max = 1.6
	_splash.gravity = Vector3(0, -9.8, 0)
	_splash.scale_amount_min = 0.03
	_splash.scale_amount_max = 0.06
	_root.add_child(_splash)


func build(bottle_count: int) -> void:
	for bottle in bottles:
		bottle.queue_free()
	bottles.clear()
	for i in bottle_count:
		var bottle := Bottle3D.new()
		_bottle_root.add_child(bottle)
		bottles.append(bottle)


func set_active(active: bool) -> void:
	# Out of the tree, the 3D world (camera, environment, lights) costs nothing.
	if active and not _root.is_inside_tree():
		add_child(_root)
	elif not active and _root.is_inside_tree():
		remove_child(_root)
	if active:
		_camera.make_current()


## Puts the rows on stepped shelves (back rows higher) and frames the camera.
func relayout() -> void:
	var n := bottles.size()
	if n == 0 or not _root.is_inside_tree():
		return
	var area := _target_rect()
	var rows := 1
	var best := 0.0
	for r in range(1, n + 1):
		var cols := ceili(float(n) / r)
		var width := cols * SPACING
		var height := BOX_TOP + (r - 1) * ROW_RISE * 0.75
		var s := minf(area.size.x / width, area.size.y / height)
		if s > best:
			best = s
			rows = r

	homes.clear()
	for shelf in _shelf_root.get_children():
		shelf.queue_free()
	for r in rows:
		@warning_ignore("integer_division")
		var count := n / rows + (1 if r < n % rows else 0)
		var back := rows - 1 - r
		var y := back * ROW_RISE
		var z := -back * ROW_DEPTH
		for c in count:
			homes.append(Vector3((c - (count - 1) * 0.5) * SPACING, y, z))
		var shelf := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(count * SPACING + 0.2, 0.1, 0.8)
		shelf.mesh = box
		shelf.material_override = _shelf_material
		shelf.position = Vector3(0, y - 0.05, z)
		_shelf_root.add_child(shelf)

	for i in n:
		var bottle := bottles[i]
		bottle.rotation = Vector3.ZERO
		bottle.position = homes[i] + (Vector3(0, LIFT, 0) if bottle.selected else Vector3.ZERO)
		bottle.reset_motion()
	_fit_camera()


func show_state(state: Array) -> void:
	for i in bottles.size():
		bottles[i].layers = state[i].duplicate()
		bottles[i].anim_units = 0
		bottles[i].refresh()


## Picks the front-most bottle whose on-screen box contains `pos`.
func bottle_at(pos: Vector2) -> int:
	var found := -1
	for i in bottles.size():
		if _screen_rect(homes[i]).has_point(pos) and (found == -1 or homes[i].z > homes[found].z):
			found = i
	return found


func set_selected(index: int, selected: bool, move := true) -> void:
	var bottle := bottles[index]
	bottle.selected = selected
	if move:
		create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).tween_property(
			bottle, "position", homes[index] + (Vector3(0, LIFT, 0) if selected else Vector3.ZERO), 0.18)


func set_hint(index: int, on: bool) -> void:
	bottles[index].hint = on


func shake(index: int) -> void:
	var bottle := bottles[index]
	var tween := create_tween()
	for offset in [-0.09, 0.09, -0.06, 0.0]:
		tween.tween_property(bottle, "position", homes[index] + Vector3(offset, 0, 0), 0.05)


func swing_to_pour(from: int, to: int) -> void:
	var src := bottles[from]
	var dir := 1.0 if homes[from].x <= homes[to].x else -1.0
	var angle := -POUR_ANGLE * dir
	var mouth_offset := Bottle3D.mouth().rotated(Vector3.BACK, angle)
	var target := homes[to] + Bottle3D.mouth() + Vector3(0, 0.35, 0.05) - mouth_offset
	await _arc(src, src.position, target, 0.0, angle, 0.38)


func flow(from: int, to: int, color: int, amount: int, state: Array) -> void:
	var src := bottles[from]
	var dst := bottles[to]
	src.layers = state[from].duplicate()
	src.anim_units = -amount
	src.anim_color = color
	dst.layers = state[to].duplicate()
	dst.anim_units = amount
	_pour_from = src
	_pour_to = dst
	_pour_level = state[to].size() - amount
	_stream_material.albedo_color = Puzzle.COLORS[color]
	_splash.color = Puzzle.COLORS[color]
	_set_pour_progress(0.0)
	_stream.visible = true
	_splash.emitting = true
	dst.kick(Vector2(randf_range(-0.6, 0.6), randf_range(-0.6, 0.6)))
	var tween := create_tween()
	tween.tween_method(_set_pour_progress, 0.0, 1.0, 0.2 + 0.14 * amount)
	await tween.finished
	_stream.visible = false
	_splash.emitting = false
	src.anim_units = 0
	dst.anim_units = 0
	src.refresh()
	dst.refresh()


func swing_back(from: int) -> void:
	var src := bottles[from]
	await _arc(src, src.position, homes[from], src.rotation.z, 0.0, 0.32)
	src.position = homes[from]
	src.rotation = Vector3.ZERO


## Moves a bottle along an arc that clears its neighbours while turning it.
func _arc(bottle: Bottle3D, start: Vector3, end: Vector3, turn_from: float, turn_to: float,
		seconds: float) -> void:
	var peak := (start + end) * 0.5
	peak.y = maxf(start.y, end.y) + 0.6
	var step := func(t: float) -> void:
		var e := ease(t, -2.0)
		var a := start.lerp(peak, e)
		var b := peak.lerp(end, e)
		bottle.position = a.lerp(b, e)
		bottle.rotation.z = lerpf(turn_from, turn_to, e)
	var tween := create_tween()
	tween.tween_method(step, 0.0, 1.0, seconds)
	await tween.finished


func _set_pour_progress(t: float) -> void:
	_pour_from.anim_frac = 1.0 - t
	_pour_to.anim_frac = t
	_pour_from.refresh()
	_pour_to.refresh()
	var start := _pour_from.global_transform * Bottle3D.mouth()
	var end := _pour_to.global_transform * Vector3(0, Bottle3D.level_y(_pour_level + t * absi(_pour_from.anim_units)), 0)
	_place_stream(start, end)
	_splash.global_position = end


## Stretches the stream cylinder between two points.
func _place_stream(start: Vector3, end: Vector3) -> void:
	var along := end - start
	var length := maxf(along.length(), 0.001)
	var y_axis := along / length
	var x_axis := y_axis.cross(Vector3.BACK)
	if x_axis.length() < 0.01:
		x_axis = Vector3.RIGHT
	x_axis = x_axis.normalized()
	var z_axis := x_axis.cross(y_axis).normalized()
	_stream.global_transform = Transform3D(Basis(x_axis, y_axis * length, z_axis), (start + end) * 0.5)


## Screen area left for the bottles between the HUD bars.
func _target_rect() -> Rect2:
	var view := get_viewport().get_visible_rect()
	return Rect2(view.position + Vector2(SIDE_MARGIN, TOP_MARGIN),
		view.size - Vector2(2.0 * SIDE_MARGIN, TOP_MARGIN + BOTTOM_MARGIN))


## Corners of the space a bottle at `home` can occupy.
func _box(home: Vector3) -> Array[Vector3]:
	var r := Bottle3D.RADIUS + 0.08
	var corners: Array[Vector3] = []
	for x in [-r, r]:
		for y in [-0.05, BOX_TOP]:
			for z in [-r, r]:
				corners.append(home + Vector3(x, y, z))
	return corners


func _screen_rect(home: Vector3) -> Rect2:
	var rect := Rect2(_camera.unproject_position(home), Vector2.ZERO)
	for corner in _box(home):
		rect = rect.expand(_camera.unproject_position(corner))
	return rect


## Moves the camera back until every bottle fits between the HUD bars, then centers the view.
func _fit_camera() -> void:
	var corners: Array[Vector3] = []
	var bounds := AABB(homes[0], Vector3.ZERO)
	for home in homes:
		for corner in _box(home):
			corners.append(corner)
			bounds = bounds.expand(corner)
	var area := _target_rect()
	var forward := -_camera.basis.z
	var center := bounds.get_center()

	var near := 1.0
	var far := 200.0
	for i in 30:
		var distance := (near + far) * 0.5
		_camera.position = center - forward * distance
		if _all_inside(corners, area):
			far = distance
		else:
			near = distance
	_camera.position = center - forward * far

	# Shift the camera so the bottles sit in the middle of the free area.
	var shown := Rect2(_camera.unproject_position(corners[0]), Vector2.ZERO)
	for corner in corners:
		shown = shown.expand(_camera.unproject_position(corner))
	var offset := shown.get_center() - area.get_center()
	var world_per_pixel := 2.0 * far * tan(deg_to_rad(CAMERA_FOV) * 0.5) / get_viewport().get_visible_rect().size.y
	_camera.position += (_camera.basis.x * offset.x - _camera.basis.y * offset.y) * world_per_pixel


func _all_inside(points: Array[Vector3], area: Rect2) -> bool:
	for p in points:
		if _camera.is_position_behind(p) or not area.has_point(_camera.unproject_position(p)):
			return false
	return true
