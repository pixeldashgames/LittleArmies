class_name GameController extends Node3D

class EnemyPositionKnowledge:
	var position: Vector2i
	var last_seen: int

	@warning_ignore("shadowed_variable")
	func _init():
		self.position = Vector2i(-1, -1)
		self.last_seen = -1

class Knowledge:
	var cells_visibility: Array
	var enemy_positions: Dictionary

	@warning_ignore("shadowed_variable")
	func _init(width: int, height: int, enemies: Array[Unit]):
		self.cells_visibility = []
		for i in height:
			self.cells_visibility.append([])
			for j in width:
				self.cells_visibility[i].append({})
		self.enemy_positions = {}
		for e in enemies:
			self.enemy_positions[e] = EnemyPositionKnowledge.new()
	
	func reset_visibility_map_for(source):
		for i in len(cells_visibility):
			for j in len(cells_visibility[i]):
				cells_visibility[i][j].erase(source)

	func get_visibility_at(pos: Vector2i):
		var visibility_values = cells_visibility[pos.y][pos.x].values()
		if len(visibility_values) == 0:
			return 0
		return visibility_values.max()

	func set_cell_visibility(source, cell: Vector2i, visibility: float):
		cells_visibility[cell.y][cell.x][source] = visibility

class Castle:
	var name: String
	var position: Vector2i
	var supplies: int
	var owner_team: int
	var claim_progress: float

	@warning_ignore("shadowed_variable")
	func _init(name: String, pos: Vector2i, owner: int, supplies: int):
		self.name = name
		self.position = pos
		self.owner_team = owner
		self.supplies = supplies
		self.claim_progress = 1 if owner >= 0 else 0

	func claim(by: Unit) -> CastleClaimResult:
		if owner_team == -1:
			if by.team == 0:
				claim_progress = clamp(claim_progress + 0.5, 0, 1)
			else:
				claim_progress = clamp(claim_progress - 0.5, 0, 1)
			if abs(claim_progress) == 1:
				claim_progress = 1
				owner_team = by.team
				return CastleClaimResult.CONQUERED
		elif owner_team != by.team:
			claim_progress = clamp(claim_progress - 0.5, 0, 1)
			if claim_progress == 0:
				owner_team = -1
				return CastleClaimResult.NEUTRALIZED
		return CastleClaimResult.IN_PROGRESS
	
	func to_dict() -> Dictionary:
		return {
			"position": position,
			"owner_team": owner_team,
			"name": name,
			"supplies": supplies
		}
			

enum CastleClaimResult {
	CONQUERED,
	NEUTRALIZED,
	IN_PROGRESS
}

enum GameOverResult {
	ATTACKERS_WON_BY_CONQUEST,
	ATTACKERS_WON_BY_ELIMINATION,
	DEFENDERS_WON_BY_ELIMINATION,
	NOT_OVER
}

const forest_speed_penalty: float = 1.5
const mountain_speed_penalty: float = 2.5
const water_speed_penalty: float = 1.5
const max_altitude_difference: float = 1.5
const max_altitude_difference_penalty_multiplier: float = 2.5
const altitude_penalty_curve: float = 2.4
const unit_separation: int = 5
const unit_float_height: float = 2

const plains_initial_visibility_multiplier: float = 1
const water_initial_visibility_multiplier: float = 1.1
const mountain_initial_visibility_multiplier: float = 2
const forest_initial_visibility_multiplier: float = 0.5

const plains_visibility_multiplier: float = 0.9
const water_visibility_multiplier: float = 0.95
const forest_visibility_multiplier: float = 0.3
const mountain_visibility_multiplier: float = 0.05
const max_altitude_difference_for_visibility: float = 2 
const altitude_decrease_visibility_multiplier_curve: float = 0.4
const altitude_increase_visibility_multiplier_curve: float = 0.2
const altitude_difference_multiplier_range := Vector2(0, 1.2)

const castle_vigilance_range: float = 5

