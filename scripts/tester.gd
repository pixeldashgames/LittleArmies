extends Node

class TestConfigResults:
    var total_defender_wins := 0
    var total_attacker_wins := 0
    var total_attacker_battle_wins := 0
    var total_defender_battle_wins := 0
    var average_duration := 0.0

    func _init(defender_wins: int, attacker_wins: int, attacker_battle_wins: int, defender_battle_wins: int, duration: float):
        total_defender_wins = defender_wins
        total_attacker_wins = attacker_wins
        total_attacker_battle_wins = attacker_battle_wins
        total_defender_battle_wins = defender_battle_wins
        average_duration = duration

@export var configs: Array[TestConfig]

@export var main_scene: PackedScene

@export var calm_attacker_scene: PackedScene
@export var calm_defender_scene: PackedScene
@export var rushing_attacker_scene: PackedScene 
@export var rushing_defender_scene: PackedScene

func _save_test_results(config: TestConfig, results: TestConfigResults):
    var file = FileAccess.open("user://" + config.test_name + ".csv", FileAccess.WRITE)
    file.store_line("Calm Defenders, Rushing Defenders, Calm Attackers, Rushing Attackers, Defender Wins,Attacker Wins,Attacker Battle Wins,Defender Battle Wins,Average Duration")
    file.store_line(str(config.calm_defenders) + "," + str(config.rushing_defenders) + "," + str(config.calm_attackers) + "," + str(config.rushing_attackers) + "," + str(results.total_defender_wins) + "," + str(results.total_attacker_wins) + "," + str(results.total_attacker_battle_wins) + "," + str(results.total_defender_battle_wins) + "," + str(results.average_duration))
    file.close()

func _enter_tree():
    for config in configs:
        var total_defender_wins = 0
        var total_attacker_wins = 0
        var total_attacker_battle_wins = 0
        var total_defender_battle_wins = 0
        var total_duration = 0
        for i in range(config.test_count):
            var main = main_scene.instance()
            var game_controller: GameController = main.get_child(0)
            var game_map: GameMap = game_controller.get_child(0)

            game_map.forest_threshold = config.forest_threshold
            game_map.mountains_compound_threshold = config.mountain_threshold

            game_controller.defender_scenes = []

            for _t in range(config.calm_defenders):
                game_controller.defender_scenes.append(calm_defender_scene)
            for _t in range(config.rushing_defenders):
                game_controller.defender_scenes.append(rushing_defender_scene)
            
            game_controller.attacker_scenes = []

            for _t in range(config.calm_attackers):
                game_controller.attacker_scenes.append(calm_attacker_scene)
            for _t in range(config.rushing_attackers):
                game_controller.attacker_scenes.append(rushing_attacker_scene)

            var result: GameController.GameOverResult = await game_controller.game_over
            if result == GameController.GameOverResult.ATTACKERS_WON_BY_CONQUEST || result == GameController.GameOverResult.ATTACKERS_WON_BY_ELIMINATION:
                total_attacker_wins += 1
            else:
                total_defender_wins += 1

            total_attacker_battle_wins += game_controller.attackers_battles_won
            total_defender_battle_wins += game_controller.defenders_battles_won
            total_duration += game_controller.duration

            main.queue_free()
        var results = TestConfigResults.new(total_defender_wins, total_attacker_wins, total_attacker_battle_wins, total_defender_battle_wins, float(total_duration) / config.test_count)
        _save_test_results(config, results)


