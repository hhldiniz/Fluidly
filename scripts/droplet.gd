extends Area2D
## A small droplet that the player collects. Bobs gently and pops in on spawn.

var _time := randf() * TAU
var _age := 0.0


func _process(delta: float) -> void:
	_time += delta
	_age += delta
	queue_redraw()


func _draw() -> void:
	var pop := minf(_age * 5.0, 1.0)
	var r := (9.0 + sin(_time * 3.0) * 1.5) * pop
	draw_circle(Vector2.ZERO, r * 1.9, Color(0.46, 0.91, 1.0, 0.12))
	draw_circle(Vector2.ZERO, r, Color(0.46, 0.91, 1.0, 0.95))
	draw_circle(Vector2(-r * 0.3, -r * 0.3), r * 0.28, Color(1, 1, 1, 0.8))
