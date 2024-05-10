class_name UserAgent extends Agent

enum SelectorState {
	SELECTING_MOVE,
	SELECTING_APPROACH,
	IDLE
}

signal move_selected

@export var move_selector_scene: PackedScene

var _selected_pos
var _selected_attack

var _selectors: Array = []

var _current_selector_state: SelectorState = SelectorState.IDLE

var _hovered_selector: MoveSelector = null

var _giving_order = false

var _possible_moves

var order_instance: OrderInterface

func _ready():
	order_instance = OrderInterface.instance
	order_instance.prompt_entered.connect(on_order_entered)
	order_instance.give_order_button_pressed.connect(on_give_order_button_pressed)
	order_instance.cancel_button_pressed.connect(on_cancel_button_pressed)

func _process(_delta):
	if not controller:
		return
	controller.camera.can_move = not _giving_order

func on_give_order_button_pressed():
	_giving_order = true
	order_instance.hide_button()
	var allied_targets = controller.units_array \
		.filter(func(u): return u.agent is SmartAgentInterface and u.team == unit.team) \
		.map(func(u): return u.unit_name)
	order_instance.open_prompter(allied_targets)

func on_cancel_button_pressed():
	_giving_order = false
	order_instance.show_button()
	order_instance.reset_prompt()

func on_order_entered(target: String, prompt: String):
	var target_unit = controller.units_array.filter(func(u): return u.unit_name == target)[0]
	var target_agent = target_unit.agent as SmartAgentInterface
	var result := await target_agent.receive_order(prompt)
	if not result.success:
		order_instance.prompt_error(result.error_message)
	else:
		order_instance.reset_prompt()
		_giving_order = false

func get_move() -> AgentMove:
	var moves = controller.get_moves(unit, unit.current_position)
	_possible_moves = moves.map(func(p): return p[0])

	build_selectors(_possible_moves)

	_current_selector_state = SelectorState.SELECTING_MOVE

	if not order_instance:
		order_instance = OrderInterface.instance

	order_instance.show_button()

	var starting_selector = get_selector_on_mouse(get_viewport().get_mouse_position())
	if starting_selector != null:
		_hovered_selector = starting_selector
		starting_selector.hover()
	else:
		_hovered_selector = null

	await move_selected

	var entry_path = moves.filter(func(m): return m[0] == _selected_pos)[0][1]
 
	order_instance.hide_button()

	return AgentMove.new(_selected_pos, entry_path, _selected_attack)

func destroy_selectors():
	for move in _selectors:
		move.queue_free()
	_selectors.clear()

func build_selectors(moves: Array):
	destroy_selectors()

	for move in moves:
		var unit_at = controller.get_unit_at(unit, move)
		if unit_at[0] and unit_at[1] != null and unit_at[1] != unit and unit_at[1].team == unit.team:
			continue

		var selector: MoveSelector = move_selector_scene.instantiate() as MoveSelector
		selector.initialize(move, unit_at[0] and unit_at[1] != null and unit_at[1] != unit)

		add_child(selector)

		selector.global_position = controller.game_map.get_game_pos(move)
		_selectors.append(selector)

func build_approach_selectors():
	var directions = controller.game_map.get_directions(_selected_attack)
	var moves = []

	for dir in directions:
		var pos = _selected_attack + dir
		if pos in _possible_moves:
			var unit_at = controller.get_unit_at(unit, pos)
			if not unit_at[0] or unit_at[1] in [null, unit]:
				moves.append(pos)

	build_selectors(moves)

	var starting_selector = get_selector_on_mouse(get_viewport().get_mouse_position())

	if starting_selector != null:
		_hovered_selector = starting_selector
		starting_selector.hover()
	else:
		_hovered_selector = null

func get_selector_on_mouse(mouse_pos) -> MoveSelector:
	var from = get_viewport().get_camera_3d().project_ray_origin(mouse_pos)
	var to = from + get_viewport().get_camera_3d().project_ray_normal(mouse_pos) * 1000
	var space_state = get_world_3d().direct_space_state
	var params = PhysicsRayQueryParameters3D.create(from, to)
	var result = space_state.intersect_ray(params)

	if not result:
		return null
	
	var collider = result.collider

	if not (collider is MoveSelector):
		return null
	
	var selector = collider as MoveSelector
	return selector

func _input(event):
	if _current_selector_state == SelectorState.IDLE or _giving_order:
		return

	if event is InputEventMouseMotion:
		var selector = get_selector_on_mouse(event.position)
		if selector != _hovered_selector:
			if _hovered_selector != null:
				_hovered_selector.unhover()
			
			if selector != null:
				selector.hover()
			
			_hovered_selector = selector

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if _hovered_selector != null:
				_hovered_selector.click()
		else:
			if _hovered_selector != null:
				if _current_selector_state == SelectorState.SELECTING_MOVE:
					if _hovered_selector.is_attack:
						_selected_attack = _hovered_selector.pos
						_current_selector_state = SelectorState.SELECTING_APPROACH
						build_approach_selectors()
					else:
						_selected_pos = _hovered_selector.pos
						_selected_attack = null
						_current_selector_state = SelectorState.IDLE
						destroy_selectors()
						move_selected.emit()
				elif _current_selector_state == SelectorState.SELECTING_APPROACH:
					_selected_pos = _hovered_selector.pos
					_current_selector_state = SelectorState.IDLE
					destroy_selectors()
					move_selected.emit()