@export var morale_starting_values: Array[float]
@export var count_starting_values: Array[int]
@export var supplies_starting_values: Array[int]
@export var castle_supplies_starting_values: Array[int]
@export var unit_names: Array[String]

@export var defender_scenes: Array[PackedScene]
@export var attacker_scenes: Array[PackedScene]

@export var highlight_scene: PackedScene
@export var unit_properties_scene: PackedScene
@export var castle_properties_scene: PackedScene
@export var teams_unit_counts: Array[int] = [5, 5]

@onready var game_map: GameMap = $GameMap
@onready var units_parent: Node3D = $Units
@onready var highlights_parent: Node3D = $Highlights
@onready var unit_properties_parent: Node3D = $UnitProperties
@onready var castle_properties_parent: Node3D = $CastleProperties
@onready var time_between_turns: Timer = $TimeBetweenTurns

@onready var camera:Camera3D = $Camera3D
@onready var hex_math = $HexMath
@onready var terrain_renderer = $TerrainRenderer
@onready var underground_renderer = $UndergroundRenderer
@onready var water_renderer = $WaterRenderer
@onready var forests_renderer = $ForestsRenderer
@onready var mountains_renderer = $MountainsRenderer

var units_array: Array[Unit] = []

var units_hightlights: Array = []
var unit_properties_objects: Array = []

var castle_properties_objects: Array = []

var teams_knowledge: Array[Knowledge] = []

var castles: Array[Castle] = []

func _ready():
	game_map.generate()
	_run_full_render()
	_generate_units()

	for team in range(len(teams_unit_counts)):
		teams_knowledge.append(\
			Knowledge.new(game_map.map_generator.width,\
				game_map.map_generator.height,\
				units_array.filter(func(u): return u.team != team)))

	for i in range(len(game_map.castles_array)):
		var pos = game_map.castles_array[i]
		# 65 = 'A'
		var castle_letter = char(65 + i)
		castles.append(Castle.new(castle_letter, pos, 0, castle_supplies_starting_values.pick_random()))

	_update_castles_visibility()

	for u in units_array:
		_update_knowledge(u)

	_update_units(0)
	_render_all_shadows(0)

	_game_loop()
	var mid_map = game_map.get_game_pos(game_map.get_size() / 2)
	mid_map.y = 10
	camera.position = mid_map

func _run_full_render():
	terrain_renderer.render(game_map)
	underground_renderer.render(game_map)
	water_renderer.render(game_map)
	forests_renderer.render(game_map)
	mountains_renderer.render(game_map)

func _render_all_shadows(team: int):
	var visibility_function: Callable
	if team == -1:
		visibility_function = func(pos: Vector2i): \
			return max(teams_knowledge[0].get_visibility_at(pos),\
				teams_knowledge[1].get_visibility_at(pos))
	else:
		visibility_function = teams_knowledge[team].get_visibility_at
	
	# var image = Image.create(len(teams_knowledge[team].cells_visibility[0]), len(teams_knowledge[team].cells_visibility), false, Image.FORMAT_RGBA8)

	# for y in range(image.get_height()):
	# 	for x in range(image.get_width()):
	# 		var color = Color(visibility_function.call(Vector2i(x, y)), 1 - visibility_function.call(Vector2i(x, y)), 0, 1.0)  # Random color
	# 		image.set_pixel(x, y, color)

	# var path = "user://generated_texture_" + str(randi() % 100) + ".png"
	# image.save_png(path)

	terrain_renderer.change_visibility(visibility_function)
	underground_renderer.change_visibility(visibility_function)
	water_renderer.change_visibility(visibility_function)
	forests_renderer.change_visibility(visibility_function)
	mountains_renderer.change_visibility(visibility_function)

func player_team() -> int:
	var player = units_array.filter(func(u): return u.agent is UserAgent)
	if len(player) == 0:
		return -1
	return player[0].team

