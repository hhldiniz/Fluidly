class_name Bottle3D
extends Node3D
## A glass test tube with liquid, built from lathed meshes. The liquid surface is
## kept level by the liquid shader and sloshes with a damped spring that reacts to
## how the bottle moves and turns.

const RADIUS := 0.32
const HEIGHT := 2.1
const WALL := 0.035
const LIQUID_TOP := HEIGHT - 0.22 ## liquid level of a full bottle
const UNIT := (LIQUID_TOP - WALL) / Puzzle.CAPACITY
const MAX_BANDS := 6

const LIQUID_SHADER := preload("res://shaders/liquid.gdshader")

## Slosh spring: how strongly motion pushes the surface, how stiff and how damped it is.
const SLOSH_PUSH := 0.6
const SLOSH_TURN_PUSH := 0.08
const SLOSH_STIFFNESS := 90.0
const SLOSH_DAMPING := 3.0
const SLOSH_MAX := 0.5

const GLASS_COLOR := Color(0.8, 0.9, 1.0, 0.16)
const SELECTED_GLOW := Color(1.0, 0.72, 0.2)
const HINT_GLOW := Color(0.3, 1.0, 0.75)

static var _glass_mesh: ArrayMesh
static var _liquid_mesh: ArrayMesh
static var _cork_mesh: CylinderMesh
static var _cork_material: StandardMaterial3D

var layers: Array = [] ## color ids, bottom -> top
## Pour animation, as in Bottle: >0 top layers flowing in, <0 units flowing out.
var anim_units := 0
var anim_color := 0
var anim_frac := 1.0
var selected := false:
	set(value):
		selected = value
		_update_glow()
var hint := false:
	set(value):
		hint = value
		_hint_time = 0.0
		_update_glow()

var _glass_material := StandardMaterial3D.new()
var _liquid_material := ShaderMaterial.new()
var _cork := MeshInstance3D.new()
var _fill := WALL
var _wobble := Vector2.ZERO
var _wobble_velocity := Vector2.ZERO
var _last_position := Vector3.ZERO
var _last_velocity := Vector3.ZERO
var _last_turn := 0.0
var _last_turn_speed := 0.0
var _hint_time := 0.0


func _ready() -> void:
	if _glass_mesh == null:
		_build_shared_resources()

	_glass_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_glass_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_glass_material.albedo_color = GLASS_COLOR
	_glass_material.roughness = 0.06
	_glass_material.metallic_specular = 0.9
	_glass_material.rim_enabled = true
	_glass_material.rim = 0.7
	_glass_material.rim_tint = 0.4
	_glass_material.emission_enabled = true
	_glass_material.emission = Color.BLACK

	_liquid_material.shader = LIQUID_SHADER

	var liquid := MeshInstance3D.new()
	liquid.mesh = _liquid_mesh
	liquid.material_override = _liquid_material
	add_child(liquid)

	var glass := MeshInstance3D.new()
	glass.mesh = _glass_mesh
	glass.material_override = _glass_material
	glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(glass)

	_cork.mesh = _cork_mesh
	_cork.material_override = _cork_material
	_cork.position = Vector3(0, HEIGHT + 0.04, 0)
	_cork.visible = false
	add_child(_cork)

	reset_motion()
	refresh()


## Local height of the liquid surface when the bottle holds `units` units.
static func level_y(units: float) -> float:
	return WALL + units * UNIT


## Local position of the bottle opening.
static func mouth() -> Vector3:
	return Vector3(0, HEIGHT + 0.07, 0)


## Pushes the liquid surface, e.g. when liquid splashes in.
func kick(push: Vector2) -> void:
	_wobble_velocity += push


## Forgets the previous position, so a jump (layout change) does not slosh.
func reset_motion() -> void:
	_last_position = global_position if is_inside_tree() else position
	_last_velocity = Vector3.ZERO
	_last_turn = rotation.z
	_last_turn_speed = 0.0


## Pushes the current layers and pour animation to the liquid shader.
func refresh() -> void:
	var colors := PackedColorArray()
	var tops := PackedFloat32Array()
	colors.resize(MAX_BANDS)
	tops.resize(MAX_BANDS)
	var y := WALL
	var bands := BoardView.bands(layers, anim_units, anim_color, anim_frac)
	var count := mini(bands.size(), MAX_BANDS)
	for i in count:
		y += bands[i][1] * UNIT
		colors[i] = Puzzle.COLORS[bands[i][0]]
		tops[i] = y
	_fill = y
	# A sliver of liquid is hidden rather than drawn as a flickering film.
	if y - WALL < 0.005:
		count = 0
	_liquid_material.set_shader_parameter(&"band_colors", colors)
	_liquid_material.set_shader_parameter(&"band_tops", tops)
	_liquid_material.set_shader_parameter(&"band_count", count)
	_cork.visible = anim_units == 0 and Puzzle.is_complete(layers)
	_update_surface()


