extends Node3D

func set_properties(unit: Unit):
	$Label.text = "➕{0}\n🤕{1}\n🍗{2}"\
					.format(
						[str(unit.count - unit.injured), 
						str(unit.injured), 
						str(unit.supplies)])
