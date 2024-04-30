class_name Unit extends Node3D

const max_unit_speed := 5.0
const morale_effect_curve_on_speed := 0.5
const max_count_that_affects_speed := 100
const count_effect_curve_on_speed := 3.6
const injured_percentage_effect_curve_on_speed := 0.4
const morale_effect_range = Vector2(0.5, 1)
const count_effect_range = Vector2(0.5, 1)
const injured_effect_range = Vector2(0.5, 1)

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

const max_supplies = 1500

const missed_supply_morale_penalty = 0.005
const killed_unit_morale_penalty = 0.01
const injured_unit_morale_penalty = 0.005
const picked_up_supplies_morale_boost = 0.001
const expected_daily_morale_change = -0.01
const expected_daily_morale_change_on_castle = 0.05
const enemy_killed_morale_boost = 0.025
const enemy_injured_morale_boost = 0.015
const castle_taken_morale_boost = 0.25
const castle_neutralized_morale_boost = 0.15

const army_percentage_desertion_curve_on_morale = 5
const morale_needed_for_desertion = 0.7

const injured_death_chance = 0.1
const injured_recovery_chance = 0.15

const terrain_advantage = {
	GameMap.TerrainType.PLAIN: {
		GameMap.TerrainType.PLAIN: 1,
		GameMap.TerrainType.FOREST: 0.8,
		GameMap.TerrainType.MOUNTAIN: 0.6,
		GameMap.TerrainType.WATER: 1.5,
		GameMap.TerrainType.CASTLE: 0.5
	},
	GameMap.TerrainType.FOREST: {
		GameMap.TerrainType.PLAIN: 1.2,
		GameMap.TerrainType.FOREST: 0.8,
		GameMap.TerrainType.MOUNTAIN: 0.8,
		GameMap.TerrainType.WATER: 1.3,
		GameMap.TerrainType.CASTLE: 0.5
	},
	GameMap.TerrainType.MOUNTAIN: {
		GameMap.TerrainType.PLAIN: 1.4,
		GameMap.TerrainType.FOREST: 0.8,
		GameMap.TerrainType.MOUNTAIN: 0.9,
		GameMap.TerrainType.WATER: 1.5,
		GameMap.TerrainType.CASTLE: 0.5
	},
	GameMap.TerrainType.WATER: {
		GameMap.TerrainType.PLAIN: 0.8,
		GameMap.TerrainType.FOREST: 0.7,
		GameMap.TerrainType.MOUNTAIN: 0.5,
		GameMap.TerrainType.WATER: 1,
		GameMap.TerrainType.CASTLE: 0.5
	},
	GameMap.TerrainType.CASTLE: {
		GameMap.TerrainType.PLAIN: 1.5,
		GameMap.TerrainType.FOREST: 1.4,
		GameMap.TerrainType.MOUNTAIN: 1.3,
		GameMap.TerrainType.WATER: 2,
		GameMap.TerrainType.CASTLE: 1
	} 
}

@onready var agent: Agent = $Agent

var unit_name: String

var current_position: Vector2i

var team: int

var count: int
var morale: float
var injured: int
var supplies: int

func to_dict(game_controller: GameController) -> Dictionary:
	return {
		"unit_name": unit_name,
		"current_position": current_position,
		"team": team,
		"count": count,
		"supplies": supplies,
		"terrain": int(game_controller.game_map.get_terrain_at(current_position)),
		"height": game_controller.game_map.get_height_at(current_position),
		"desire": agent.get_desire() if agent is SmartAgentInterface else -1
	}

func normal_distribution(mean: float, std_dev: float):
	var u1 = randf()
	var u2 = randf()
	var rand_std_normal = sqrt(-2.0 * log(u1)) * sin(2.0 * PI * u2)
	var rand_normal = mean + std_dev * rand_std_normal
	return rand_normal

func desert_units():
	if morale > morale_needed_for_desertion:
		return

	var can_desert = count - injured
	var morale_desertion_factor = 1 - morale / 0.7
	var desertion_chance = ease(morale_desertion_factor, army_percentage_desertion_curve_on_morale)
	desertion_chance = clamp(normal_distribution(desertion_chance, 0.05), 0, 1)
	var desertion = roundi(can_desert * desertion_chance)
	count -= desertion

	if desertion > 0:
		Logger.log_desertion(self, desertion)

func end_of_day(in_castle: bool):
	if supplies < count:
		change_morale(missed_supply_morale_penalty * (supplies - count))
	change_morale(expected_daily_morale_change if not in_castle \
					else expected_daily_morale_change_on_castle)
	
	# injured recovery / death
	var dead := 0
	var recovered := 0
	for i in range(injured):
		var random = randf()
		if random < injured_death_chance:
			dead += 1
		elif random < injured_death_chance + injured_recovery_chance:
			recovered += 1

	if dead > 0:
		Logger.log_injured_died(self, dead)
	if recovered > 0:
		Logger.log_injured_recovered(self, recovered)

	count -= dead
	injured -= recovered + dead

func change_morale(expected_change: float, deviation: float = 0.01):
	morale = clamp(morale + normal_distribution(expected_change, deviation), 0, 1)

func decrease_supplies():
	supplies = max(0, supplies - count)

func take_castle():
	change_morale(castle_taken_morale_boost)

func neutralized_castle():
	change_morale(castle_neutralized_morale_boost)

func pickup_supplies(available: int):
	# make castles deplete
	var taken = min(available, max_supplies - supplies)

	if taken == 0:
		return 0

	change_morale(picked_up_supplies_morale_boost * taken)
	supplies += taken

	return taken

func kill_units(amount: int):
	amount = min(count - injured, amount)
	count -= amount
	change_morale(-killed_unit_morale_penalty * amount)
	return amount

func injure_units(amount: int):
	amount = min(count - injured, amount)
	injured += amount
	change_morale(-injured_unit_morale_penalty * amount)
	return amount

func is_dead():
	return count - injured <= 0

func initialize(controller, u_name, unit_pos, unit_team, unit_count, unit_morale, unit_injured, unit_food_amount):
	unit_name = u_name
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

func damage_dealt_to_enemy(killed: int, _injured: int):
	change_morale(enemy_killed_morale_boost * killed + enemy_injured_morale_boost * _injured)

# Returns [killed, injured]
func get_damage(my_terrain: GameMap.TerrainType, other_unit_terrain: GameMap.TerrainType, my_height: float, other_unit_height: float, advantage: bool) -> Array[float]:
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

	var killed: float = effective_count * max_kill_chance * total_modifier_damage_modifier
	var _injured: float = effective_count * max_injure_chance * total_modifier_damage_modifier

	killed *= normal_distribution(1, 0.1)
	_injured *= normal_distribution(1, 0.1)

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
