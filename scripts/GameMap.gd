class_name GameMap extends Node3D

class MapEntity:
	var mesh: Mesh
	var position: Vector3

	@warning_ignore("shadowed_variable")
	func _init(mesh: Mesh, position: Vector3):
		self.mesh = mesh
		self.position = position

@export var castles_count: int = 3

@export var height_scale: float = 1.0
@export var height_offset: float = 0.0

@export var forest_threshold: float = 0.5

@export var map_size: Vector2i

@export var mountains_compound_threshold: float = 1
@export var mountains_randomness_scale: float = 1

@export var castle_threshold: float = 0.5
@export var castle_threshold_decrease_step: float = 0.1
@export var castles_randomness_scale: float = 1

@export var block_scene: PackedScene
@export var water_scene: PackedScene
@export var underground_scene: PackedScene

@export var forest_scene: PackedScene
@export var castle_scene: PackedScene
@export var mountain_scene: PackedScene

@export var extra_width: int = 20
@export var extra_height: int = 30

@onready var map_generator = $PerlinMapGenerator
@onready var map_parent = $MapParent
@onready var forests_parent = $ForestsParent
@onready var mountains_parent = $MountainsParent
@onready var castles_parent = $CastlesParent

var height_map: Array
var forest_map: Array
var mountain_map: Array
var castle_map: Array
var water_proximity_map: Array
var structure_proximity_map: Array

var terrain_array: Array
var water_array: Array
var forests_array: Array
var mountains_array: Array
var castles_array: Array

var water_blocks: Array[Vector2i] = []

func _ready():
	map_generator.width = map_size.x + 2 * extra_width
	map_generator.height = map_size.y + 2 * extra_height
 
func get_game_pos(matrix_pos: Vector2i):
	var x_pos = matrix_pos.x * 2 + matrix_pos.y % 2;
	var z_pos = matrix_pos.y * sqrt(3)
	return Vector3(x_pos, get_height_at(matrix_pos), z_pos)

func get_size() -> Vector2i: return Vector2i(map_generator.width, map_generator.height)

func get_playable_size() -> Vector2i: return map_size

