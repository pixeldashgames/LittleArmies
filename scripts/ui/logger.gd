class_name Logger extends VBoxContainer

const max_log_count = 10

static var instance = null

func _ready():
	instance = self

static func log_combat(unit_a: Unit, unit_b: Unit, a_killed: int, a_injured: int, b_killed: int, b_injured: int):
	var a_color = Color(1, 0.6, 0.6).to_html(false) \
					if unit_a.team == 1 \
					else Color(0.6, 0.6, 1).to_html(false)
	var b_color = Color(1, 0.6, 0.6).to_html(false) \
					if unit_b.team == 1 \
					else Color(0.6, 0.6, 1).to_html(false)
	
	var a_tag = "[color={0}]{1}[/color]".format([a_color, unit_a.unit_name])
	var b_tag = "[color={0}]{1}[/color]".format([b_color, unit_b.unit_name])
	
	do_log("{0} fought {1}!".format([a_tag, b_tag]))
	do_log("{0} killed {1} and injured {2} of {3}'s units.".format([a_tag, a_killed, a_injured, b_tag]))
	do_log("{0} killed {1} and injured {2} of {3}'s units.".format([b_tag, b_killed, b_injured, a_tag]))

	if unit_a.is_dead():
		do_log("{0} is dead!".format([a_tag]))

	if unit_b.is_dead():
		do_log("{0} is dead!".format([b_tag]))

static func log_take_castle(unit: Unit, castle: GameController.Castle):
	var a_color = Color(1, 0.6, 0.6).to_html(false) \
					if unit.team == 1 \
					else Color(0.6, 0.6, 1).to_html(false)
	
	var a_tag = "[color={0}]{1}[/color]".format([a_color, unit.unit_name])
	
	do_log("{0} took {1}!".format([a_tag, castle.name]))

static func log_desertion(unit: Unit, count: int):
	var a_color = Color(1, 0.6, 0.6).to_html(false) \
					if unit.team == 1 \
					else Color(0.6, 0.6, 1).to_html(false)
	
	var a_tag = "[color={0}]{1}[/color]".format([a_color, unit.unit_name])
	
	var units_str = "unit" if count == 1 else "units"

	do_log("{0} {1} deserted from {2}!".format([str(count), units_str, a_tag]))

	if unit.is_dead():
		do_log("{0} is disbanded!".format([a_tag]))

static func log_injured_recovered(unit: Unit, count: int):
	var a_color = Color(1, 0.6, 0.6).to_html(false) \
					if unit.team == 1 \
					else Color(0.6, 0.6, 1).to_html(false)
	
	var a_tag = "[color={0}]{1}[/color]".format([a_color, unit.unit_name])
	
	var units_str = "unit" if count == 1 else "units"

	do_log("{0} {1} from {2} recovered from injuries!".format([str(count), units_str, a_tag]))

static func log_injured_died(unit: Unit, count: int):
	var a_color = Color(1, 0.6, 0.6).to_html(false) \
					if unit.team == 1 \
					else Color(0.6, 0.6, 1).to_html(false)
	
	var a_tag = "[color={0}]{1}[/color]".format([a_color, unit.unit_name])
	
	var units_str = "unit" if count == 1 else "units"

	do_log("{0} {1} from {2} died from injuries!".format([str(count), units_str, a_tag]))

static func do_log(text: String):
	if instance == null:
		return

	var log_instance = RichTextLabel.new()
	log_instance.fit_content = true
	log_instance.bbcode_enabled = true
	log_instance.text = text
	instance.add_child(log_instance)

	if instance.get_children(false).size() > max_log_count:
		instance.get_child(0).queue_free()