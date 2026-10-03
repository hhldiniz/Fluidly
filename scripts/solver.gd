class_name Solver
## Depth-first search for a sequence of pours that solves a puzzle.
## Used to guarantee generated levels are solvable and to provide hints.


## Returns an Array of Vector2i(from, to) moves that solves `state`, or null if
## no solution was found within `max_states` explored states.
static func solve(state: Array, max_states := 30000) -> Variant:
	var work := Puzzle.copy(state)
	var path: Array[Vector2i] = []
	var budget := [max_states]
	if _search(work, {}, path, budget):
		return path
	return null


static func _search(state: Array, visited: Dictionary, path: Array[Vector2i], budget: Array) -> bool:
	if Puzzle.is_solved(state):
		return true
	if budget[0] <= 0:
		return false
	var k := Puzzle.key(state)
	if visited.has(k):
		return false
	visited[k] = true
	budget[0] -= 1
	for move in _candidate_moves(state):
		var amount := Puzzle.pour(state, move.x, move.y)
		path.append(move)
		if _search(state, visited, path, budget):
			return true
		path.pop_back()
		Puzzle.unpour(state, move.x, move.y, amount)
	return false


## Legal moves, most promising first, skipping moves that can never help.
static func _candidate_moves(state: Array) -> Array[Vector2i]:
	var whole: Array[Vector2i] = [] # whole color band moves onto the same color
	var partial: Array[Vector2i] = [] # only part of the band fits
	var to_empty: Array[Vector2i] = []
	for from in state.size():
		var src: Array = state[from]
		if src.is_empty() or Puzzle.is_complete(src):
			continue
		var run := Puzzle.top_run(src)
		var tried_empty := false
		for to in state.size():
			if not Puzzle.can_pour(state, from, to):
				continue
			var dst: Array = state[to]
			if dst.is_empty():
				# Moving a single-color bottle into an empty one changes nothing, and
				# all empty bottles are equivalent, so try only the first.
				if run == src.size() or tried_empty:
					continue
				tried_empty = true
				to_empty.append(Vector2i(from, to))
			elif run <= Puzzle.CAPACITY - dst.size():
				whole.append(Vector2i(from, to))
			else:
				partial.append(Vector2i(from, to))
	return whole + to_empty + partial
