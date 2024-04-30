extends Node3D

@export var chunk_size: int = 8
@export var shadow_cascades: int = 5
@export var multi_mesh_scene: PackedScene
@export var mutli_mesh_shadowed_scene: PackedScene

var last_visibility_chunks: Array = []

var normal_mmeshes: Array = []
var shadowed_mmeshes_levels: Array = []

var vertical_chunks
var horizontal_chunks

var map_height
var map_width

func render(game_map: GameMap):
	map_height = game_map.map_generator.height
	map_width = game_map.map_generator.width
	vertical_chunks = ceili(map_height / chunk_size)
	horizontal_chunks = ceili(map_width / chunk_size)

	shadowed_mmeshes_levels = []
	shadowed_mmeshes_levels.resize(shadow_cascades)
	for k in range(shadow_cascades):
		shadowed_mmeshes_levels[k] = []
		shadowed_mmeshes_levels[k].resize(vertical_chunks)
	
	normal_mmeshes.resize(vertical_chunks)

	for i in range(vertical_chunks):
		normal_mmeshes[i] = []
		normal_mmeshes[i].resize(horizontal_chunks)

		for k in range(shadow_cascades):
			shadowed_mmeshes_levels[k][i] = []
			shadowed_mmeshes_levels[k][i].resize(horizontal_chunks) 

		for j in range(horizontal_chunks):
			var from: Vector2i = Vector2i(j * chunk_size, i * chunk_size)
			var to: Vector2i = Vector2i(min((j + 1) * chunk_size, map_width), min((i + 1) * chunk_size, map_height))

			var multi_mesh_instance = multi_mesh_scene.instantiate()
			multi_mesh_instance.visible = false
			add_child(multi_mesh_instance)
			multi_mesh_instance.render(game_map, from, to, shadow_cascades, shadow_cascades)
			normal_mmeshes[i][j] = multi_mesh_instance

			for k in range(shadow_cascades):
				var shadowed_mm = mutli_mesh_shadowed_scene.instantiate()
				shadowed_mm.visible = false
				add_child(shadowed_mm)
				shadowed_mm.render(game_map, from, to, k, shadow_cascades)
				shadowed_mmeshes_levels[k][i][j] = get_child(get_child_count() - 1)

func get_shadow_cascade(visibility_level: float) -> int:
	for i in range(shadow_cascades):
		if visibility_level <= (float(i) / shadow_cascades) + 0.0001:
			return i
	return shadow_cascades

func _get_mmesh(i: int, j: int, shadow_cascade: int):
	if shadow_cascade == shadow_cascades:
		return normal_mmeshes[i][j]
	else:
		return shadowed_mmeshes_levels[shadow_cascade][i][j]

func change_visibility(visibility_function: Callable):
	if last_visibility_chunks.size() == 0:
		last_visibility_chunks.resize(vertical_chunks)
		for i in range(vertical_chunks):
			last_visibility_chunks[i] = []
			last_visibility_chunks[i].resize(horizontal_chunks)
			for j in range(horizontal_chunks):
				last_visibility_chunks[i][j] = []
				last_visibility_chunks[i][j].resize(chunk_size)
				for y in range(chunk_size):
					last_visibility_chunks[i][j][y] = []
					last_visibility_chunks[i][j][y].resize(chunk_size)
					for x in range(chunk_size):
						last_visibility_chunks[i][j][y][x] = -1

	for i in range(vertical_chunks):
		for j in range(horizontal_chunks):
			# check if every cell in the chunk is visible
			var from: Vector2i = Vector2i(j * chunk_size, i * chunk_size)
			var to: Vector2i = Vector2i(min((j + 1) * chunk_size, map_width), min((i + 1) * chunk_size, map_height))

			var visibility = -1
			var mixed = false

			var elements_per_cascade = []
			for k in range(shadow_cascades + 1):
				elements_per_cascade.append([])

			var chunk_changed = false

			for y in range(from.y, to.y):
				for x in range(from.x, to.x):
					var rounded_value: int = get_shadow_cascade(visibility_function.call(Vector2i(x, y)))

					if last_visibility_chunks[i][j][y - from.y][x - from.x] != rounded_value:
						last_visibility_chunks[i][j][y - from.y][x - from.x] = rounded_value
						chunk_changed = true

					elements_per_cascade[rounded_value].append(Vector2i(x, y))

					if mixed:
						continue

					if visibility == -1:
						visibility = rounded_value
					elif visibility != rounded_value:
						visibility = -1
						mixed = true

			if not chunk_changed:
				continue

			if not mixed:
				for k in range(shadow_cascades + 1):
					var show_mmesh = visibility == k

					var mmesh = _get_mmesh(i, j, k)

					mmesh.visible = show_mmesh

					mmesh.change_all_instances_visibility(show_mmesh)
				continue
			
			for k in range(shadow_cascades + 1):
				var mmesh = _get_mmesh(i, j, k)
				mmesh.visible = true

				for element in elements_per_cascade[k]:
					for c in range(shadow_cascades + 1):
						_get_mmesh(i, j, c).change_instance_visibility(element, c == k)