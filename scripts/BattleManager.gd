extends Node

# Менеджер боевой логики
class_name BattleManager

# Функция для поиска ближайших противников и назначения целей
func find_battle_targets(allies: Array, enemies: Array) -> Dictionary:
	var battle_assignments = {
		"enemy_to_allies": {},  # Враги -> атакующие их союзники
		"ally_to_enemies": {}   # Союзники -> атакующие их враги
	}
	
	# Союзники ищут ближайших врагов
	for ally in allies:
		if !is_instance_valid(ally.card):
			continue
		var closest_enemy = find_closest_target(ally.card, enemies)
		if closest_enemy:
			if not battle_assignments.enemy_to_allies.has(closest_enemy):
				battle_assignments.enemy_to_allies[closest_enemy] = []
			battle_assignments.enemy_to_allies[closest_enemy].append(ally)
			print("Союзник ", ally.card.name, " атакует врага ", closest_enemy.card.name, " (расстояние: ", ally.card.global_position.distance_to(closest_enemy.card.global_position), ")")
	
	# Враги ищут ближайших союзников
	for enemy in enemies:
		if !is_instance_valid(enemy.card):
			continue
		var closest_ally = find_closest_target(enemy.card, allies)
		if closest_ally:
			if not battle_assignments.ally_to_enemies.has(closest_ally):
				battle_assignments.ally_to_enemies[closest_ally] = []
			battle_assignments.ally_to_enemies[closest_ally].append(enemy)
			print("Враг ", enemy.card.name, " атакует союзника ", closest_ally.card.name, " (расстояние: ", enemy.card.global_position.distance_to(closest_ally.card.global_position), ")")
	
	return battle_assignments

# Функция для поиска ближайшей цели
func find_closest_target(attacker_card: Node, targets: Array) -> Dictionary:
	var closest_target = null
	var min_distance = INF
	
	for target in targets:
		if !is_instance_valid(target.card):
			continue
		var distance = attacker_card.global_position.distance_to(target.card.global_position)
		if distance < min_distance:
			min_distance = distance
			closest_target = target
	
	return closest_target

# Функция для выполнения боевых действий
func execute_battle(battle_assignments: Dictionary):
	# Союзники атакуют врагов
	for enemy in battle_assignments.enemy_to_allies.keys():
		var attackers = battle_assignments.enemy_to_allies[enemy]
		for attacker in attackers:
			if !is_instance_valid(attacker.card):
				continue
			attacker.card.move_to_enemy(enemy.card)
	
	# Враги атакуют союзников
	for ally in battle_assignments.ally_to_enemies.keys():
		var attackers = battle_assignments.ally_to_enemies[ally]
		for attacker in attackers:
			if !is_instance_valid(attacker.card):
				continue
			attacker.card.move_to_enemy(ally.card) 