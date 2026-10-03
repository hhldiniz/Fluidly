class_name Bottle
extends Node2D
## Draws one bottle and its liquid. The puzzle state lives in main.gd; this node
## only renders the layers it is given, plus the pour animation.

const WIDTH := 64.0
const HEIGHT := 210.0
const INSET := 6.0
const HEADROOM := 18.0
const UNIT_HEIGHT := (HEIGHT - 2.0 * INSET - HEADROOM) / Puzzle.CAPACITY

const GLASS_FILL := Color(1, 1, 1, 0.06)
const GLASS_EDGE := Color(0.85, 0.93, 1.0, 0.85)
const SELECTED_EDGE := Color(1.0, 0.84, 0.3)
const HINT_EDGE := Color(0.3, 1.0, 0.75)

var layers: Array = [] ## color ids, bottom -> top
var selected := false
var hint := false:
	set(value):
		hint = value
		_hint_time = 0.0
		queue_redraw()

## Pour animation: >0 means the top `anim_units` layers are flowing in, <0 means
## that many units of `anim_color` are flowing out (drawn above `layers`).
var anim_units := 0
var anim_color := 0
var anim_frac := 1.0

var _hint_time := 0.0
var _outline := PackedVector2Array()
var _inner := PackedVector2Array()


func _ready() -> void:
	_outline = _tube(WIDTH * 0.5, -HEIGHT * 0.5, HEIGHT * 0.5)
	_inner = _tube(WIDTH * 0.5 - INSET, -HEIGHT * 0.5, HEIGHT * 0.5 - INSET)


func _process(delta: float) -> void:
	if hint:
		_hint_time += delta
		queue_redraw()


## Local position of the bottle opening.
func mouth() -> Vector2:
	return Vector2(0, -HEIGHT * 0.5)


## Local y of the liquid surface when the bottle holds `units` units.
func surface_y(units: float) -> float:
	return HEIGHT * 0.5 - INSET - units * UNIT_HEIGHT


## Tube outline from the top-left corner, around the rounded bottom, to the top-right corner.
static func _tube(half_width: float, top: float, bottom: float) -> PackedVector2Array:
	var pts := PackedVector2Array([Vector2(-half_width, top)])
	var center := Vector2(0, bottom - half_width)
	for i in 17:
		var a := PI - PI * i / 16.0
		pts.append(center + Vector2(cos(a), sin(a)) * half_width)
	pts.append(Vector2(half_width, top))
	return pts


func _draw() -> void:
	draw_colored_polygon(_outline, GLASS_FILL)

	# Liquid: stacked bands clipped to the inside of the tube.
	var y := surface_y(0)
	for band in _bands():
		var h: float = band[1] * UNIT_HEIGHT
		if h < 0.05:
			continue
		var rect := PackedVector2Array([
			Vector2(-WIDTH, y - h), Vector2(WIDTH, y - h), Vector2(WIDTH, y), Vector2(-WIDTH, y)])
		for poly in Geometry2D.intersect_polygons(rect, _inner):
			draw_colored_polygon(poly, Puzzle.COLORS[band[0]])
		y -= h
	if y < surface_y(0) - 0.5:
		var hw := WIDTH * 0.5 - INSET
		draw_line(Vector2(-hw, y), Vector2(hw, y), Color(1, 1, 1, 0.35), 2.0)

	# Glass shine, outline and rim.
	draw_line(Vector2(-WIDTH * 0.5 + 13, -HEIGHT * 0.5 + 22), Vector2(-WIDTH * 0.5 + 13, HEIGHT * 0.5 - 44),
		Color(1, 1, 1, 0.16), 5.0)
	var edge := GLASS_EDGE
	if selected:
		edge = SELECTED_EDGE
	elif hint:
		edge = GLASS_EDGE.lerp(HINT_EDGE, 0.5 + 0.5 * sin(_hint_time * 8.0))
	draw_polyline(_outline, edge, 3.0, true)
	draw_rect(Rect2(-WIDTH * 0.5 - 6, -HEIGHT * 0.5 - 4, WIDTH + 12, 8), edge)

	# Cork on finished bottles.
	if anim_units == 0 and Puzzle.is_complete(layers):
		var cork := Rect2(-WIDTH * 0.5 + INSET + 4, -HEIGHT * 0.5 - 28, WIDTH - 2 * INSET - 8, 26)
		draw_rect(cork, Color(0.69, 0.48, 0.3))
		draw_rect(Rect2(cork.position + Vector2(0, 8), Vector2(cork.size.x, 4)), Color(0.55, 0.36, 0.2))


## Liquid bands as [color, height in units], bottom -> top, merging equal colors.
func _bands() -> Array:
	var bands := []
	for i in layers.size():
		var amount := 1.0
		if anim_units > 0 and i >= layers.size() - anim_units:
			amount = anim_frac
		_add_band(bands, layers[i], amount)
	if anim_units < 0:
		_add_band(bands, anim_color, -anim_units * anim_frac)
	return bands


static func _add_band(bands: Array, color: int, amount: float) -> void:
	if not bands.is_empty() and bands.back()[0] == color:
		bands.back()[1] += amount
	else:
		bands.append([color, amount])
