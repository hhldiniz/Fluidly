class_name View2D
extends BoardView
## Flat view: bottles drawn with Bottle (CanvasItem drawing) on shelves.

const TOP_MARGIN := 80.0
const BOTTOM_MARGIN := 104.0
const SIDE_MARGIN := 16.0
## Space reserved around each bottle (relative to its size) for spacing, lift and cork.
const CELL := Vector2(Bottle.WIDTH * 1.7, Bottle.HEIGHT * 1.45)
const MAX_SCALE := 1.6
const LIFT := 28.0

var bottles: Array[Bottle] = []
var homes: Array[Vector2] = []
var bottle_scale := 1.0
var shelves: Array[Rect2] = []

var _canvas := Node2D.new()
var _stream := Line2D.new()
var _pour_from: Bottle
var _pour_to: Bottle


func _ready() -> void:
	add_child(_canvas)
	_canvas.draw.connect(_draw_shelves)
	_stream.visible = false
	_stream.z_index = 2
	_stream.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_stream.end_cap_mode = Line2D.LINE_CAP_ROUND
	add_child(_stream)


func build(bottle_count: int) -> void:
	for bottle in bottles:
		bottle.queue_free()
	bottles.clear()
	for i in bottle_count:
		var bottle := Bottle.new()
		_canvas.add_child(bottle)
		bottles.append(bottle)


func set_active(active: bool) -> void:
	_canvas.visible = active
	if not active:
		_stream.visible = false


## Places the bottles in centered rows, choosing the row count that makes them largest.
func relayout() -> void:
	var view := _canvas.get_viewport_rect()
	var area := Rect2(view.position + Vector2(SIDE_MARGIN, TOP_MARGIN),
		view.size - Vector2(2.0 * SIDE_MARGIN, TOP_MARGIN + BOTTOM_MARGIN))
	var n := bottles.size()
	var rows := 1
	var best := 0.0
	for r in range(1, n + 1):
		var cols := ceili(float(n) / r)
		var s := minf(area.size.x / (cols * CELL.x), area.size.y / (r * CELL.y))
		if s > best:
			best = s
			rows = r
	bottle_scale = minf(best, MAX_SCALE)

	var cell := CELL * bottle_scale
	var top := area.position.y + (area.size.y - rows * cell.y) * 0.5
	homes.clear()
	shelves.clear()
	for r in rows:
		@warning_ignore("integer_division")
		var count := n / rows + (1 if r < n % rows else 0)
		var left := area.get_center().x - count * cell.x * 0.5
		# Bottles sit low in their cell, leaving room above for the lift and cork.
		var y := top + r * cell.y + cell.y - Bottle.HEIGHT * 0.5 * bottle_scale - 0.1 * cell.y
		for c in count:
			homes.append(Vector2(left + (c + 0.5) * cell.x, y))
		var shelf_y := y + (Bottle.HEIGHT * 0.5 + 4.0) * bottle_scale
		shelves.append(Rect2(left + 8.0, shelf_y, count * cell.x - 16.0, 6.0 * bottle_scale))

	for i in n:
		var bottle := bottles[i]
		bottle.scale = Vector2.ONE * bottle_scale
		bottle.rotation = 0.0
		bottle.position = homes[i] + (_lift() if bottle.selected else Vector2.ZERO)
	_canvas.queue_redraw()


func show_state(state: Array) -> void:
	for i in bottles.size():
		bottles[i].layers = state[i].duplicate()
		bottles[i].anim_units = 0
		bottles[i].queue_redraw()


func bottle_at(pos: Vector2) -> int:
	var half := Vector2(Bottle.WIDTH * 0.5 + 12, Bottle.HEIGHT * 0.5 + LIFT) * bottle_scale
	for i in bottles.size():
		if Rect2(homes[i] - half, half * 2.0).has_point(pos):
			return i
	return -1


func set_selected(index: int, selected: bool, move := true) -> void:
	var bottle := bottles[index]
	bottle.selected = selected
	bottle.queue_redraw()
	if move:
		create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT) \
			.tween_property(bottle, "position", homes[index] + (_lift() if selected else Vector2.ZERO), 0.15)


func set_hint(index: int, on: bool) -> void:
	bottles[index].hint = on


func shake(index: int) -> void:
	var bottle := bottles[index]
	var tween := create_tween()
	for offset in [-8.0, 8.0, -5.0, 0.0]:
		tween.tween_property(bottle, "position", homes[index] + Vector2(offset * bottle_scale, 0), 0.05)


func swing_to_pour(from: int, to: int) -> void:
	var src := bottles[from]
	var dst := bottles[to]
	src.z_index = 1
	var angle := POUR_ANGLE * (1.0 if homes[from].x <= homes[to].x else -1.0)
	var dst_mouth := dst.position + dst.mouth() * bottle_scale
	var target := dst_mouth + Vector2(0, -26.0 * bottle_scale) - (src.mouth() * bottle_scale).rotated(angle)
	var tween := create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(src, "position", target, 0.28)
	tween.tween_property(src, "rotation", angle, 0.28)
	await tween.finished


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
	_set_pour_progress(0.0)
	_stream.default_color = Puzzle.COLORS[color]
	_stream.width = 7.0 * bottle_scale
	_stream.points = PackedVector2Array([
		src.to_global(src.mouth()),
		dst.to_global(Vector2(0, dst.surface_y(state[to].size() - amount))),
	])
	_stream.visible = true
	var tween := create_tween()
	tween.tween_method(_set_pour_progress, 0.0, 1.0, 0.15 + 0.12 * amount)
	await tween.finished
	_stream.visible = false
	src.anim_units = 0
	dst.anim_units = 0
	src.queue_redraw()
	dst.queue_redraw()


func swing_back(from: int) -> void:
	var src := bottles[from]
	var tween := create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(src, "position", homes[from], 0.25)
	tween.tween_property(src, "rotation", 0.0, 0.25)
	await tween.finished
	src.z_index = 0


func _set_pour_progress(t: float) -> void:
	_pour_from.anim_frac = 1.0 - t
	_pour_to.anim_frac = t
	_pour_from.queue_redraw()
	_pour_to.queue_redraw()


func _lift() -> Vector2:
	return Vector2(0, -LIFT * bottle_scale)


func _draw_shelves() -> void:
	for shelf in shelves:
		_canvas.draw_rect(shelf, Color(0.55, 0.75, 0.95, 0.12))