func _game_loop():
	while _is_game_over() == GameOverResult.NOT_OVER:
		var units = units_array.duplicate()
		for unit in units:
			if not is_instance_valid(unit) or not units_array.has(unit):
				continue

			@warning_ignore("redundant_await")
			var move = await unit.agent.get_move()
			_perform_move(unit, move)

			if not unit.is_dead():
				var castle = castles.filter(func(c): return c.position == unit.current_position)

				var in_castle = len(castle) != 0

				unit.end_of_day(in_castle and castle[0].owner_team == unit.team)
				unit.decrease_supplies()

				unit.desert_units()
				if not unit.is_dead():
					if in_castle:
						var this_castle: Castle = castle[0]

						var result := this_castle.claim(unit)

						if result == CastleClaimResult.CONQUERED:
							unit.take_castle()
							Logger.log_take_castle(unit, this_castle)
						elif result == CastleClaimResult.NEUTRALIZED:
							unit.neutralized_castle()	
						
						if this_castle.owner_team == unit.team:
							this_castle.supplies -= unit.pickup_supplies(this_castle.supplies)

					_update_knowledge(unit)

			time_between_turns.start()
			_update_units(player_team())
			_update_castles()
			_render_all_shadows(player_team())

			if _is_game_over() != GameOverResult.NOT_OVER:
				break

			if not time_between_turns.is_stopped():
				await time_between_turns.timeout
	
	finish_game()

func finish_game():
	print("game over by" + str(_is_game_over()))

func get_cells_in_range(from: Vector2i, max_range: float):
	var cells_in_range = [from]
	var queue = [[from, max_range]]

	while len(queue) > 0:
		var current = queue.pop_front()

		if current[1] <= 0:
			continue

		var directions = game_map.get_directions(current[0])
		for dir in directions:
			var new_pos = current[0] + dir

			if not game_map.is_valid_pos(new_pos):
				continue

			if cells_in_range.has(new_pos):
				continue

			cells_in_range.append(new_pos)
			queue.append([new_pos, current[1] - 1])

	return cells_in_range	

func update_visibility_for_cell(source, from: Vector2i, c: Vector2i, cells_in_between: Array, this_height: float, team: int):
	if from == c:
		teams_knowledge[team].set_cell_visibility(source, from, 1)
		return

	var visibility
	if game_map.has_water_in(from):
		visibility = water_initial_visibility_multiplier
	elif game_map.has_forest_in(from):
		visibility = forest_initial_visibility_multiplier
	elif game_map.has_mountain_in(from):
		visibility = mountain_initial_visibility_multiplier
	else:
		visibility = plains_initial_visibility_multiplier

	# var cells_in_between = HexagonMath.get_cells_between(from, c)

	var height_change_point = this_height
	var increased_height = false
	var last_height = height_change_point
	for i in range(1, len(cells_in_between)):
		if not game_map.is_valid_pos(cells_in_between[i]):
			continue

		if game_map.has_water_in(cells_in_between[i]):
			visibility *= water_visibility_multiplier
		elif game_map.has_forest_in(cells_in_between[i]):
			visibility *= forest_visibility_multiplier
		elif game_map.has_mountain_in(cells_in_between[i]):
			visibility *= mountain_visibility_multiplier
		else:
			visibility *= plains_visibility_multiplier
		
		var height = game_map.get_height_at(cells_in_between[i])
		if height > last_height:
			increased_height = true
			if height > height_change_point:
				height_change_point = height
			last_height = height
		elif not increased_height:
			height_change_point = height
			last_height = height
		
	var curve = altitude_decrease_visibility_multiplier_curve if this_height > height_change_point else altitude_increase_visibility_multiplier_curve

	var value = clampf(abs(this_height - height_change_point) / max_altitude_difference_for_visibility, 0, 1)

	var unsigned_value = value if this_height > height_change_point else (1 - value)

	var altitude_vis_multiplier = ease(unsigned_value, curve)

	var range_min = 1.0 if this_height > height_change_point else altitude_difference_multiplier_range.x
	var range_max = altitude_difference_multiplier_range.y if this_height > height_change_point else 1.0

	visibility *= lerpf(range_min, range_max, altitude_vis_multiplier)

	teams_knowledge[team].set_cell_visibility(source, c, visibility)

