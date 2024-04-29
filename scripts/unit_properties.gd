extends Node3D

func set_properties(unit: Unit):
	var count_icon = "🛡️" if unit.team == 0 else "🗡️"
	$Label.text = "{0}\n{5}{1}\n🤕{2}\n🍗{3}\n🥳{4}"\
					.format(
						[unit.unit_name,
						str(unit.count - unit.injured), 
						str(unit.injured), 
						str(unit.supplies),
						str(roundi(unit.morale * 100)),
						count_icon])
