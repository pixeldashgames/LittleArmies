class_name Unit extends Node3D

const max_unit_speed := 5.0
const morale_effect_curve_on_speed := 0.5
const max_count_that_affects_speed := 100
const count_effect_curve_on_speed := 3.6
const injured_percentage_effect_curve_on_speed := 0.4
const morale_effect_range = Vector2(0, 1)
const count_effect_range = Vector2(0.5, 1)
const injured_effect_range = Vector2(0, 1)

const max_unit_vigilance := 5.0
const max_count_that_affects_vigilance := 50
const morale_effect_curve_on_vigilance := 0.3
const count_effect_curve_on_vigilance := 0.2
const morale_vigilance_effect_range = Vector2(0.1, 1)
const count_vigilance_effect_range = Vector2(0.2, 1)

const max_count_that_affects_visibility := 50
const count_effect_curve_on_visibility := 3.6
const visibility_chance_range = Vector2(0.5, 1)

const advantage_damage_modifier := 1.25
const disadvantage_damage_modifier := 0.75

const max_kill_chance := 0.3
const max_injure_chance := 0.1
const morale_effect_curve_on_damage_chance := 3.4
const max_height_difference_for_damage := 2.0
const height_increase_effect_curve_on_damage := 2.0
const height_decrease_effect_curve_on_damage := 0.5
const height_difference_effect_range := Vector2(0, 1.5)

const max_supplies = 500

# do random damage with a distribution

const terrain_advantage = {
	TerrainType.PLAIN: {
		TerrainType.PLAIN: 1,
		TerrainType.FOREST: 0.8,
		TerrainType.MOUNTAIN: 0.6,
		TerrainType.WATER: 1.5
	},
	TerrainType.FOREST: {
		TerrainType.PLAIN: 1.2,
		TerrainType.FOREST: 0.8,
		TerrainType.MOUNTAIN: 0.8,
		TerrainType.WATER: 1.3
	},
	TerrainType.MOUNTAIN: {
		TerrainType.PLAIN: 1.4,
		TerrainType.FOREST: 0.8,
		TerrainType.MOUNTAIN: 0.9,
		TerrainType.WATER: 1.5
	},
	TerrainType.WATER: {
		TerrainType.PLAIN: 0.6,
		TerrainType.FOREST: 0.7,
		TerrainType.MOUNTAIN: 0.5,
		TerrainType.WATER: 1
	}
}

enum TerrainType {
	PLAIN = 0,
	FOREST = 1,
	MOUNTAIN = 2,
	WATER = 3
}

@onready var agent: Agent = $Agent

var current_position: Vector2i

var team: int

var count: int
var morale: float
var injured: int
var supplies: int

const sqrt2pi = sqrt(2 * PI)

func normal_distribution(x: float, m: float, o_sqrd: float):
	var o = sqrt(o_sqrd)
	var first_factor = 1 / o * (sqrt2pi)
	var second_factor = exp(-((x - m) ** 2) / (2 * o_sqrd))

	return first_factor * second_factor

func end_of_day_morale_change():
	if supplies < count:
		pass

func decrease_morale(expected_value: float):


func decrease_supplies():
	supplies = max(0, supplies - count)

func pickup_supplies():
	supplies = max_supplies

func kill_units(amount: int):
	count = max(injured, count - amount)

func injure_units(amount: int):
	injured = min(count, injured + amount)

func is_dead():
	return count - injured <= 0

func initialize(controller, unit_pos, unit_team, unit_count, unit_morale, unit_injured, unit_food_amount):
	current_position = unit_pos
	team = unit_team
	count = unit_count
	morale = unit_morale
	injured = unit_injured
	supplies = unit_food_amount
	agent.initialize(controller, self)

	var models = $Models.get_children()
	for model in models:
		var anim_player: AnimationPlayer = model.find_child("AnimationPlayer")
		if anim_player:
			anim_player.play("Idle")

# Returns [killed, injured]
func get_damage(my_terrain: TerrainType, other_unit_terrain: TerrainType, my_height: float, other_unit_height: float, advantage: bool) -> Array[float]:
	var effective_count = count - injured
	var morale_modifier = ease(morale, morale_effect_curve_on_damage_chance)
	var terrain_modifier = terrain_advantage[my_terrain][other_unit_terrain]
	var height_difference = clamp(abs(other_unit_height - my_height) / max_height_difference_for_damage, 0, 1)
	var height_difference_modifier
	if my_height > other_unit_height:
		height_difference_modifier = lerpf(1, height_difference_effect_range.y, ease(height_difference, height_decrease_effect_curve_on_damage))
	else:
		height_difference_modifier = lerpf(height_difference_effect_range.x, 1 , ease(1 - height_difference, height_increase_effect_curve_on_damage))
	
	var advantaje_modifier = advantage_damage_modifier if advantage else disadvantage_damage_modifier

	var total_modifier_damage_modifier = morale_modifier * height_difference_modifier * terrain_modifier * advantaje_modifier

	var killed = effective_count * max_kill_chance * total_modifier_damage_modifier
	var _injured = effective_count * max_injure_chance * total_modifier_damage_modifier
	return [killed, _injured]

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
