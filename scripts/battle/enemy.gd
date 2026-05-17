class_name Enemy extends Actor

var data: EnemyData
var next_move: EnemyMove
var move_history: Array[EnemyMove] = []


func setup_from_data(p_data: EnemyData, rng: RandomNumberGenerator) -> void:
	data = p_data
	var hp_value: int = rng.randi_range(p_data.hp_min, p_data.hp_max)
	setup(hp_value)


func roll_next_move(rng: RandomNumberGenerator) -> EnemyMove:
	var candidates: Array[EnemyMove] = []
	for m in data.move_set:
		if _can_use(m):
			candidates.append(m)
	if candidates.is_empty():
		candidates = data.move_set.duplicate()

	# Weighted random selection
	var total: float = 0.0
	for m in candidates:
		total += m.weight
	var pick: float = rng.randf() * total
	var cum: float = 0.0
	for m in candidates:
		cum += m.weight
		if pick <= cum:
			next_move = m
			return m
	next_move = candidates[0]
	return next_move


func _can_use(move: EnemyMove) -> bool:
	if move.max_uses_in_a_row < 0:
		return true
	var count: int = 0
	for i in range(move_history.size() - 1, -1, -1):
		if move_history[i].id == move.id:
			count += 1
		else:
			break
	return count < move.max_uses_in_a_row
