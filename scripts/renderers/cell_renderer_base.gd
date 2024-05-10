class_name CellRenderer extends MultiMeshInstance3D

var cell_indexes: Dictionary = {}

func update_visibility(visibility_function: Callable):
	for pos in cell_indexes:
		var vis = visibility_function.call(pos)
		for i in cell_indexes[pos]:
			multimesh.set_instance_custom_data(i, Color(vis, 0, 0, 0))
