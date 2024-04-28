extends CellRenderer

func render(game_map: GameMap, from: Vector2i, to: Vector2i):
	var mountains_array = game_map.mountains_array

	var new_multimesh = MultiMesh.new()
	new_multimesh.transform_format = MultiMesh.TRANSFORM_3D
	new_multimesh.use_colors = true
	new_multimesh.mesh = multimesh.mesh
	multimesh = new_multimesh

	var transforms = []

	for i in range(from.y, to.y):
		for j in range(from.x, to.x):
			if mountains_array[i][j] < 0:
				continue
			
			var x_pos = j * 2 + posmod(i, 2)
			var z_pos = i * sqrt(3)

			transforms.append(Transform3D(Basis(), Vector3(x_pos, mountains_array[i][j], z_pos)))
			instance_positions.append(Vector2i(j, i))
	
	var count = len(transforms)
	multimesh.instance_count = count
	for i in range(count):
		multimesh.set_instance_transform(i, transforms[i])


