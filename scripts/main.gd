extends Node2D
## Color-sort puzzle. Tap a bottle, then tap another to pour into it. Liquids
## never mix: you can only pour onto the same color or into an empty bottle.
## The level is won when every bottle holds a single color.

const SAVE_PATH := "user://fluidly.cfg"
const TOP_MARGIN := 96.0
const BOTTOM_MARGIN := 104.0
const SIDE_MARGIN := 16.0
## Space reserved around each bottle (relative to its size) for spacing, lift and cork.
const CELL := Vector2(Bottle.WIDTH * 1.7, Bottle.HEIGHT * 1.45)
const MAX_SCALE := 1.6
const LIFT := 28.0
const POUR_ANGLE := 1.4 ## radians, ~80 degrees

var level := 1
var moves := 0
var state: Array = []
var initial_state: Array = []
var history: Array = []
var selected := -1
var busy := false
var won := false

var bottles: Array[Bottle] = []
var homes: Array[Vector2] = []
var bottle_scale := 1.0
var shelves: Array[Rect2] = []
var _layout_pending := false
var _pour_from: Bottle
var _pour_to: Bottle

@onready var bottle_root: Node2D = $Bottles
@onready var stream: Line2D = $Stream
@onready var level_label: Label = %LevelLabel
@onready var moves_label: Label = %MovesLabel
@onready var status_label: Label = %StatusLabel
@onready var undo_button: Button = %UndoButton
@onready var restart_button: Button = %RestartButton
@onready var hint_button: Button = %HintButton
@onready var win_overlay: Control = %WinOverlay
@onready var win_label: Label = %WinLabel
@onready var next_button: Button = %NextButton


func _ready() -> void:
	undo_button.pressed.connect(_undo)
	restart_button.pressed.connect(_restart)
	hint_button.pressed.connect(_show_hint)
	next_button.pressed.connect(func() -> void: _start_level(level + 1))
	get_viewport().size_changed.connect(_on_viewport_resized)
	_start_level(_level_from_url() if _level_from_url() > 0 else _load_level())


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_on_tap(get_canvas_transform().affine_inverse() * event.position)
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_Z, KEY_BACKSPACE:
				_undo()
			KEY_R:
				_restart()
			KEY_H:
				_show_hint()
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
				if won:
					_start_level(level + 1)


func _draw() -> void:
	for shelf in shelves:
		draw_rect(shelf, Color(0.55, 0.75, 0.95, 0.12))


# --- Level flow -------------------------------------------------------------

func _start_level(number: int) -> void:
	level = maxi(number, 1)
	initial_state = LevelGenerator.generate(level)
	won = false
	win_overlay.visible = false
	_save_level()
	_rebuild_bottles()
	_reset_to(initial_state)


func _reset_to(start: Array) -> void:
	state = Puzzle.copy(start)
	history.clear()
	moves = 0
	selected = -1
	for bottle in bottles:
		bottle.selected = false
		bottle.hint = false
	_layout()
	_refresh()
	status_label.text = "Tap a bottle, then tap where to pour it."


func _restart() -> void:
	if busy or history.is_empty():
		return
	_reset_to(initial_state)


func _undo() -> void:
	if busy or won or history.is_empty():
		return
	state = history.pop_back()
	moves -= 1
	_select(-1)
	_clear_hint()
	_refresh()
	status_label.text = ""


func _check_finished() -> void:
	if Puzzle.is_solved(state):
		won = true
		_save_level(level + 1)
		win_label.text = "Level %d complete!\nSolved in %d moves." % [level, moves]
		win_overlay.visible = true
		next_button.grab_focus()
	elif not Puzzle.has_any_move(state):
		status_label.text = "No moves left. Undo or restart."


# --- Interaction ------------------------------------------------------------

func _on_tap(pos: Vector2) -> void:
	if busy or won:
		return
	var tapped := _bottle_at(pos)
	if tapped == -1 or tapped == selected:
		_select(-1)
	elif selected == -1:
		if state[tapped].is_empty() or Puzzle.is_complete(state[tapped]):
			_shake(tapped)
		else:
			_select(tapped)
	elif Puzzle.can_pour(state, selected, tapped):
		_pour(selected, tapped)
	elif state[tapped].is_empty() or Puzzle.is_complete(state[tapped]):
		_shake(tapped)
	else:
		# Not a valid target: pick it up instead.
		_select(tapped)


func _bottle_at(pos: Vector2) -> int:
	var half := Vector2(Bottle.WIDTH * 0.5 + 12, Bottle.HEIGHT * 0.5 + LIFT) * bottle_scale
	for i in bottles.size():
		if Rect2(homes[i] - half, half * 2.0).has_point(pos):
			return i
	return -1


func _select(index: int) -> void:
	_clear_hint()
	if selected != -1:
		bottles[selected].selected = false
		_move_bottle(selected, homes[selected])
	selected = index
	if index != -1:
		bottles[index].selected = true
		_move_bottle(index, homes[index] + Vector2(0, -LIFT * bottle_scale))
	for bottle in bottles:
		bottle.queue_redraw()


func _move_bottle(index: int, to: Vector2) -> void:
	create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT) \
		.tween_property(bottles[index], "position", to, 0.15)


func _shake(index: int) -> void:
	var bottle := bottles[index]
	var home := homes[index]
	var tween := create_tween()
	for offset in [-8.0, 8.0, -5.0, 0.0]:
		tween.tween_property(bottle, "position", home + Vector2(offset * bottle_scale, 0), 0.05)


