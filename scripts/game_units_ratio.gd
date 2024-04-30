class_name GameUnitsRatio extends Resource

@export var attackers_ratio: CalmRushRatio
@export var defenders_ratio: CalmRushRatio

func _to_string():
    return "{0}-{1} vs {2}-{3}".format([defenders_ratio.calm, defenders_ratio.rush, attackers_ratio.calm, attackers_ratio.rush])