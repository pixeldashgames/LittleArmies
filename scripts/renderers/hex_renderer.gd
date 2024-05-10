extends Node3D

@export var chunk_size: int = 8
@export var multi_mesh_scene: PackedScene

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

	mmeshes.resize(vertical_chunks)

	for i in range(vertical_chunks):
		mmeshes[i] = []
		mmeshes[i].resize(horizontal_chunks)

		for j in range(horizontal_chunks):
			var from: Vector2i = Vector2i(j * chunk_size, i * chunk_size)
			var to: Vector2i = Vector2i(min((j + 1) * chunk_size, map_width), min((i + 1) * chunk_size, map_height))

			var multi_mesh_instance = multi_mesh_scene.instantiate()
			add_child(multi_mesh_instance)
			multi_mesh_instance.render(game_map, from, to)
			mmeshes[i][j] = multi_mesh_instance

func change_visibility(visibility_function: Callable):
	for i in range(vertical_chunks):
		for j in range(horizontal_chunks):
			mmeshes[i][j].update_visibility(visibility_function)