func _update_visibility_for_source(source, from: Vector2i, height: float, team: int, vigilance_range: float):
	var cells_in_range = get_cells_in_range(from, vigilance_range)
	var in_between_for_each_cell = hex_math.GetAllCellsBetween(from, cells_in_range)

	for i in range(len(cells_in_range)):
		update_visibility_for_cell(source, from, cells_in_range[i], in_between_for_each_cell[i], height, team)

func _update_castles_visibility():
	for castle in castles:
		var height = game_map.get_height_at(castle.position)
		_update_visibility_for_source(castle, castle.position, height, 0, castle_vigilance_range)

func _update_knowledge(unit: Unit):
	teams_knowledge[unit.team].reset_visibility_map_for(unit)

	var vigilance_range = unit.get_vigilance_range()
	var height = game_map.get_height_at(unit.current_position)

	_update_visibility_for_source(unit, unit.current_position, height, unit.team, vigilance_range)

	_update_units_knowledge()

func _update_units_knowledge():
	for u in units_array:
		var pos = u.current_position
		var chance = u.get_visibility_chance() * teams_knowledge[1 - u.team].get_visibility_at(pos)
		var unit_knowledge = teams_knowledge[1 - u.team].enemy_positions[u]
		if chance > 0:
			if unit_knowledge.last_seen == 0:
				unit_knowledge.position = pos
			elif randf() <= chance:
				unit_knowledge.position = pos
				unit_knowledge.last_seen = 0
			elif unit_knowledge.last_seen != -1:
				unit_knowledge.last_seen += 1
		elif unit_knowledge.last_seen != -1:
			unit_knowledge.last_seen += 1
				
func _perform_move(unit: Unit, move: Agent.AgentMove):
	var enemy_positions = units_array.filter(func(u): return u.team != unit.team)\
							.reduce(func(accum, u):
								accum[u.current_position] = u
								return accum, {})

	for entry_move in move.entry_path:
		if entry_move in enemy_positions:
				# unexpected attack
				_perform_battle(unit, enemy_positions[entry_move], -1)
				return
		unit.current_position = entry_move

	if move.attacking_pos != null:
		_perform_battle(unit, enemy_positions[move.attacking_pos], 0)

func _perform_battle(unit_a: Unit, unit_b: Unit, advantage_unit: int):
	var unit_a_terrain = game_map.get_terrain_at(unit_a.current_position)
	var unit_b_terrain = game_map.get_terrain_at(unit_b.current_position)
	var unit_a_height = game_map.get_height_at(unit_a.current_position)
	var unit_b_height = game_map.get_height_at(unit_b.current_position)

	var unit_a_damage = unit_a.get_damage(unit_a_terrain, unit_b_terrain, unit_a_height, unit_b_height, advantage_unit == 0)
	var unit_b_damage = unit_b.get_damage(unit_b_terrain, unit_a_terrain, unit_b_height, unit_a_height, advantage_unit == 1)

	var a_deaths = unit_a.kill_units(ceili(unit_b_damage[0]))
	var a_injured = unit_a.injure_units(ceili(unit_b_damage[1]))
	var b_deaths = unit_b.kill_units(ceili(unit_a_damage[0]))
	var b_injured = unit_b.injure_units(ceili(unit_a_damage[1]))

	unit_b.damage_dealt_to_enemy(a_deaths, a_injured)
	unit_a.damage_dealt_to_enemy(b_deaths, b_injured)

	teams_knowledge[unit_a.team].enemy_positions[unit_b].last_seen = 0
	teams_knowledge[unit_b.team].enemy_positions[unit_a].last_seen = 0
	teams_knowledge[unit_a.team].enemy_positions[unit_b].position = unit_b.current_position
	teams_knowledge[unit_b.team].enemy_positions[unit_a].position = unit_a.current_position

	Logger.log_combat(unit_a, unit_b, b_deaths, b_injured, a_deaths, a_injured)

