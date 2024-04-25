extends Node3D

@export var chunk_size: int = 8
@export var multi_mesh_scene: PackedScene

func render(game_map: GameMap):
	var map_height = game_map.map_generator.height
	var map_width = game_map.map_generator.width
	var vertical_chunks = ceili(map_height / chunk_size)
	var horizontal_chunks = ceili(map_width / chunk_size)

	for i in range(vertical_chunks):
		for j in range(horizontal_chunks):
			var multi_mesh_instance = multi_mesh_scene.instantiate()
			add_child(multi_mesh_instance)
			var from: Vector2i = Vector2i(j * chunk_size, i * chunk_size)
			var to: Vector2i = Vector2i(min((j + 1) * chunk_size, map_width), min((i + 1) * chunk_size, map_height))
			multi_mesh_instance.render(game_map, from, to)