func get_directions(from: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var from_row = from.y

	var up_left = Vector2i( - 1, -1) if from_row % 2 == 0 else Vector2i(0, -1)
	if not _pos_in_outer_area(from + up_left):
		result.append(up_left)

	var up_right = Vector2i(0, -1) if from_row % 2 == 0 else Vector2i(1, -1)
	if not _pos_in_outer_area(from + up_right):
		result.append(up_right)

	var left = Vector2i( - 1, 0)
	if not _pos_in_outer_area(from + left):
		result.append(left)

	var right = Vector2i(1, 0)
	if not _pos_in_outer_area(from + right):
		result.append(right)

	var down_left = Vector2i( - 1, 1) if from_row % 2 == 0 else Vector2i(0, 1)
	if not _pos_in_outer_area(from + down_left):
		result.append(down_left)

	var down_right = Vector2i(0, 1) if from_row % 2 == 0 else Vector2i(1, 1)
	if not _pos_in_outer_area(from + down_right):
		result.append(down_right)

	return result

func get_map_directions(from: Vector2i):
	var result: Array[Vector2i] = []
	var from_row = from.y

	var up_left = Vector2i( - 1, -1) if from_row % 2 == 0 else Vector2i(0, -1)
	if is_valid_pos(from + up_left):
		result.append(up_left)

	var up_right = Vector2i(0, -1) if from_row % 2 == 0 else Vector2i(1, -1)
	if is_valid_pos(from + up_right):
		result.append(up_right)

	var left = Vector2i( - 1, 0)
	if is_valid_pos(from + left):
		result.append(left)

	var right = Vector2i(1, 0)
	if is_valid_pos(from + right):
		result.append(right)

	var down_left = Vector2i( - 1, 1) if from_row % 2 == 0 else Vector2i(0, 1)
	if is_valid_pos(from + down_left):
		result.append(down_left)

	var down_right = Vector2i(0, 1) if from_row % 2 == 0 else Vector2i(1, 1)
	if is_valid_pos(from + down_right):
		result.append(down_right)

	return result

func is_valid_pos(pos: Vector2i) -> bool:
	return pos.y >= 0 and pos.y < map_generator.height and \
		pos.x >= 0 and pos.x < map_generator.width

func has_water_in(pos: Vector2i) -> bool:
	return height_map[pos.y][pos.x] + height_offset < 0

func has_mountain_in(pos: Vector2i) -> bool:
	return mountains_array[pos.y][pos.x] != null

func has_castle_in(pos: Vector2i) -> bool:
	return castles_array[pos.y][pos.x] != null

func has_forest_in(pos: Vector2i) -> bool:
	return forests_array[pos.y][pos.x] != null

func get_height_at(pos: Vector2i) -> float:
	return (height_map[pos.y][pos.x] + height_offset) * height_scale + 1 \
		if not has_water_in(pos) else 1

func generate():
	_generate_heights()
	_generate_forests()
	_generate_mountains()
	_generate_points_of_interest()

func _update_structure_proximity_map(structure_i, structure_j):
	structure_proximity_map[structure_i][structure_j] = 1

	var max_distance := floori(float(map_generator.width) / castles_count / 2)

	# Value of each element in the queue is '(column, row, distance_from_structure)'
	var queue: Array[Vector3i] = [Vector3i(structure_j, structure_i, 0)]

	while len(queue) > 0:
		var block = queue.pop_front()

		var b_distance = block.z

		if max_distance - b_distance == 0:
			break

		var b_pos = Vector2i(block.x, block.y)

		var directions = get_map_directions(b_pos)

		for dir in directions:
			var pos = b_pos + dir
			var i = pos.y
			var j = pos.x

			# 0.3 curve is a medium-hard ease-out
			var proximity = ease(float(max_distance - b_distance + 1) / max_distance, 0.3)

			if structure_proximity_map[i][j] >= proximity:
				continue
			
			structure_proximity_map[i][j] = proximity

			queue.push_back(Vector3i(j, i, b_distance + 1))

func _generate_noise_map():
	var noise_map: Array = []
	noise_map.resize(map_generator.height)
	for i in range(map_generator.height):
		noise_map[i] = []
		noise_map[i].resize(map_generator.width)
		for j in range(map_generator.width):
			noise_map[i][j] = randf_range( - 1, 1)
	return noise_map

func _generate_castle(castle_positions, threshold):
	for pos in castle_positions:
		var i = int(pos.y)
		var j = int(pos.x)
		var castle_likelyhood = pos.z

		if castle_likelyhood < threshold \
			or has_water_in(Vector2i(pos.x, pos.y)) or castles_array[i][j] != null:
			continue
		
		var x_pos = j * 2 + i % 2;
		var z_pos = i * sqrt(3)
		var y_pos = (height_map[i][j] + height_offset) * height_scale + 1

		var block = castle_scene.instantiate()

		castles_parent.add_child(block);
		block.position = Vector3(x_pos, y_pos, z_pos)

		if forests_array[i][j] >= 0:
			# forests_array[i][j].free()
			forests_array[i][j] = -1
		elif mountains_array[i][j] >= 0:
			# mountains_array[i][j].free()
			mountains_array[i][j] = -1

		castles_array[i][j] = block
		_update_structure_proximity_map(i, j)
		return true
	return false

func _generate_points_of_interest():
	structure_proximity_map = []
	structure_proximity_map.resize(map_generator.height)
	for i in range(map_generator.height):
		structure_proximity_map[i] = []
		structure_proximity_map[i].resize(map_generator.width)
		for j in range(map_generator.width):
			structure_proximity_map[i][j] = 0

	castle_map = _generate_noise_map()
	castles_array = []
	castles_array.resize(map_generator.height)

	var placed_castles = 0

	var threshold = castle_threshold
	
	var map_width = map_generator.width - 2 * extra_width
	var map_height = map_generator.height - 2 * extra_height

	while placed_castles < castles_count:
		if threshold <= - 1:
			print_debug("Could not place the required amount of castles, placed ", placed_castles)
			break
		
		var castle_positions: Array[Vector3] = []

		for i in range(map_generator.height):
			castles_array[i] = []
			castles_array[i].resize(map_generator.width)
			
			# only _generate castles in the lower quarter of the playable map
			if i < extra_height + 2 * map_height / 3 or i >= extra_height + map_height:
				continue

			for j in range(map_generator.width):
				if j < extra_width or j >= extra_width + map_width:
					continue

				var castle_likelyhood = castle_map[i][j] * castles_randomness_scale \
					+ water_proximity_map[i][j] - structure_proximity_map[i][j]
				castle_positions.append(Vector3(j, i, castle_likelyhood))

		castle_positions.sort_custom(func(a, b): return a.z > b.z)

		if _generate_castle(castle_positions, threshold):
			placed_castles += 1
		else:
			threshold -= castle_threshold_decrease_step

func _compute_water_proximity_map():
	water_proximity_map = []
	water_proximity_map.resize(map_generator.height)

	for i in range(map_generator.height):
		water_proximity_map[i] = []
		water_proximity_map[i].resize(map_generator.width)

	if len(water_blocks) == 0:
		for i in range(map_generator.height):
			for j in range(map_generator.width):
				water_proximity_map[i][j] = 0
		return

	var queue: Array[Vector2i] = []

	for w in water_blocks:
		water_proximity_map[w.y][w.x] = 0
		queue.push_back(w)

	var max_distance := 0

	while len(queue) > 0:
		var block = queue.pop_front()

		var b_pos = Vector2i(block.x, block.y)
		
		var directions = get_map_directions(b_pos)

		for dir in directions:
			var pos = b_pos + dir
			var i = pos.y
			var j = pos.x

			if water_proximity_map[i][j] != null:
				continue
			
			var water_distance = water_proximity_map[b_pos.y][b_pos.x] + 1

			water_proximity_map[i][j] = water_distance

			if water_distance > max_distance:
				max_distance = water_distance

			queue.push_back(Vector2i(j, i))

	for i in range(map_generator.height):
		for j in range(map_generator.width):
			if max_distance == 0:
				water_proximity_map[i][j] = 1
				continue

			var distance = water_proximity_map[i][j]
			
			water_proximity_map[i][j] = float(max_distance - distance) / max_distance

func _generate_forests():
	forest_map = map_generator.GeneratePerlinMap()
	forests_array = []
	forests_array.resize(map_generator.height)

	for i in range(map_generator.height):
		forests_array[i] = []
		forests_array[i].resize(map_generator.width)

		for j in range(map_generator.width):
			forests_array[i][j] = -1

			if forest_map[i][j] + water_proximity_map[i][j] < forest_threshold \
				or has_water_in(Vector2i(j, i)):
				continue
			
			# var x_pos = j * 2 + i % 2;
			# var z_pos = i * sqrt(3)
			var y_pos = (height_map[i][j] + height_offset) * height_scale + 1

			# var block = forest_scene.instantiate()

			# forests_parent.add_child(block);
			# block.position = Vector3(x_pos, y_pos, z_pos)

			forests_array[i][j] = y_pos

func _generate_mountains():
	mountain_map = map_generator.GeneratePerlinMap()
	mountains_array = []
	mountains_array.resize(map_generator.height)

	for i in range(map_generator.height):
		mountains_array[i] = []
		mountains_array[i].resize(map_generator.width)
		
		for j in range(map_generator.width):
			mountains_array[i][j] = -1

			if mountain_map[i][j] * mountains_randomness_scale \
				 + height_map[i][j] < mountains_compound_threshold \
				or has_water_in(Vector2i(j, i)):
				continue
			
			# var x_pos = j * 2 + i % 2;
			# var z_pos = i * sqrt(3)
			var y_pos = (height_map[i][j] + height_offset) * height_scale + 1

			# var block = mountain_scene.instantiate()

			# mountains_parent.add_child(block);
			# block.position = Vector3(x_pos, y_pos, z_pos)

			if forests_array[i][j] >= 0:
				# forests_array[i][j].free()
				forests_array[i][j] = -1

			mountains_array[i][j] = y_pos

func _pos_in_outer_area(pos: Vector2i) -> bool:
	return _in_outer_area(pos.y, pos.x)

func _in_outer_area(i: int, j: int) -> bool:
	return i < extra_height or i >= map_generator.height - extra_height \
		or j < extra_width or j >= map_generator.width - extra_width

func _generate_heights():
	height_map = map_generator.GeneratePerlinMap()
	terrain_array = []
	terrain_array.resize(map_generator.height)

	water_array = []
	water_array.resize(map_generator.height)

	for i in range(map_generator.height):
		terrain_array[i] = []
		terrain_array[i].resize(map_generator.width)
		water_array[i] = []
		water_array[i].resize(map_generator.width)

		for j in range(map_generator.width):
			water_array[i][j] = false
			terrain_array[i][j] = []
			

			var y_pos
			# var block
			
			# var x_pos = j * 2 + i % 2;
			# var z_pos = i * sqrt(3)

			if height_map[i][j] + height_offset < 0:
				y_pos = 0
				# block = water_scene.instantiate()
				water_array[i][j] = true
				water_blocks.append(Vector2i(j, i))
			else:
				y_pos = (height_map[i][j] + height_offset) * height_scale
				# block = block_scene.instantiate()
				terrain_array[i][j] = [y_pos]

			# map_parent.add_child(block)
			# block.position = Vector3(x_pos, y_pos, z_pos)

			# terrain_array[i][j] = block

			if y_pos == 0:
				continue

			var min_underground: float = 0

			# find the lowest surrounding block to make fill empty space beneath the current block
			# border blocks get the full fill for aesthetics
			if i == map_generator.height - 1 or i == 0 or j == map_generator.width - 1 or j == 0:
				min_underground = 0
			else:
				for y in range(i - 1, i + 2):
					if min_underground <= 0.5:
						break

					for x in range(j - 1, j + 2):
						var h = height_map[y][x] + height_offset
						if h < 0:
							min_underground = 0.5
							break

						if h * height_scale + 1 < min_underground:
							min_underground = h * height_scale + 1

			# fill the empty space
			while y_pos > min_underground:
				# var underground_block = underground_scene.instantiate()
				# map_parent.add_child(underground_block)
				
				y_pos -= 1
				terrain_array[i][j].append(y_pos)
				# underground_block.position = Vector3(x_pos, y_pos, z_pos)
	
	_compute_water_proximity_map()