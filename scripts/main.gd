extends Node2D
## Game loop: collect droplets, dodge embers, survive as long as you can.

enum State { READY, PLAYING, GAME_OVER }

const SAVE_PATH := "user://fluidly.cfg"
const ARENA := Rect2(0, 0, 1280, 720)
const MAX_DROPLETS := 5
const SAFE_SPAWN_DISTANCE := 260.0

@export var droplet_scene: PackedScene
@export var hazard_scene: PackedScene

var state := State.READY
var score := 0
var best := 0
var _spawn_timer := 0.0

@onready var player: Area2D = $Player
@onready var score_label: Label = $HUD/ScoreLabel
@onready var best_label: Label = $HUD/BestLabel
@onready var message_label: Label = $HUD/MessageLabel


func _ready() -> void:
	randomize()
	player.bounds = ARENA
	player.collected.connect(_on_collected)
	player.died.connect(_on_died)
	_load_best()
	_enter_ready()


func _draw() -> void:
	# Soft ripples as a background.
	var t := Time.get_ticks_msec() / 1000.0
	for i in 5:
		var r := fmod(t * 40.0 + i * 160.0, 800.0)
		var alpha := 0.07 * (1.0 - r / 800.0)
		draw_arc(ARENA.get_center(), r, 0.0, TAU, 96, Color(0.3, 0.8, 0.95, alpha), 3.0, true)
	draw_rect(ARENA.grow(-2.0), Color(0.3, 0.8, 0.95, 0.25), false, 3.0)


func _process(_delta: float) -> void:
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if state == State.PLAYING:
		return
	var pressed := false
	if event is InputEventKey and event.pressed and not event.echo:
		pressed = event.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]
	elif event is InputEventMouseButton and event.pressed:
		pressed = true
	elif event is InputEventScreenTouch and event.pressed:
		pressed = true
	if pressed:
		_start()


func _physics_process(delta: float) -> void:
	if state != State.PLAYING:
		return
	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		_spawn_timer = 1.1
		if get_tree().get_nodes_in_group("droplet").size() < MAX_DROPLETS:
			_spawn_droplet()


func _enter_ready() -> void:
	state = State.READY
	player.active = false
	_clear_entities()
	player.reset(ARENA.get_center())
	_update_labels()
	message_label.text = "Fluidly\n\nMove with arrow keys / WASD, or hold the mouse / touch to glide.\nCollect droplets, avoid the embers.\n\nPress SPACE, ENTER or tap to start"


func _start() -> void:
	_clear_entities()
	score = 0
	state = State.PLAYING
	player.reset(ARENA.get_center())
	player.active = true
	_spawn_timer = 0.0
	_update_labels()
	message_label.text = ""
	for i in 3:
		_spawn_droplet()


func _on_collected() -> void:
	score += 1
	if score % 3 == 0:
		_spawn_hazard()
	_update_labels()


func _on_died() -> void:
	if state != State.PLAYING:
		return
	state = State.GAME_OVER
	player.active = false
	if score > best:
		best = score
		_save_best()
	_update_labels()
	message_label.text = "Evaporated!\nScore: %d\n\nPress SPACE, ENTER or tap to try again" % score


func _spawn_droplet() -> void:
	var d: Area2D = droplet_scene.instantiate()
	d.position = _random_point_away_from_player(60.0)
	add_child(d)


func _spawn_hazard() -> void:
	var h: Area2D = hazard_scene.instantiate()
	h.bounds = ARENA
	h.position = _random_point_away_from_player(40.0, SAFE_SPAWN_DISTANCE)
	var speed := randf_range(110.0, 200.0) + minf(score * 3.0, 120.0)
	h.velocity = Vector2.from_angle(randf() * TAU) * speed
	add_child(h)


func _random_point_away_from_player(margin: float, min_distance := 0.0) -> Vector2:
	var area := ARENA.grow(-margin)
	var p := player.position
	for i in 20:
		p = Vector2(randf_range(area.position.x, area.end.x), randf_range(area.position.y, area.end.y))
		if p.distance_to(player.position) >= min_distance:
			break
	return p


func _clear_entities() -> void:
	for n in get_tree().get_nodes_in_group("droplet") + get_tree().get_nodes_in_group("hazard"):
		n.queue_free()


func _update_labels() -> void:
	score_label.text = "Score: %d" % score
	best_label.text = "Best: %d" % best


func _load_best() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		best = int(cfg.get_value("scores", "best", 0))


func _save_best() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("scores", "best", best)
	cfg.save(SAVE_PATH)
