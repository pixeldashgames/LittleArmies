class_name SmartAgentInterface extends Agent

class ReceiveOrderResult:
    var success: bool
    var error_message: String

    @warning_ignore("shadowed_variable")
    func _init(success: bool, error_message: String):
        self.success = success
        self.error_message = error_message

@onready var csharp_agent = $AgentInterface

func get_move():
    var params = get_csharp_params()

    var move = csharp_agent.GetMove(params[0], params[1], params[2], \
        func(p): return controller.get_moves(unit, p), \
        func(p): return controller.game_map.get_directions(p)\
            .map(func(d): return p + d),
        func(p): return int(controller.game_map.get_terrain_at(p)))
    
    if move[2] as bool:
        return AgentMove.new(move[0][-1] as Vector2i, move[0] as Array, move[1] as Vector2i)
    else:
        return AgentMove.new(move[0][-1] as Vector2i, move[0] as Array)
    
func get_csharp_params() -> Array:
    var this_unit = unit.to_dict(controller)
    var other_units = controller.units_array.filter(func(u): 
        if u == unit:
            return false
        
        if u.team == unit.team:
            return true
        
        var last_seen = controller.teams_knowledge[unit.team].enemy_positions[u].last_seen

        # was seen less than two cycles ago
        return last_seen < len(controller.units_array) * 2)\
        .map(func (u):
            var dict = u.to_dict(controller)
            if u.team != unit.team:
                dict["current_position"] = controller.teams_knowledge[unit.team].enemy_positions[u].position
            return dict)
    var castles = controller.castles.map(func(c): return c.to_dict())

    return [this_unit, other_units, castles]

func receive_order(order: String) -> ReceiveOrderResult:
    var params = get_csharp_params()

    csharp_agent.ReceiveOrder(order, params[0], params[1], params[2]);

    var result: Array = await csharp_agent.OnPromptReceived

    return ReceiveOrderResult.new(result[0], result[1])

func get_desire():
    return csharp_agent.GetDesire();