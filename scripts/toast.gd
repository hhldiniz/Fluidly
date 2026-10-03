class_name Toast
extends PanelContainer
## Message bubble in the middle of the screen. It pops in with a short rise,
## stays for a while, then fades away. It never blocks taps on the bottles.

const RISE := 28.0
const MAX_WIDTH := 760.0

var _tween: Tween

@onready var _label: Label = $Label


func _ready() -> void:
	visible = false
	get_viewport().size_changed.connect(_recenter)


## Shows `text` centered on screen. With `duration` <= 0 it stays until hide_message().
func show_message(text: String, duration := 3.0) -> void:
	_label.text = text
	visible = true
	_recenter()
	var home := position
	pivot_offset = size * 0.5
	position = home + Vector2(0, RISE)
	scale = Vector2(0.8, 0.8)
	modulate.a = 0.0

	_restart_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "position", home, 0.4)
	_tween.tween_property(self, "scale", Vector2.ONE, 0.4)
	_tween.tween_property(self, "modulate:a", 1.0, 0.25)
	if duration > 0.0:
		_tween.chain().tween_interval(duration)
		_tween.chain().tween_callback(hide_message)


## Fades the message out while it drifts up a little.
func hide_message() -> void:
	if not visible:
		return
	_restart_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_tween.tween_property(self, "position", position - Vector2(0, RISE * 0.5), 0.3)
	_tween.tween_property(self, "scale", Vector2(0.95, 0.95), 0.3)
	_tween.tween_property(self, "modulate:a", 0.0, 0.3)
	_tween.chain().tween_callback(hide)


func _restart_tween() -> Tween:
	if _tween:
		_tween.kill()
	_tween = create_tween().set_parallel()
	return _tween


func _recenter() -> void:
	var view := get_viewport_rect().size
	# Wrap long messages instead of letting them run off narrow screens.
	var font := _label.get_theme_font(&"font")
	var natural := ceilf(font.get_string_size(_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1,
		_label.get_theme_font_size(&"font_size")).x)
	var limit := minf(MAX_WIDTH, view.x - 48.0) - get_theme_stylebox(&"panel").get_minimum_size().x
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if natural > limit else TextServer.AUTOWRAP_OFF
	_label.custom_minimum_size.x = minf(natural, limit)
	reset_size()
	position = ((view - size) * 0.5).round()
