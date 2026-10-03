extends Node2D
## Color-sort puzzle. Tap a bottle, then tap another to pour into it. Liquids
## never mix: you can only pour onto the same color or into an empty bottle.
## The level is won when every bottle holds a single color.
##
## This script owns the rules, state, input, sound and HUD. Drawing is done by
## a BoardView: View2D (flat) or View3D (3D bottles with sloshing liquid), chosen
## in the settings.

const SAVE_PATH := "user://fluidly.cfg"
const GRAPHICS_2D := "2d"
const GRAPHICS_3D := "3d"

var level := 1
var moves := 0
var state: Array = []
var initial_state: Array = []
var history: Array = []
var selected := -1
var hint_target := -1
var busy := false
var won := false
var graphics := GRAPHICS_2D
var view: BoardView

var _views := {}
var _layout_pending := false

@onready var level_label: Label = %LevelLabel
@onready var moves_label: Label = %MovesLabel
@onready var toast: Toast = %Toast
@onready var undo_button: Button = %UndoButton
@onready var restart_button: Button = %RestartButton
@onready var hint_button: Button = %HintButton
@onready var settings_button: Button = %SettingsButton
@onready var win_overlay: Control = %WinOverlay
@onready var win_label: Label = %WinLabel
@onready var next_button: Button = %NextButton
@onready var settings_overlay: Control = %SettingsOverlay
@onready var graphics_2d_button: Button = %Graphics2DButton
@onready var graphics_3d_button: Button = %Graphics3DButton
@onready var sound_button: Button = %SoundButton
@onready var close_settings_button: Button = %CloseSettingsButton
@onready var sfx: Sfx = $Sfx


func _ready() -> void:
	undo_button.pressed.connect(_undo)
	restart_button.pressed.connect(_restart)
	hint_button.pressed.connect(_show_hint)
	settings_button.pressed.connect(_open_settings)
	next_button.pressed.connect(func() -> void: _start_level(level + 1))
	graphics_2d_button.pressed.connect(_choose_graphics.bind(GRAPHICS_2D))
	graphics_3d_button.pressed.connect(_choose_graphics.bind(GRAPHICS_3D))
	sound_button.pressed.connect(_toggle_sound)
	close_settings_button.pressed.connect(_close_settings)
	get_viewport().size_changed.connect(_on_viewport_resized)

	_set_muted(bool(_load_setting("settings", "muted", false)))
	var url_graphics := _url_param("view")
	_use_graphics(url_graphics if url_graphics in [GRAPHICS_2D, GRAPHICS_3D]
		else str(_load_setting("settings", "graphics", GRAPHICS_2D)))
	var url_level := _url_param("level")
	_start_level(int(url_level) if url_level.is_valid_int() else int(_load_setting("progress", "level", 1)))


func _unhandled_input(event: InputEvent) -> void:
	if settings_overlay.visible:
		if event.is_action_pressed(&"ui_cancel"):
			_close_settings()
		return
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
			KEY_M:
				_toggle_sound()
			KEY_V:
				_choose_graphics(GRAPHICS_3D if graphics == GRAPHICS_2D else GRAPHICS_2D)
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
				if won:
					_start_level(level + 1)


# --- Level flow -------------------------------------------------------------

func _start_level(number: int) -> void:
	level = maxi(number, 1)
	initial_state = LevelGenerator.generate(level)
	won = false
	win_overlay.visible = false
	_save_level()
	view.build(initial_state.size())
	_reset_to(initial_state)


func _reset_to(start: Array) -> void:
	state = Puzzle.copy(start)
	history.clear()
	moves = 0
	_select(-1, false)
	view.relayout()
	_refresh()
	toast.show_message("Tap a bottle, then tap where to pour it.")


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
	_refresh()
	sfx.play(&"pick", 0.8)
	toast.hide_message()


func _check_finished() -> void:
	if Puzzle.is_solved(state):
		won = true
		_save_level(level + 1)
		win_label.text = "Level %d complete!\nSolved in %d moves." % [level, moves]
		win_overlay.visible = true
		next_button.grab_focus()
		get_tree().create_timer(0.25).timeout.connect(sfx.play.bind(&"victory"))
	elif not Puzzle.has_any_move(state):
		toast.show_message("No moves left. Undo or restart.", 0.0)


# --- Interaction ------------------------------------------------------------

func _on_tap(pos: Vector2) -> void:
	if busy or won:
		return
	var tapped := view.bottle_at(pos)
	if tapped == -1 or tapped == selected:
		if selected != -1:
			sfx.play(&"pick", 0.85, -4.0)
		_select(-1)
	elif selected == -1:
		if state[tapped].is_empty() or Puzzle.is_complete(state[tapped]):
			_shake(tapped)
		else:
			_pick_up(tapped)
	elif Puzzle.can_pour(state, selected, tapped):
		_pour(selected, tapped)
	elif state[tapped].is_empty() or Puzzle.is_complete(state[tapped]):
		_shake(tapped)
	else:
		# Not a valid target: pick it up instead.
		_pick_up(tapped)


