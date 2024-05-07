class_name CellRenderer extends MultiMeshInstance3D

var instance_positions: Array[Vector2i] = []

func change_instance_visibility(pos: Vector2i, vis: float):
	for i in range(len(instance_positions)):
		if instance_positions[i] != pos:
			continue
		multimesh.set_instance_custom_data(i, Color(vis, 0, 0, 0))
