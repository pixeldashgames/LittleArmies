class_name RandomAgent extends Agent

func get_move() -> AgentMove:
	var possible_moves = controller.get_moves(unit, unit.current_position)
	var moves = possible_moves.map(func(m): return m[0])

	var random_move = moves.pick_random()

	var target_unit = controller.get_unit_at(unit, random_move)

	if target_unit[0] and target_unit[1] != null and target_unit[1] != unit:
		var adjacent = _get_random_adjacent_move(moves, random_move)
		var entry_path = possible_moves.filter(func(m): return m[0] == adjacent)[0][1]
		if target_unit.team == unit.team:
			return AgentMove.new(adjacent, entry_path, null)
		else:
			return AgentMove.new(adjacent, entry_path, random_move)

	var entry = possible_moves.filter(func(m): return m[0] == random_move)[0][1]

	return AgentMove.new(random_move, entry, null)        

func _get_random_adjacent_move(moves, target):
	var adjacent_moves = []

	var directions = controller.game_map.get_directions(target)

	for dir in directions:
		if (target + dir) in moves:
			adjacent_moves.append(target + dir)

	return adjacent_moves.pick_random()