func _pick_up(index: int) -> void:
	_select(index)
	sfx.play(&"pick", randf_range(0.96, 1.06))


func _select(index: int, animate := true) -> void:
	_clear_hint()
	if selected != -1:
		view.set_selected(selected, false, animate)
	selected = index
	if index != -1:
		view.set_selected(index, true, animate)


func _shake(index: int) -> void:
	sfx.play(&"invalid")
	view.shake(index)


func _pour(from: int, to: int) -> void:
	busy = true
	_clear_hint()
	toast.hide_message()
	var color: int = state[from].back()
	history.append(Puzzle.copy(state))
	var amount := Puzzle.pour(state, from, to)
	moves += 1
	selected = -1
	view.set_selected(from, false, false)

	await view.swing_to_pour(from, to)
	# The bubbles sound higher as the target bottle fills up.
	var pour_sound := sfx.play(&"pour", 1.0 + 0.08 * (state[to].size() - amount))
	await view.flow(from, to, color, amount, state)
	sfx.fade_out(pour_sound, &"pour")
	if Puzzle.is_complete(state[to]):
		sfx.play(&"cork")
	await view.swing_back(from)

	busy = false
	if _layout_pending:
		_layout_pending = false
		view.relayout()
	_refresh()
	_check_finished()


func _show_hint() -> void:
	if busy or won:
		return
	var solution = Solver.solve(state, 60000)
	if solution == null:
		toast.show_message("No solution from here. Try undo or restart.")
	elif not solution.is_empty():
		var move: Vector2i = solution[0]
		_pick_up(move.x)
		hint_target = move.y
		view.set_hint(hint_target, true)
		toast.show_message("Hint: pour the raised bottle into the glowing one.")


func _clear_hint() -> void:
	if hint_target != -1:
		view.set_hint(hint_target, false)
		hint_target = -1


func _on_viewport_resized() -> void:
	if busy:
		_layout_pending = true
	else:
		view.relayout()


func _refresh() -> void:
	view.show_state(state)
	level_label.text = "Level %d" % level
	moves_label.text = "Moves: %d" % moves
	undo_button.disabled = history.is_empty()
	restart_button.disabled = history.is_empty()


# --- Settings ---------------------------------------------------------------

func _open_settings() -> void:
	if busy:
		return
	settings_overlay.visible = true
	(graphics_3d_button if graphics == GRAPHICS_3D else graphics_2d_button).grab_focus()


func _close_settings() -> void:
	settings_overlay.visible = false


func _choose_graphics(mode: String) -> void:
	if busy or mode == graphics:
		_sync_settings_buttons()
		return
	_use_graphics(mode)
	_save_setting("settings", "graphics", mode)
	# Show the current level in the new view.
	_clear_hint()
	var was_selected := selected
	selected = -1
	view.build(state.size())
	view.relayout()
	_refresh()
	if was_selected != -1:
		_select(was_selected, false)
		view.relayout()


## Switches the active view, creating it the first time it is used.
func _use_graphics(mode: String) -> void:
	if view:
		view.set_active(false)
	graphics = mode
	if not _views.has(mode):
		var created: BoardView = View3D.new() if mode == GRAPHICS_3D else View2D.new()
		add_child(created)
		move_child(created, 0) # keep the views below the HUD and sound nodes
		_views[mode] = created
	view = _views[mode]
	view.set_active(true)
	_sync_settings_buttons()


func _sync_settings_buttons() -> void:
	graphics_2d_button.set_pressed_no_signal(graphics == GRAPHICS_2D)
	graphics_3d_button.set_pressed_no_signal(graphics == GRAPHICS_3D)


func _toggle_sound() -> void:
	_set_muted(not sfx.muted)
	_save_setting("settings", "muted", sfx.muted)


func _set_muted(value: bool) -> void:
	sfx.muted = value
	sound_button.text = "Off" if value else "On"
	sound_button.set_pressed_no_signal(not value)


# --- Progress ---------------------------------------------------------------

## On the web build, `?level=N` and `?view=3d` in the page URL pick the level and graphics.
func _url_param(name: String) -> String:
	if not OS.has_feature("web"):
		return ""
	var value = JavaScriptBridge.eval("new URLSearchParams(window.location.search).get('%s')" % name, true)
	return value if value is String else ""


func _save_level(value := level) -> void:
	_save_setting("progress", "level", value)


func _load_setting(section: String, key: String, default: Variant) -> Variant:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		return cfg.get_value(section, key, default)
	return default


func _save_setting(section: String, key: String, value: Variant) -> void:
	var cfg := ConfigFile.new()
	cfg.load(SAVE_PATH)
	cfg.set_value(section, key, value)
	cfg.save(SAVE_PATH)
