class_name Unit extends Node3D

const max_unit_speed := 5
const morale_effect_curve_on_speed := 0.5
const max_count_that_affects_speed := 100
const count_effect_curve_on_speed := 3.6
const injured_percentage_effect_curve_on_speed := 0.4
const morale_effect_range = Vector2(0, 1)
const count_effect_range = Vector2(0.5, 1)
const injured_effect_range = Vector2(0, 1)

const max_unit_vigilance := 10
const max_count_that_affects_vigilance := 50
const morale_effect_curve_on_vigilance := 0.3
const count_effect_curve_on_vigilance := 0.2
const morale_vigilance_effect_range = Vector2(0.1, 1)
const count_vigilance_effect_range = Vector2(0.2, 1)

const max_count_that_affects_visibility := 50
const count_effect_curve_on_visibility := 3.6
const visibility_chance_range = Vector2(0.5, 1)

@onready var agent: Agent = $Agent

var current_position: Vector2i

var team: int

var count: int
var morale: float
var injured: int
var supplies: int
var medicine_amount: int

func decrease_morale():
	pass

func decrease_supplies():
	pass

func pickup_supplies():
	pass

func initialize(controller, unit_pos, unit_team, unit_count, unit_morale, unit_injured, unit_food_amount, unit_medicine_amount):
	current_position = unit_pos
	team = unit_team
	count = unit_count
	morale = unit_morale
	injured = unit_injured
	supplies = unit_food_amount
	medicine_amount = unit_medicine_amount
	agent.initialize(controller, self)

	var models = $Models.get_children()
	for model in models:
		var anim_player: AnimationPlayer = model.find_child("AnimationPlayer")
		if anim_player:
			anim_player.play("Idle")

func get_vigilance_range() -> float:
	return max_unit_vigilance \
		* _lerp_to_range(ease(morale, morale_effect_curve_on_vigilance), 
			morale_vigilance_effect_range) \
		* _lerp_to_range(ease(
			clamp(float(count - injured) / max_count_that_affects_vigilance, 0, 1)
			, count_effect_curve_on_vigilance), 
			count_vigilance_effect_range)

func get_visibility_chance() -> float:
	return _lerp_to_range(ease(
		clamp(float(count - injured) / max_count_that_affects_visibility, 0, 1)
		, count_effect_curve_on_visibility), 
		visibility_chance_range)

# how far can this unit move in one turn
func get_unit_speed() -> float:
	return max_unit_speed \
		* _lerp_to_range(ease(morale, morale_effect_curve_on_speed), 
			morale_effect_range) \
		* _lerp_to_range(1 - ease(
			clamp(float(count - injured) / max_count_that_affects_speed, 0, 1)
			, count_effect_curve_on_speed), 
			count_effect_range) \
		* _lerp_to_range(1 - ease(float(injured) / count, injured_percentage_effect_curve_on_speed), 
			injured_effect_range)
	
func _lerp_to_range(x: float, to_range: Vector2) -> float:
	return lerpf(to_range.x, to_range.y, x)
