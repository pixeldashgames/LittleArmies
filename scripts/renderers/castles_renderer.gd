extends CellRenderer

func render(game_map: GameMap):
	var castles_array = game_map.castles_array

	var new_multimesh = MultiMesh.new()
	new_multimesh.transform_format = MultiMesh.TRANSFORM_3D
	new_multimesh.use_custom_data = true
	new_multimesh.mesh = multimesh.mesh
	multimesh = new_multimesh
	var transforms = []

	var cindex := 0

	for pos in castles_array:
		var x_pos = pos.x * 2 + posmod(pos.y, 2)
		var z_pos = pos.y * sqrt(3)

		transforms.append(Transform3D(Basis(), Vector3(x_pos, game_map.get_height_at(pos), z_pos)))
		cell_indexes[pos] = [ cindex ]
		cindex += 1
	
	var count = len(transforms)
	multimesh.instance_count = count
	for i in range(count):
		multimesh.set_instance_transform(i, transforms[i])
		multimesh.set_instance_custom_data(i, Color(0, 0, 0, 0))