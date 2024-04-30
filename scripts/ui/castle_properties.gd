extends Node3D

func set_properties(castle: GameController.Castle):
	var base_text
	if castle.owner_team == -1:
		if castle.claim_progress == 0:
			base_text = "Neutral"
			$Label.modulate = Color(1, 1, 1)
		elif castle.claim_progress < 0:
			base_text = "Attackers Claiming " + str(roundi(-castle.claim_progress * 100)) + "%"
			$Label.modulate = Color(1, 1, 0.6)
		else:
			base_text = "Defenders Claiming " + str(roundi(castle.claim_progress * 100)) + "%"
			$Label.modulate = Color(1, 1, 0.6)
	elif castle.owner_team == 1:
		if castle.claim_progress == 1:
			base_text = "Owned by Attackers"
			$Label.modulate = Color(1, 0.6, 0.6)
		else:
			base_text = "Under Siege by Defenders " + str(roundi(castle.claim_progress * 100)) + "%"
			$Label.modulate = Color(1, 1, 0.6)
	else:
		if castle.claim_progress == 1:
			base_text = "Owned by Defenders"
			$Label.modulate = Color(0.6, 0.6, 1)
		else:
			base_text = "Under Siege by Attackers " + str(roundi(castle.claim_progress * 100)) + "%"
			$Label.modulate = Color(1, 1, 0.6)
	$Label.text = castle.name + "\n" + base_text + "\n🍗" + str(castle.supplies)