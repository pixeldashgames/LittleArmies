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

func _save_test_results(config: TestConfig, ratio: GameUnitsRatio, results: TestConfigResults):
    var file = FileAccess.open("user://" + config.test_name + "_" + str(ratio) + ".csv", FileAccess.WRITE)
    file.store_line("Calm Defenders, Rushing Defenders, Calm Attackers, Rushing Attackers, Defender Wins,Attacker Wins,Attacker Battle Wins,Defender Battle Wins,Average Duration")
    file.store_line(str(ratio.defenders_ratio.calm) + "," + str(ratio.defenders_ratio.rush) + "," + str(ratio.attackers_ratio.calm) + "," + str(ratio.attackers_ratio.rush) + "," + str(results.total_defender_wins) + "," + str(results.total_attacker_wins) + "," + str(results.total_attacker_battle_wins) + "," + str(results.total_defender_battle_wins) + "," + str(results.average_duration))
    file.close()

func _ready():
    for config in configs:
        for ratio in config.ratios:
            var total_defender_wins = 0
            var total_attacker_wins = 0
            var total_attacker_battle_wins = 0
            var total_defender_battle_wins = 0
            var total_duration = 0
            for i in range(config.test_count):
                var main = main_scene.instantiate()
                add_child(main)
                var game_controller: GameController = main.get_child(0)
                var game_map: GameMap = game_controller.get_child(0)

                game_map.forest_threshold = config.forest_threshold
                game_map.mountains_compound_threshold = config.mountain_threshold

                game_controller.defender_scenes = []

                game_controller.is_test = true

                for _t in range(ratio.defenders_ratio.calm):
                    game_controller.defender_scenes.append(calm_defender_scene)
                for _t in range(ratio.defenders_ratio.rush):
                    game_controller.defender_scenes.append(rushing_defender_scene)
                
                game_controller.attacker_scenes = []

                for _t in range(ratio.attackers_ratio.calm):
                    game_controller.attacker_scenes.append(calm_attacker_scene)
                for _t in range(ratio.attackers_ratio.rush):
                    game_controller.attacker_scenes.append(rushing_attacker_scene)

                await get_tree().process_frame

                game_controller.start_game()

                var result: GameController.GameOverResult = await game_controller.game_over
                if result == GameController.GameOverResult.ATTACKERS_WON_BY_CONQUEST || result == GameController.GameOverResult.ATTACKERS_WON_BY_ELIMINATION:
                    total_attacker_wins += 1
                else:
                    total_defender_wins += 1

                total_attacker_battle_wins += game_controller.attackers_battles_won
                total_defender_battle_wins += game_controller.defenders_battles_won
                total_duration += game_controller.total_duration

                main.queue_free()

                print("finished test")

                await get_tree().create_timer(0.25).timeout

            var results = TestConfigResults.new(total_defender_wins, total_attacker_wins, total_attacker_battle_wins, total_defender_battle_wins, float(total_duration) / config.test_count)
            _save_test_results(config, ratio, results)
            print("finished ratio")
        print("finished config")
    print("finished all")


