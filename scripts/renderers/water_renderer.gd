extends CellRenderer

func render(game_map: GameMap, from: Vector2i, to: Vector2i):
	var water_array = game_map.water_array

	var new_multimesh = MultiMesh.new()
	new_multimesh.transform_format = MultiMesh.TRANSFORM_3D
	new_multimesh.use_custom_data = true
	new_multimesh.mesh = multimesh.mesh
	multimesh = new_multimesh

	var transforms = []

	var cindex := 0

	for i in range(from.y, to.y):
		for j in range(from.x, to.x):
			if not water_array[i][j]:
				continue

			var x_pos = j * 2 + posmod(i, 2)
			var z_pos = i * sqrt(3)

			transforms.append(Transform3D(Basis(), Vector3(x_pos, 0, z_pos)))
			cell_indexes[Vector2i(j, i)] = [ cindex ]
			cindex += 1
	
	var count = len(transforms)
	multimesh.instance_count = count
	for i in range(count):
		multimesh.set_instance_transform(i, transforms[i])
		multimesh.set_instance_custom_data(i, Color(0, 0, 0, 0))
