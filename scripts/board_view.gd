class_name BoardView
extends Node
## Renders the bottles. main.gd owns the rules, state and input; a view only
## shows the state it is given and animates moves. Subclasses: View2D, View3D.

const POUR_ANGLE := 1.4 ## radians, ~80 degrees


## Creates the bottles for a new level.
func build(_bottle_count: int) -> void:
	pass


## Shows or hides this view.
func set_active(_active: bool) -> void:
	pass


## Places the bottles to fit the current screen and puts them at rest.
func relayout() -> void:
	pass


## Updates every bottle's liquid to match `state`.
func show_state(_state: Array) -> void:
	pass


## Index of the bottle under `pos` (viewport coordinates), or -1.
func bottle_at(_pos: Vector2) -> int:
	return -1


## Highlights a bottle as picked up. With `move`, also lifts/lowers it.
func set_selected(_index: int, _selected: bool, _move := true) -> void:
	pass


## Makes a bottle glow as the hint target.
func set_hint(_index: int, _on: bool) -> void:
	pass


## Shakes a bottle to signal an invalid move.
func shake(_index: int) -> void:
	pass


## Coroutine: swings bottle `from` over bottle `to` and tilts it.
func swing_to_pour(_from: int, _to: int) -> void:
	pass


## Coroutine: animates `amount` units of `color` flowing from `from` into `to`.
## `state` is the puzzle state after the pour.
func flow(_from: int, _to: int, _color: int, _amount: int, _state: Array) -> void:
	pass


## Coroutine: returns bottle `from` to its place after a pour.
func swing_back(_from: int) -> void:
	pass


## Liquid bands as [color, height in units], bottom -> top, merging equal colors.
## `anim_units` > 0: the top layers are flowing in, scaled by `anim_frac`.
## `anim_units` < 0: that many units of `anim_color` are flowing out, drawn on top.
static func bands(layers: Array, anim_units := 0, anim_color := 0, anim_frac := 1.0) -> Array:
	var out := []
	for i in layers.size():
		var amount := 1.0
		if anim_units > 0 and i >= layers.size() - anim_units:
			amount = anim_frac
		_add_band(out, layers[i], amount)
	if anim_units < 0:
		_add_band(out, anim_color, -anim_units * anim_frac)
	return out


static func _add_band(out: Array, color: int, amount: float) -> void:
	if not out.is_empty() and out.back()[0] == color:
		out.back()[1] += amount
	else:
		out.append([color, amount])