func _pour(from: int, to: int) -> void:
	busy = true
	_clear_hint()
	status_label.text = ""
	var src := bottles[from]
	var dst := bottles[to]
	var color: int = state[from].back()
	history.append(Puzzle.copy(state))
	var amount := Puzzle.pour(state, from, to)
	moves += 1
	selected = -1
	src.selected = false
	src.z_index = 1

	# Swing the source over the target's mouth and tilt it.
	var dir := 1.0 if homes[from].x <= homes[to].x else -1.0
	var angle := POUR_ANGLE * dir
	var dst_mouth := dst.position + dst.mouth() * bottle_scale
	var target := dst_mouth + Vector2(0, -26.0 * bottle_scale) - (src.mouth() * bottle_scale).rotated(angle)
	var tween := create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(src, "position", target, 0.28)
	tween.tween_property(src, "rotation", angle, 0.28)
	await tween.finished

	# Let the liquid flow.
	src.layers = state[from].duplicate()
	src.anim_units = -amount
	src.anim_color = color
	dst.layers = state[to].duplicate()
	dst.anim_units = amount
	_pour_from = src
	_pour_to = dst
	_set_pour_progress(0.0)
	stream.default_color = Puzzle.COLORS[color]
	stream.width = 7.0 * bottle_scale
	stream.points = PackedVector2Array([
		to_local(src.to_global(src.mouth())),
		to_local(dst.to_global(Vector2(0, dst.surface_y(state[to].size() - amount)))),
	])
	stream.visible = true
	tween = create_tween()
	tween.tween_method(_set_pour_progress, 0.0, 1.0, 0.15 + 0.12 * amount)
	await tween.finished
	stream.visible = false
	src.anim_units = 0
	dst.anim_units = 0

	# Swing back.
	tween = create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(src, "position", homes[from], 0.25)
	tween.tween_property(src, "rotation", 0.0, 0.25)
	await tween.finished
	src.z_index = 0
	busy = false
	if _layout_pending:
		_layout()
	_refresh()
	_check_finished()


func _set_pour_progress(t: float) -> void:
	_pour_from.anim_frac = 1.0 - t
	_pour_to.anim_frac = t
	_pour_from.queue_redraw()
	_pour_to.queue_redraw()


func _show_hint() -> void:
	if busy or won:
		return
	var solution = Solver.solve(state, 60000)
	if solution == null:
		status_label.text = "No solution from here. Try undo or restart."
	elif not solution.is_empty():
		var move: Vector2i = solution[0]
		_select(move.x)
		bottles[move.y].hint = true
		status_label.text = "Hint: pour the raised bottle into the glowing one."


func _clear_hint() -> void:
	for bottle in bottles:
		bottle.hint = false


# --- Layout & rendering -----------------------------------------------------

func _rebuild_bottles() -> void:
	for bottle in bottles:
		bottle.queue_free()
	bottles.clear()
	for i in initial_state.size():
		var bottle := Bottle.new()
		bottle_root.add_child(bottle)
		bottles.append(bottle)


func _on_viewport_resized() -> void:
	if busy:
		_layout_pending = true
	else:
		_layout()


## Places the bottles in centered rows, choosing the row count that makes them largest.
func _layout() -> void:
	_layout_pending = false
	var view := get_viewport_rect()
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
	var index := 0
	for r in rows:
		@warning_ignore("integer_division")
		var count := n / rows + (1 if r < n % rows else 0)
		var left := area.get_center().x - count * cell.x * 0.5
		# Bottles sit low in their cell, leaving room above for the lift and cork.
		var y := top + r * cell.y + cell.y - Bottle.HEIGHT * 0.5 * bottle_scale - 0.1 * cell.y
		for c in count:
			homes.append(Vector2(left + (c + 0.5) * cell.x, y))
			index += 1
		var shelf_y := y + (Bottle.HEIGHT * 0.5 + 4.0) * bottle_scale
		shelves.append(Rect2(left + 8.0, shelf_y, count * cell.x - 16.0, 6.0 * bottle_scale))

	for i in n:
		var bottle := bottles[i]
		bottle.scale = Vector2.ONE * bottle_scale
		bottle.rotation = 0.0
		bottle.position = homes[i] + (Vector2(0, -LIFT * bottle_scale) if i == selected else Vector2.ZERO)
	queue_redraw()


func _refresh() -> void:
	for i in bottles.size():
		bottles[i].layers = state[i].duplicate()
		bottles[i].queue_redraw()
	level_label.text = "Level %d" % level
	moves_label.text = "Moves: %d" % moves
	undo_button.disabled = history.is_empty()
	restart_button.disabled = history.is_empty()


# --- Progress ---------------------------------------------------------------

## On the web build, `?level=N` in the page URL opens level N directly.
func _level_from_url() -> int:
	if not OS.has_feature("web"):
		return 0
	var value = JavaScriptBridge.eval("new URLSearchParams(window.location.search).get('level')", true)
	return int(value) if value is String and value.is_valid_int() else 0


func _load_level() -> int:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		return int(cfg.get_value("progress", "level", 1))
	return 1


func _save_level(value := level) -> void:
	var cfg := ConfigFile.new()
	cfg.load(SAVE_PATH)
	cfg.set_value("progress", "level", value)
	cfg.save(SAVE_PATH)
