extends Area2D
## The player: a wobbly drop of water that glides toward the pointer/touch,
## or accelerates with the arrow keys / WASD.

signal collected
signal died

const ACCEL := 2200.0
const FRICTION := 3.2
const MAX_SPEED := 520.0
const FOLLOW_STRENGTH := 6.0
const BASE_RADIUS := 22.0
const POINTS := 28
const TRAIL_LENGTH := 14

var velocity := Vector2.ZERO
var bounds := Rect2(0, 0, 1280, 720)
var active := false
var size_bonus := 0.0 ## grows a little with every droplet collected
var _time := 0.0
var _pulse := 0.0
var _trail: Array[Vector2] = []
var _pointer_target: Variant = null ## Vector2 while a pointer/touch is held, otherwise null


func _ready() -> void:
	area_entered.connect(_on_area_entered)


func reset(at: Vector2) -> void:
	position = at
	velocity = Vector2.ZERO
	size_bonus = 0.0
	_trail.clear()
	_set_radius()


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_pointer_target = _to_world(event.position) if event.pressed else null
	elif event is InputEventScreenDrag:
		_pointer_target = _to_world(event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_pointer_target = _to_world(event.position) if event.pressed else null
	elif event is InputEventMouseMotion and _pointer_target != null:
		_pointer_target = _to_world(event.position)


func _to_world(screen_pos: Vector2) -> Vector2:
	return get_canvas_transform().affine_inverse() * screen_pos


func _physics_process(delta: float) -> void:
	_time += delta
	_pulse = move_toward(_pulse, 0.0, delta * 3.0)
	if active:
		_steer(delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, 600.0 * delta)
	velocity = velocity.limit_length(MAX_SPEED)
	position += velocity * delta
	_bounce_off_walls()

	_trail.push_front(position)
	if _trail.size() > TRAIL_LENGTH:
		_trail.pop_back()
	queue_redraw()


func _steer(delta: float) -> void:
	var dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	dir += Vector2(
		int(Input.is_key_pressed(KEY_D)) - int(Input.is_key_pressed(KEY_A)),
		int(Input.is_key_pressed(KEY_S)) - int(Input.is_key_pressed(KEY_W)))
	dir = dir.limit_length(1.0)
	if dir != Vector2.ZERO:
		velocity += dir * ACCEL * delta
	elif _pointer_target != null:
		var to_target: Vector2 = _pointer_target - position
		velocity = velocity.lerp(to_target * FOLLOW_STRENGTH, 1.0 - exp(-8.0 * delta))
	velocity *= exp(-FRICTION * delta * (0.4 if dir != Vector2.ZERO else 1.0))


func _bounce_off_walls() -> void:
	var r := _radius()
	var lo := bounds.position + Vector2(r, r)
	var hi := bounds.end - Vector2(r, r)
	if position.x < lo.x or position.x > hi.x:
		velocity.x *= -0.5
	if position.y < lo.y or position.y > hi.y:
		velocity.y *= -0.5
	position = position.clamp(lo, hi)


func _radius() -> float:
	return BASE_RADIUS + size_bonus


func _set_radius() -> void:
	(($CollisionShape2D as CollisionShape2D).shape as CircleShape2D).radius = _radius() * 0.9


func _on_area_entered(area: Area2D) -> void:
	if not active:
		return
	if area.is_in_group("droplet"):
		area.queue_free()
		size_bonus = minf(size_bonus + 0.6, 22.0)
		_pulse = 1.0
		_set_radius()
		collected.emit()
	elif area.is_in_group("hazard"):
		died.emit()


func _draw() -> void:
	# Fading trail.
	for i in range(_trail.size() - 1, 0, -1):
		var t := 1.0 - float(i) / TRAIL_LENGTH
		draw_circle(_trail[i] - position, _radius() * t * 0.8, Color(0.30, 0.79, 0.94, 0.12 * t))

	# Wobbly blob outline; the wobble reacts to speed and to pickups.
	var speed_factor := velocity.length() / MAX_SPEED
	var pts := PackedVector2Array()
	for i in POINTS:
		var a := TAU * i / POINTS
		var wobble := sin(a * 3.0 + _time * 5.0) * (1.2 + speed_factor * 3.0) \
			+ sin(a * 5.0 - _time * 7.0) * (0.8 + _pulse * 4.0)
		var r := _radius() + wobble + _pulse * 4.0
		# Stretch along the direction of travel.
		var p := Vector2(cos(a), sin(a)) * r
		if velocity.length() > 1.0:
			var d := velocity.normalized()
			var along := p.dot(d)
			p += d * along * speed_factor * 0.25
		pts.append(p)
	draw_colored_polygon(pts, Color(0.30, 0.79, 0.94, 0.95))
	pts.append(pts[0])
	draw_polyline(pts, Color(0.88, 0.98, 1.0, 0.9), 2.0, true)
	# Highlight.
	draw_circle(Vector2(-_radius() * 0.35, -_radius() * 0.35), _radius() * 0.22, Color(1, 1, 1, 0.55))
