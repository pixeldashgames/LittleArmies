class_name Unit extends Node3D

const max_unit_speed := 5
const morale_effect_curve_on_speed := 0.5
const max_count_that_affects_speed := 100
const count_effect_curve_on_speed := 3.6
const injured_percentage_effect_curve_on_speed := 0.4
const morale_effect_range = Vector2(0, 1)
const count_effect_range = Vector2(0.5, 1)
const injured_effect_range = Vector2(0, 1)

const max_unit_visibility := 10
const morale_effect_curve_on_visibility := 0.5
const max_count_that_affects_visibility := 20
const count_effect_curve_on_visibility := 3.6
const injured_percentage_effect_curve_on_visibility := 0.4
const morale_visibility_effect_range = Vector2(0, 1)
const count_visibility_effect_range = Vector2(0.5, 1)
const injured_visibility_effect_range = Vector2(0, 1)

@onready var agent: Agent = $Agent

var current_position: Vector2i

var team: int

var count: int
var morale: float
var injured: int
var food_amount: int
var medicine_amount: int

func initialize(controller, unit_pos, unit_team, unit_count, unit_morale, unit_injured, unit_food_amount, unit_medicine_amount):
	current_position = unit_pos
	team = unit_team
	count = unit_count
	morale = unit_morale
	injured = unit_injured
	food_amount = unit_food_amount
	medicine_amount = unit_medicine_amount
	agent.initialize(controller, self)

	var models = $Models.get_children()
	for model in models:
		var anim_player: AnimationPlayer = model.find_child("AnimationPlayer")
		if anim_player:
			anim_player.play("Idle")


func get_visibility_range() -> float:
	return 5 

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