func _process(delta: float) -> void:
	if delta <= 0.0:
		return
	# The liquid lags behind the glass: acceleration and turning push the
	# surface, and a damped spring pulls it back to level.
	var velocity := (global_position - _last_position) / delta
	var acceleration := (velocity - _last_velocity) / delta
	var turn_speed := (rotation.z - _last_turn) / delta
	var turn_acceleration := (turn_speed - _last_turn_speed) / delta
	_last_position = global_position
	_last_velocity = velocity
	_last_turn = rotation.z
	_last_turn_speed = turn_speed

	var push := Vector2(acceleration.x, acceleration.z) * SLOSH_PUSH \
		+ Vector2(-turn_acceleration * SLOSH_TURN_PUSH, 0.0)
	_wobble_velocity += (push - _wobble * SLOSH_STIFFNESS) * delta
	_wobble_velocity *= exp(-SLOSH_DAMPING * delta)
	_wobble = (_wobble + _wobble_velocity * delta).limit_length(SLOSH_MAX)
	_update_surface()

	if hint:
		_hint_time += delta
		_update_glow()


func _update_surface() -> void:
	if not is_inside_tree():
		return
	# The surface plane passes through the bottle axis at the fill height. For a
	# cylinder any such plane leaves the same volume below it, so tilting keeps
	# the amount of liquid right.
	_liquid_material.set_shader_parameter(&"surface_point", global_transform * Vector3(0, _fill, 0))
	_liquid_material.set_shader_parameter(&"surface_normal", Vector3(_wobble.x, 1.0, _wobble.y).normalized())


func _update_glow() -> void:
	var glow := Color.BLACK
	var tint := GLASS_COLOR
	if selected:
		glow = SELECTED_GLOW * 0.6
		tint = Color(1.0, 0.85, 0.5, 0.3)
	elif hint:
		var pulse := 0.5 + 0.5 * sin(_hint_time * 8.0)
		glow = HINT_GLOW * (0.25 + 0.5 * pulse)
		tint = GLASS_COLOR.lerp(Color(0.5, 1.0, 0.85, 0.3), pulse)
	_glass_material.emission = glow
	_glass_material.albedo_color = tint


static func _build_shared_resources() -> void:
	var outer := _tube_profile(RADIUS, 0.0)
	# Lip around the opening.
	outer.append(Vector2(RADIUS, HEIGHT))
	outer.append(Vector2(RADIUS + 0.045, HEIGHT + 0.015))
	outer.append(Vector2(RADIUS + 0.045, HEIGHT + 0.07))
	outer.append(Vector2(RADIUS - 0.012, HEIGHT + 0.07))
	_glass_mesh = _lathe(outer)

	var inner_radius := RADIUS - WALL
	var inner := _tube_profile(inner_radius, WALL)
	inner.append(Vector2(inner_radius, HEIGHT - 0.02))
	inner.append(Vector2(0.0, HEIGHT - 0.02))
	_liquid_mesh = _lathe(inner)

	_cork_mesh = CylinderMesh.new()
	_cork_mesh.top_radius = inner_radius + 0.01
	_cork_mesh.bottom_radius = inner_radius - 0.03
	_cork_mesh.height = 0.3
	_cork_material = StandardMaterial3D.new()
	_cork_material.albedo_color = Color(0.69, 0.48, 0.3)
	_cork_material.roughness = 0.9


## Profile of a tube with a round bottom, from the bottom center up to where the walls start.
static func _tube_profile(radius: float, bottom: float) -> PackedVector2Array:
	var profile := PackedVector2Array()
	for i in 13:
		var a := -PI * 0.5 + PI * 0.5 * i / 12.0
		profile.append(Vector2(radius * cos(a), bottom + radius + radius * sin(a)))
	return profile


## Revolves a (radius, height) profile around the Y axis, with smooth normals.
static func _lathe(profile: PackedVector2Array, segments := 40) -> ArrayMesh:
	var normals := PackedVector2Array()
	for i in profile.size():
		var t := profile[mini(i + 1, profile.size() - 1)] - profile[maxi(i - 1, 0)]
		normals.append(Vector2(t.y, -t.x).normalized())
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in profile.size() - 1:
		for s in segments:
			var a0 := TAU * s / segments
			var a1 := TAU * (s + 1) / segments
			var quad := [[i, a0], [i, a1], [i + 1, a1], [i, a0], [i + 1, a1], [i + 1, a0]]
			for corner in quad:
				var p := profile[corner[0]]
				var n := normals[corner[0]]
				var c := cos(corner[1])
				var sn := sin(corner[1])
				st.set_normal(Vector3(n.x * c, n.y, n.x * sn))
				st.add_vertex(Vector3(p.x * c, p.y, p.x * sn))
	return st.commit()
