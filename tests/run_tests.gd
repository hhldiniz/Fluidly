extends SceneTree
## Headless tests: godot --headless -s res://tests/run_tests.gd
## Exits with the number of failed checks.

var _failures := 0


func _init() -> void:
	_test_rules()
	_test_generated_levels()
	print("FAILED: %d check(s)" % _failures if _failures else "All tests passed")
	quit(_failures)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error("FAIL: " + message)


func _test_rules() -> void:
	var state := [[0, 1, 1], [2, 1], [], [0, 0, 0, 2]]
	_check(Puzzle.can_pour(state, 0, 1), "pour onto the same color")
	_check(Puzzle.can_pour(state, 0, 2), "pour into an empty bottle")
	_check(not Puzzle.can_pour(state, 0, 3), "cannot pour into a full bottle")
	_check(not Puzzle.can_pour(state, 2, 0), "cannot pour from an empty bottle")
	_check(not Puzzle.can_pour([[0], [1]], 0, 1), "colors never mix")

	_check(Puzzle.pour(state, 0, 1) == 2, "whole color band moves when it fits")
	_check(state[0] == [0] and state[1] == [2, 1, 1, 1], "pour result")

	var partial := [[1, 1, 1], [0, 0, 1]]
	_check(Puzzle.pour(partial, 0, 1) == 1, "only what fits is poured")
	_check(partial[0] == [1, 1] and partial[1] == [0, 0, 1, 1], "partial pour result")
	Puzzle.unpour(partial, 0, 1, 1)
	_check(partial == [[1, 1, 1], [0, 0, 1]], "unpour reverts a pour")

	_check(Puzzle.is_solved([[0, 0, 0, 0], [], [1, 1, 1, 1]]), "sorted state is solved")
	_check(not Puzzle.is_solved([[0, 0, 0], [0], [1, 1, 1, 1]]), "split color is not solved")
	_check(not Puzzle.has_any_move([[0, 1, 0, 1], [1, 0, 1, 0]]), "stuck state has no moves")


func _test_generated_levels() -> void:
	var started := Time.get_ticks_msec()
	for level in range(1, 31):
		var bottles := LevelGenerator.generate(level)
		var colors := LevelGenerator.colors_for_level(level)
		_check(bottles == LevelGenerator.generate(level), "level %d is deterministic" % level)
		_check(bottles.size() == colors + LevelGenerator.EMPTY_BOTTLES, "level %d bottle count" % level)

		var counts := {}
		for bottle in bottles:
			for color in bottle:
				counts[color] = counts.get(color, 0) + 1
		_check(counts.size() == colors, "level %d uses %d colors" % [level, colors])
		for color in counts:
			_check(counts[color] == Puzzle.CAPACITY, "level %d color %d fills one bottle" % [level, color])

		var solution = Solver.solve(bottles)
		_check(solution != null, "level %d is solvable" % level)
		if solution != null:
			var state := Puzzle.copy(bottles)
			for move in solution:
				_check(Puzzle.can_pour(state, move.x, move.y), "level %d solution move is legal" % level)
				Puzzle.pour(state, move.x, move.y)
			_check(Puzzle.is_solved(state), "level %d solution solves it" % level)
	print("Generated and verified 30 levels in %d ms" % (Time.get_ticks_msec() - started))
