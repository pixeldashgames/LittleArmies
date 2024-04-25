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
	var map_width
	var map_height

	@warning_ignore("shadowed_variable")
	func _init(width: int, height: int, enemies: Array[Unit]):
		map_width = width
		map_height = height
		self.cells_visibility = []
		self.cells_visibility.resize(height)
		for i in height:
			self.cells_visibility[i] = []
			self.cells_visibility[i].resize(width)
			for j in width:
				self.cells_visibility[i][j] = 0
		self.enemy_positions = {}
		for e in enemies:
			self.enemy_positions[e] = EnemyPositionKnowledge.new()
	
	func reset_visibility_map():
		for i in map_height:
			for j in map_width:
				self.cells_visibility[i][j] = 0
		

const forest_speed_penalty: float = 1.5
const mountain_speed_penalty: float = 2.5
const water_speed_penalty: float = 2
const max_altitude_difference: float = 1.5
const max_altitude_difference_penalty_multiplier: float = 2.5
const altitude_penalty_curve: float = 2.4
const unit_separation: int = 5
const unit_float_height: float = 2

const plains_visibility_multiplier: float = 0.9
const water_visibility_multiplier: float = 0.95
const forest_visibility_multiplier: float = 0.3
const mountain_visibility_multiplier: float = 0.05
const max_altitude_difference_for_visibility: float = 2 
const altitude_decrease_visibility_multiplier_curve: float = 0.4
const altitude_increase_visibility_multiplier_curve: float = 0.2
const altitude_difference_multiplier_range := Vector2(0, 1.2)

const castle_vigilance_range: float = 7 

@export var morale_starting_values: Array[float]
@export var count_starting_values: Array[int]
@export var medicine_starting_values: Array[int]
@export var food_starting_values: Array[int]

@export var unit_scene: PackedScene
@export var player_scene: PackedScene
@export var highlight_scene: PackedScene
@export var teams_unit_counts: Array[int] = [5, 5]

@onready var game_map: GameMap = $GameMap
@onready var units_parent: Node3D = $Units
@onready var highlights_parent: Node3D = $Highlights
@onready var time_between_turns: Timer = $TimeBetweenTurns

@onready var camera:Camera3D = $Camera3D
@onready var terrain_renderer = $TerrainRenderer
@onready var underground_renderer = $UndergroundRenderer
@onready var water_renderer = $WaterRenderer
@onready var forests_renderer = $ForestsRenderer
@onready var mountains_renderer = $MountainsRenderer

var units_array: Array[Unit] = []

var units_hightlights: Array = []

var teams_knowledge: Array[Knowledge] = []

func _ready():
	game_map.generate()
	terrain_renderer.render(game_map)
	underground_renderer.render(game_map)
	water_renderer.render(game_map)
	forests_renderer.render(game_map)
	mountains_renderer.render(game_map)

	_generate_units()
	_update_unit_positions()
	_game_loop()
	var mid_map = game_map.get_game_pos(game_map.get_size() / 2)
	mid_map.y = 10
	camera.position = mid_map

func _game_loop():
	while not _is_game_over():
		for unit in units_array:
			@warning_ignore("redundant_await")
			var move = await unit.agent.get_move()
			_perform_move(unit, move)
			_update_unit_positions()
			_update_knowledge()
			time_between_turns.start()
			await time_between_turns.timeout

