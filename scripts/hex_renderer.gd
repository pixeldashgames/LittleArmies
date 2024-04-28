extends Node3D

@export var chunk_size: int = 8
@export var multi_mesh_scene: PackedScene
@export var mutli_mesh_shadowed_scene: PackedScene

var normal_mmeshes: Array = []
var shadowed_mmeshes: Array = []

var vertical_chunks
var horizontal_chunks

var map_height
var map_width

func render(game_map: GameMap):
	map_height = game_map.map_generator.height
	map_width = game_map.map_generator.width
	vertical_chunks = ceili(map_height / chunk_size)
	horizontal_chunks = ceili(map_width / chunk_size)

	# TODO: Different shadow levels

	for i in range(vertical_chunks):
		normal_mmeshes.append([])
		shadowed_mmeshes.append([])
		for j in range(horizontal_chunks):
			var from: Vector2i = Vector2i(j * chunk_size, i * chunk_size)
			var to: Vector2i = Vector2i(min((j + 1) * chunk_size, map_width), min((i + 1) * chunk_size, map_height))

			var multi_mesh_instance = multi_mesh_scene.instantiate()
			add_child(multi_mesh_instance)
			multi_mesh_instance.render(game_map, from, to)
			normal_mmeshes[i].append(multi_mesh_instance)

			var shadowed_mm = mutli_mesh_shadowed_scene.instantiate()
			add_child(shadowed_mm)
			shadowed_mm.render(game_map, from, to)
			shadowed_mmeshes[i].append(shadowed_mm)

func change_visibility(visibility_function: Callable):
	for i in range(vertical_chunks):
		for j in range(horizontal_chunks):
			# check if every cell in the chunk is visible
			var from: Vector2i = Vector2i(j * chunk_size, i * chunk_size)
			var to: Vector2i = Vector2i(min((j + 1) * chunk_size, map_width), min((i + 1) * chunk_size, map_height))

			# -1 = undetermined 0 = no visibility 1 = all visibility
			var visibility = -1
			var mixed = false

			var non_shadowed = []
			var shadowed = []

			for y in range(from.y, to.y):
				for x in range(from.x, to.x):
					var rounded_value: int = 0 if visibility_function.call(Vector2i(x, y)) < 0.0001 else 1

					if rounded_value == 0:
						shadowed.append(Vector2i(x, y))
					else:
						non_shadowed.append(Vector2i(x, y))

					if mixed:
						continue

					if visibility == -1:
						visibility = rounded_value
					elif visibility != rounded_value:
						visibility = -1
						mixed = true

			if not mixed:
				normal_mmeshes[i][j].visible = visibility == 1

				if visibility == 1:
					normal_mmeshes[i][j].change_all_instances_visibility(true)
					
				shadowed_mmeshes[i][j].visible = visibility == 0

				if visibility == 0:
					shadowed_mmeshes[i][j].change_all_instances_visibility(true)
				continue
			
			normal_mmeshes[i][j].visible = true
			shadowed_mmeshes[i][j].visible = true

			for element in non_shadowed:
				normal_mmeshes[i][j].change_instance_visibility(element, true)
				shadowed_mmeshes[i][j].change_instance_visibility(element, false)
			
			for element in shadowed:
				normal_mmeshes[i][j].change_instance_visibility(element, false)
				shadowed_mmeshes[i][j].change_instance_visibility(element, true)