func destroy_unit(unit: Unit):
	units_array.erase(unit)
	for team in range(len(teams_knowledge)):
		if team == unit.team:
			teams_knowledge[team].reset_visibility_map_for(unit)
		else:
			teams_knowledge[team].enemy_positions.erase(unit)

	unit.queue_free()

func _is_game_over() -> GameOverResult:
	if len(units_array.filter(func(u): return u.team == 0)) == 0:
		return GameOverResult.ATTACKERS_WON_BY_ELIMINATION
	elif len(units_array.filter(func(u): return u.team == 1)) == 0:
		return GameOverResult.DEFENDERS_WON_BY_ELIMINATION
	elif len(castles.filter(func(c): return c.owner_team == 0)) == 0:
		return GameOverResult.ATTACKERS_WON_BY_CONQUEST
	else:
		return GameOverResult.NOT_OVER

func _generate_units():
	var max_units_per_row = 1 + game_map.get_playable_size().x / unit_separation
	
	for i in range(len(teams_unit_counts)):
		var unit_count = teams_unit_counts[i]
		var rows = ceili(float(unit_count) / max_units_per_row)
		
		for row in range(rows):
			var units_in_row = min(unit_count - row * max_units_per_row, max_units_per_row)
			_generate_units_row(i, units_in_row, row)

func _generate_units_row(team: int, count: int, row: int):
	var total_space_occupied = (count - 1) * unit_separation + count
	var start_x = game_map.extra_width + (game_map.get_playable_size().x - total_space_occupied) / 2
	var y = \
		game_map.extra_height + game_map.get_playable_size().y - 2 - row * 2 \
		if team == 0 \
		else game_map.extra_height + 1 + row * 2
	
	for i in range(count):
		var x = start_x + i * unit_separation + i
		_generate_unit_at(Vector2i(x, y), team)

func _generate_unit_at(pos: Vector2i, team: int):
	var array = defender_scenes if team == 0 else attacker_scenes
	var unit_scene = array.pick_random()
	array.erase(unit_scene)

	var unit = unit_scene.instantiate() as Unit

	units_parent.add_child(unit)
	if team == 0:
		unit.rotation_degrees.y = 180
	var unit_name = unit_names.pick_random()
	unit_names.erase(unit_name)
	unit.initialize(self, unit_name, pos, team, count_starting_values.pick_random(), \
		morale_starting_values.pick_random(), 0, supplies_starting_values.pick_random())
	units_array.append(unit)

func _update_castles():
	for prop in castle_properties_objects:
		prop.queue_free()
	castle_properties_objects.clear()

	for castle in castles:
		if castle.owner_team and castle.claim_progress != 1:
			# stop siege if no enemy is in the castle
			var enemy_in_castle = units_array.filter(func(u): return u.current_position == castle.position and u.team != castle.owner_team)
			if len(enemy_in_castle) == 0:
				castle.claim_progress = 1

		var pos = game_map.get_game_pos(castle.position)
		var castle_properties = castle_properties_scene.instantiate()
		castle_properties_parent.add_child(castle_properties)
		castle_properties.position = pos
		castle_properties.set_properties(castle)
		castle_properties_objects.append(castle_properties)

