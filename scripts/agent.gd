class_name Agent extends Node3D

class AgentMove:
	var target_pos
	var attacking_pos

	func _init(target, attack = null):
		target_pos = target
		attacking_pos = attack

var controller: GameController
var unit: Unit

func initialize(game_controller: GameController, agent_unit: Unit):
	controller = game_controller
	unit = agent_unit

func get_move() -> AgentMove:
	assert(false, "Trying to query base Agent")
	return null
