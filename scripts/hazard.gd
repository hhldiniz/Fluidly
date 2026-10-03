extends Area2D
## A drifting ember that ends the run on contact. Bounces off the arena walls.

var velocity := Vector2.ZERO
var bounds := Rect2(0, 0, 1280, 720)
var _time := randf() * TAU
var _age := 0.0
const RADIUS := 16.0
const SPIKES := 10
const ARMING_TIME := 0.8 ## harmless while it grows in, so spawns never feel unfair


func _ready() -> void:
	monitorable = false


func _physics_process(delta: float) -> void:
	_age += delta
	_time += delta
	if not monitorable and _age >= ARMING_TIME:
		monitorable = true
	position += velocity * delta
	if position.x < bounds.position.x + RADIUS or position.x > bounds.end.x - RADIUS:
		velocity.x *= -1.0
	if position.y < bounds.position.y + RADIUS or position.y > bounds.end.y - RADIUS:
		velocity.y *= -1.0
	position = position.clamp(bounds.position + Vector2(RADIUS, RADIUS), bounds.end - Vector2(RADIUS, RADIUS))
	queue_redraw()


func _draw() -> void:
	var pop := minf(_age / ARMING_TIME, 1.0)
	var pts := PackedVector2Array()
	for i in SPIKES * 2:
		var a := TAU * i / (SPIKES * 2) + _time
		var r := (RADIUS if i % 2 == 0 else RADIUS * 0.62) * pop
		pts.append(Vector2(cos(a), sin(a)) * r)
	draw_circle(Vector2.ZERO, RADIUS * 1.8 * pop, Color(1.0, 0.35, 0.2, 0.12))
	draw_colored_polygon(pts, Color(1.0, 0.42, 0.21))
	draw_circle(Vector2.ZERO, RADIUS * 0.35 * pop, Color(1.0, 0.85, 0.4))
