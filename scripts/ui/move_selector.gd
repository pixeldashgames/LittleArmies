class_name MoveSelector extends StaticBody3D

@export var normal_alpha := 0.5
@export var hover_alpha := 0.7
@export var click_alpha := 1.0

@export var attack_color: Color
@export var move_color: Color

var pos: Vector2i
var is_attack: bool

func hover():
	$Sprite.modulate.a = hover_alpha

func click():
	$Sprite.modulate.a = click_alpha

func unhover():
	$Sprite.modulate.a = normal_alpha

@warning_ignore("shadowed_variable")
func initialize(pos, is_attack):
	self.pos = pos
	self.is_attack = is_attack

	$Sprite.modulate = attack_color if is_attack else move_color
	$Sprite.modulate.a = normal_alpha