func _update_visibility_map(team: int, from: Vector2i, max_range: float):
	var cells_in_range = [from]
	var queue = [[from, max_range]]

	while len(queue) > 0:
		var current = queue.pop_front()

		if current[1] <= 0:
			continue

		var directions = game_map.get_directions(current[0])
		for dir in directions:
			var new_pos = current[0] + dir

			if cells_in_range.has(new_pos):
				continue

			cells_in_range.append(new_pos)
			queue.append([new_pos, current[1] - 1])
	
	for c in cells_in_range:
		var cells_in_between = HexagonMath.get_cells_between(from, c)
		var visibility = 1
		var this_height = game_map.get_height_at(from)
		var height_change_point = this_height
		var increased_height = false
		var last_height = height_change_point
		for i in range(1, len(cells_in_between)):
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
			elif not increased_height:
				height_change_point = height

		var curve = altitude_decrease_visibility_multiplier_curve if this_height > height_change_point else altitude_increase_visibility_multiplier_curve

		var value = clampf(abs(this_height - height_change_point) / max_altitude_difference_for_visibility, 0, 1)

		var unsigned_value = value if this_height > height_change_point else value

		var altitude_vis_multiplier = ease(unsigned_value, curve)

		var range_min = 1.0 if this_height > height_change_point else altitude_difference_multiplier_range.x
		var range_max = altitude_difference_multiplier_range.y if this_height > height_change_point else 1.0

		visibility *= lerpf(range_min, range_max, altitude_vis_multiplier)

		var current_visibility = teams_knowledge[team].cells_visibility[c.y][c.x] 
		if visibility > current_visibility:
			teams_knowledge[team].cells_visibility[c.y][c.x] = visibility

func _update_knowledge():
	for team in range(teams_unit_counts.size()):
		teams_knowledge[team].reset_visibility_map()

		# updating visibility
		for unit in units_array.filter(func(u): return u.team == team):
			var vigilance_range = unit.get_vigilance_range()
			_update_visibility_map(team, unit.current_position, vigilance_range)
		
		if team == 0:
			for castle in game_map.castles_array:
				_update_visibility_map(team, castle, castle_vigilance_range)
		
		var visibility_map = teams_knowledge[team].cells_visibility

		for enemy in units_array.filter(func(u): return u.team != team):
			var pos = enemy.current_position
			var chance = enemy.get_visibility_chance() * visibility_map[pos.y][pos.x]
			var enemy_knowledge = teams_knowledge[team].enemy_positions[enemy]
			if chance > 0:
				if enemy_knowledge.last_seen == 0:
					enemy_knowledge.position = pos
				elif randf() <= chance:
					enemy_knowledge.position = pos
					enemy_knowledge.last_seen = 0
				elif enemy_knowledge.last_seen != -1:
					enemy_knowledge.last_seen += 1
			elif enemy_knowledge.last_seen != -1:
				enemy_knowledge.last_seen += 1
				
func _perform_move(unit: Unit, move: Agent.AgentMove):
	unit.current_position = move.target_pos

func _perform_battle(unit_a: Unit, unit_b: Unit, advantage_unit: int):
	pass

func _is_game_over() -> bool:
	return false

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
		_generate_unit_at(Vector2i(x, y), team, row == 0 and i == (count + 1) / 2 and team == 0)

func _generate_unit_at(pos: Vector2i, team: int, is_player: bool):
	var unit = unit_scene.instantiate() as Unit \
				if not is_player \
				else player_scene.instantiate() as Unit

	units_parent.add_child(unit)
	if team == 0:
		unit.rotation_degrees.y = 180
	unit.initialize(self, pos, team, count_starting_values.pick_random(), \
		morale_starting_values.pick_random(), 0, food_starting_values.pick_random(), \
		medicine_starting_values.pick_random())
	units_array.append(unit)

func _update_unit_positions():
	for highlight in units_hightlights:
		highlight.queue_free()
	units_hightlights.clear()

	for unit in units_array:
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

func get_unit_at(pos: Vector2i) -> Unit:
	for unit in units_array:
		if unit.current_position == pos:
			return unit
	return null

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

	var visited: Dictionary = {from: speed}
	var queue = [Vector3(from.x, from.y, speed)]

	while len(queue) > 0:
		var current = queue.pop_front()
		var pos = Vector2i(current.x, current.y)
		var remaining = current.z

		if remaining == 0:
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
			
			if visited.has(new_pos) and visited[new_pos] >= new_remaining:
				continue
			
			visited[new_pos] = new_remaining
			queue.append(Vector3(new_pos.x, new_pos.y, new_remaining))

	return visited.keys()
