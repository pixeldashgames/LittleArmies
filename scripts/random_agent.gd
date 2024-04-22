class_name RandomAgent extends Agent

func get_move() -> AgentMove:
    var moves = controller.get_moves(unit, unit.current_position)

    var random_move = moves.pick_random()

    var target_unit = controller.get_unit_at(random_move)

    if target_unit != null and target_unit != unit:
        var adjacent = _get_random_adjacent_move(moves, random_move)
        if target_unit.team == unit.team:
            return AgentMove.new(adjacent, null)
        else:
            return AgentMove.new(adjacent, random_move)

    return AgentMove.new(random_move, null)        

func _get_random_adjacent_move(moves, target):
    var adjacent_moves = []

    var directions = controller.game_map.get_directions(target)

    for dir in directions:
        if (target + dir) in moves:
            adjacent_moves.append(target + dir)

    return adjacent_moves.pick_random()