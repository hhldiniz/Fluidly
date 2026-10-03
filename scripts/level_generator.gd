class_name LevelGenerator
## Builds deterministic, solvable levels: level N always produces the same puzzle.

const EMPTY_BOTTLES := 2
const MAX_ATTEMPTS := 200


@warning_ignore("integer_division")
static func colors_for_level(level: int) -> int:
	return mini(3 + (maxi(level, 1) - 1) / 2, Puzzle.COLORS.size())


static func generate(level: int) -> Array:
	var color_count := colors_for_level(level)
	var rng := RandomNumberGenerator.new()
	var bottles := []
	for attempt in MAX_ATTEMPTS:
		rng.seed = hash("fluidly:%d:%d" % [level, attempt])

		# Pick which palette colors this level uses.
		var palette := range(Puzzle.COLORS.size())
		_shuffle(palette, rng)

		var pool := []
		for c in color_count:
			for i in Puzzle.CAPACITY:
				pool.append(palette[c])
		_shuffle(pool, rng)

		bottles = []
		for b in color_count:
			bottles.append(pool.slice(b * Puzzle.CAPACITY, (b + 1) * Puzzle.CAPACITY))
		for e in EMPTY_BOTTLES:
			bottles.append([])

		if _has_complete_bottle(bottles):
			continue
		if Solver.solve(bottles) != null:
			return bottles
	return bottles


static func _shuffle(items: Array, rng: RandomNumberGenerator) -> void:
	for i in range(items.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = items[i]
		items[i] = items[j]
		items[j] = tmp


static func _has_complete_bottle(bottles: Array) -> bool:
	for bottle in bottles:
		if Puzzle.is_complete(bottle):
			return true
	return false
