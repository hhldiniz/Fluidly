class_name Puzzle
## Rules of the color-sort puzzle.
##
## A puzzle state is an Array of bottles; each bottle is an Array of color ids
## ordered bottom -> top. Liquids never mix: a pour moves the contiguous band of
## the source's top color, as much of it as fits, onto an empty bottle or onto
## the same color.

const CAPACITY := 4

## Liquid colors, indexed by color id.
const COLORS: Array[Color] = [
	Color(0.902, 0.224, 0.275), # red
	Color(0.969, 0.498, 0.0), # orange
	Color(1.0, 0.839, 0.039), # yellow
	Color(0.655, 0.788, 0.341), # lime
	Color(0.176, 0.416, 0.31), # green
	Color(0.298, 0.788, 0.941), # cyan
	Color(0.227, 0.337, 0.831), # blue
	Color(0.482, 0.173, 0.749), # purple
	Color(1.0, 0.439, 0.651), # pink
	Color(0.553, 0.333, 0.141), # brown
	Color(0.678, 0.71, 0.741), # gray
	Color(0.973, 0.976, 0.98), # white
]


static func copy(state: Array) -> Array:
	var out := []
	for bottle in state:
		out.append(bottle.duplicate())
	return out


## Number of units of the top color sitting on top of each other.
static func top_run(bottle: Array) -> int:
	if bottle.is_empty():
		return 0
	var top = bottle.back()
	var run := 0
	for i in range(bottle.size() - 1, -1, -1):
		if bottle[i] != top:
			break
		run += 1
	return run


static func is_complete(bottle: Array) -> bool:
	return bottle.size() == CAPACITY and top_run(bottle) == CAPACITY


static func can_pour(state: Array, from: int, to: int) -> bool:
	if from == to:
		return false
	var src: Array = state[from]
	var dst: Array = state[to]
	if src.is_empty() or dst.size() >= CAPACITY:
		return false
	return dst.is_empty() or dst.back() == src.back()


## Pours from `from` into `to` (the move must be legal) and returns how many units moved.
static func pour(state: Array, from: int, to: int) -> int:
	var src: Array = state[from]
	var dst: Array = state[to]
	var amount := mini(top_run(src), CAPACITY - dst.size())
	for i in amount:
		dst.append(src.pop_back())
	return amount


## Reverts a pour made with pour().
static func unpour(state: Array, from: int, to: int, amount: int) -> void:
	for i in amount:
		state[from].append(state[to].pop_back())


## Solved when every bottle is either empty or full of a single color.
static func is_solved(state: Array) -> bool:
	for bottle in state:
		if not bottle.is_empty() and not is_complete(bottle):
			return false
	return true


static func has_any_move(state: Array) -> bool:
	for from in state.size():
		for to in state.size():
			if can_pour(state, from, to):
				return true
	return false


## Order-independent key of a state, used by the solver to skip visited states.
static func key(state: Array) -> String:
	var codes := PackedInt32Array()
	for bottle in state:
		var code := 0
		for color in bottle:
			code = code * 16 + color + 1
		codes.append(code)
	codes.sort()
	return str(codes)
