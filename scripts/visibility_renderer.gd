extends Node3D

@export var decal_scene: PackedScene

var decals_array: Array

func initialize(width: int, height: int):
	decals_array = []
	for i in range(height):
		decals_array.append([])
		for j in range(width):
			var decal: Decal = decal_scene.instantiate()
			add_child(decal)
			var x_pos = j * 2 + posmod(i, 2)
			var z_pos = i * sqrt(3)
			decal.global_position = Vector3(x_pos, 2.5, z_pos)
			decal.visible = false
			decals_array[i].append(decal)

func update_and_render(cells_visibility: Array):
	for i in range(len(decals_array)):
		for j in range(len(decals_array[i])):
			if cells_visibility[i][j] >= 0.99:
				decals_array[i][j].visible = false
				continue
			decals_array[i][j].visible = true
			decals_array[i][j].albedo_mix = 1 - cells_visibility[i][j]
