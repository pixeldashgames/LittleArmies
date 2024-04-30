extends CellRenderer

func render(game_map: GameMap, from: Vector2i, to: Vector2i, cascade: int, total_cascades: int):
	var terrain_array = game_map.terrain_array

	var new_multimesh = MultiMesh.new()
	new_multimesh.transform_format = MultiMesh.TRANSFORM_3D
	new_multimesh.use_colors = true
	new_multimesh.mesh = multimesh.mesh
	multimesh = new_multimesh
	
	if cascade != total_cascades:
		# create a new material off the overlay and change the albedo alpha
		var material = material_overlay
		material = material.duplicate()
		material.albedo_color.a = lerpf(0, material.albedo_color.a, 1 - cascade / total_cascades)
		material_overlay = material

	var transforms = []

	for i in range(from.y, to.y):
		for j in range(from.x, to.x):
			if len(terrain_array[i][j]) <= 1:
				continue
			
			var x_pos = j * 2 + posmod(i, 2)
			var z_pos = i * sqrt(3)

			for k in range(1, len(terrain_array[i][j])):
				transforms.append(Transform3D(Basis(), Vector3(x_pos, terrain_array[i][j][k], z_pos)))
				instance_positions.append(Vector2i(j, i))
	
	var count = len(transforms)
	multimesh.instance_count = count
	for i in range(count):
		multimesh.set_instance_transform(i, transforms[i])
