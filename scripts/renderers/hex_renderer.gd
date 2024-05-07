extends Node3D

@export var chunk_size: int = 8
@export var multi_mesh_scene: PackedScene

var last_visibility_chunks: Array = []

var mmeshes: Array = []

var vertical_chunks
var horizontal_chunks

var map_height
var map_width

func render(game_map: GameMap):
	map_height = game_map.map_generator.height
	map_width = game_map.map_generator.width
	vertical_chunks = ceili(map_height / chunk_size)
	horizontal_chunks = ceili(map_width / chunk_size)

	# initializing last_visibility_chuns
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

	mmeshes.resize(vertical_chunks)

	for i in range(vertical_chunks):
		mmeshes[i] = []
		mmeshes[i].resize(horizontal_chunks)

		for j in range(horizontal_chunks):
			var from: Vector2i = Vector2i(j * chunk_size, i * chunk_size)
			var to: Vector2i = Vector2i(min((j + 1) * chunk_size, map_width), min((i + 1) * chunk_size, map_height))

			var multi_mesh_instance = multi_mesh_scene.instantiate()
			multi_mesh_instance.visible = false
			add_child(multi_mesh_instance)
			multi_mesh_instance.render(game_map, from, to)
			mmeshes[i][j] = multi_mesh_instance

func change_visibility(visibility_function: Callable):
	for i in range(vertical_chunks):
		for j in range(horizontal_chunks):
			# check if every cell in the chunk is visible
			var from: Vector2i = Vector2i(j * chunk_size, i * chunk_size)
			var to: Vector2i = Vector2i(min((j + 1) * chunk_size, map_width), min((i + 1) * chunk_size, map_height))

			for y in range(from.y, to.y):
				for x in range(from.x, to.x):
					var vis = visibility_function.call(Vector2i(x, y))

					if last_visibility_chunks[i][j][y - from.y][x - from.x] != vis:
						last_visibility_chunks[i][j][y - from.y][x - from.x] = vis
						mmeshes[i][j].change_instance_visibility(Vector2i(x, y), vis)
