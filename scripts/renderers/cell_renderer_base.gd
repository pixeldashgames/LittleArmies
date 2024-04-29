class_name CellRenderer extends MultiMeshInstance3D

var instance_positions: Array[Vector2i] = []

func change_instance_visibility(pos: Vector2i, vis: bool):
	for i in range(len(instance_positions)):
		if instance_positions[i] != pos:
			continue
			
		var t = multimesh.get_instance_transform(i)
		t.basis = Basis.from_scale(Vector3.ONE if vis else Vector3.ZERO)
		multimesh.set_instance_transform(i, t)

func change_all_instances_visibility(vis: bool):
	for i in range(multimesh.instance_count):
		var t = multimesh.get_instance_transform(i)
		t.basis = Basis.from_scale(Vector3.ONE if vis else Vector3.ZERO)
		multimesh.set_instance_transform(i, t)