func _update_units(p_team: int):
	for highlight in units_hightlights:
		highlight.queue_free()
	units_hightlights.clear()

	for prop in unit_properties_objects:
		prop.queue_free()
	unit_properties_objects.clear()

	var units_queued_to_destroy = []

	for u in units_array:
		if u.is_dead():
			units_queued_to_destroy.append(u)

	for u in units_queued_to_destroy:
		destroy_unit(u)

	for unit in units_array:
		if p_team != -1 and unit.team != p_team:
			unit.visible = teams_knowledge[p_team].enemy_positions[unit].last_seen == 0
			if not unit.visible:
				continue

		var matrix_pos = unit.current_position

		var pos = game_map.get_game_pos(matrix_pos)

		var unit_pos = pos

		if game_map.has_forest_in(matrix_pos) \
			or game_map.has_mountain_in(matrix_pos) \
			or game_map.has_castle_in(matrix_pos) \
			or game_map.has_water_in(matrix_pos):
				unit_pos.y += unit_float_height

		unit.position = unit_pos

		var highlight = highlight_scene.instantiate()
		highlights_parent.add_child(highlight)
		highlight.position = pos
		units_hightlights.append(highlight)

		var unit_properties = unit_properties_scene.instantiate()
		unit_properties_parent.add_child(unit_properties)
		unit_properties.position = unit_pos
		unit_properties.set_properties(unit)
		unit_properties_objects.append(unit_properties)

func get_unit_at(from: Unit, pos: Vector2i) -> Array:
	for unit in units_array:
		if unit.current_position == pos:
			if unit.team != from.team:
				return [teams_knowledge[from.team].enemy_positions[unit].last_seen == 0, unit]
			return [true, unit]
	return [true, null]

func get_moves(unit: Unit, from: Vector2i) -> Array:
	var speed = unit.get_unit_speed()

	var initial_penalty := 0.0

	if game_map.has_forest_in(from):
		initial_penalty = forest_speed_penalty - 1
	elif game_map.has_mountain_in(from):
		initial_penalty = mountain_speed_penalty - 1
	elif game_map.has_water_in(from):
		initial_penalty = water_speed_penalty - 1
	else: # plains
		initial_penalty = 0
	
	speed -= initial_penalty

	if speed < mountain_speed_penalty:
		speed = mountain_speed_penalty

	# visited is point: [[path to point], speed]
	var visited: Dictionary = {from: [[from], speed]}
	# queue is [[[path_to_current], (Vector3)current_data]]
	var queue = [[[from], Vector3(from.x, from.y, speed)]]

	while len(queue) > 0:
		var element = queue.pop_front()
		var current = element[1]
		var path: Array = element[0]
		var pos = Vector2i(current.x, current.y)
		var remaining = current.z

		if remaining <= 0:
			continue

		var pos_altitude = game_map.get_height_at(pos)

		var directions = game_map.get_directions(pos)

		for dir in directions:
			var new_pos = pos + dir

			var this_altitude = game_map.get_height_at(new_pos)

			var altitude_difference = abs(this_altitude - pos_altitude)

			if altitude_difference > max_altitude_difference:
				continue

			var speed_penalty = 0

			if game_map.has_forest_in(new_pos):
				speed_penalty = forest_speed_penalty
			elif game_map.has_mountain_in(new_pos):
				speed_penalty = mountain_speed_penalty
			elif game_map.has_water_in(new_pos):
				speed_penalty = water_speed_penalty
			else: # plains
				speed_penalty = 1
			
			speed_penalty *= 1 + (max_altitude_difference_penalty_multiplier - 1) \
				* ease(altitude_difference / max_altitude_difference, altitude_penalty_curve)
			
			var new_remaining = remaining - speed_penalty

			if new_remaining < 0:
				continue

			if visited.has(new_pos) and visited[new_pos][1] >= new_remaining:
				continue
			
			var new_path = path + [new_pos]

			var unit_at = get_unit_at(unit, new_pos)
			if unit_at[0] and unit_at[1] != null and unit_at[1] != unit:
				if unit_at[1].team != unit.team:
					visited[new_pos] = [new_path, remaining]
				continue
			
			visited[new_pos] = [new_path, new_remaining]
			queue.append([new_path, Vector3(new_pos.x, new_pos.y, new_remaining)])

	var result = []
	for key in visited.keys():
		result.append([key, visited[key][0]])

	return result
