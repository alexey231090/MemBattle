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
		if closest_enemy.size() > 0:
			if not battle_assignments.enemy_to_allies.has(closest_enemy):
				battle_assignments.enemy_to_allies[closest_enemy] = []
			battle_assignments.enemy_to_allies[closest_enemy].append(ally)
			print("Бой: ", ally.card.name, " -> ", closest_enemy.card.name)
	
	# Враги ищут ближайших союзников
	for enemy in enemies:
		if !is_instance_valid(enemy.card):
			continue
		var closest_ally = find_closest_target(enemy.card, allies)
		if closest_ally.size() > 0:
			if not battle_assignments.ally_to_enemies.has(closest_ally):
				battle_assignments.ally_to_enemies[closest_ally] = []
			battle_assignments.ally_to_enemies[closest_ally].append(enemy)
			print("Бой: ", enemy.card.name, " -> ", closest_ally.card.name)
	
	return battle_assignments

# Функция для поиска новых целей для карт, у которых цель погибла
func find_new_targets_for_orphaned_cards(allies: Array, enemies: Array):
	print("Проверяем карты без целей. Союзников: ", allies.size(), ", Врагов: ", enemies.size())
	
	# Дополнительная фильтрация - убираем мертвые карты
	allies = allies.filter(func(ally): return is_instance_valid(ally.card))
	enemies = enemies.filter(func(enemy): return is_instance_valid(enemy.card))
	
	# Создаем временные назначения для новых целей
	var new_assignments = {
		"enemy_to_allies": {},
		"ally_to_enemies": {}
	}
	
	# Проверяем союзников без целей
	for ally in allies:
		if !is_instance_valid(ally.card):
			continue
		# Если карта не в бою, её цель погибла, или цель мертва
		if not ally.card.is_fighting or not is_instance_valid(ally.card.combat_target) or (ally.card.combat_target and ally.card.combat_target.current_health <= 0):
			print("Союзник ", ally.card.name, " без цели. is_fighting: ", ally.card.is_fighting, ", combat_target: ", ally.card.combat_target)
			var new_target = find_closest_target(ally.card, enemies)
			if new_target.size() > 0 and is_instance_valid(new_target.card):
				print("Новая цель: ", ally.card.name, " -> ", new_target.card.name)
				# Добавляем в временные назначения
				if not new_assignments.enemy_to_allies.has(new_target):
					new_assignments.enemy_to_allies[new_target] = []
				new_assignments.enemy_to_allies[new_target].append(ally)
	
	# Проверяем врагов без целей
	for enemy in enemies:
		if !is_instance_valid(enemy.card):
			continue
		# Если карта не в бою, её цель погибла, или цель мертва
		if not enemy.card.is_fighting or not is_instance_valid(enemy.card.combat_target) or (enemy.card.combat_target and enemy.card.combat_target.current_health <= 0):
			print("Враг ", enemy.card.name, " без цели. is_fighting: ", enemy.card.is_fighting, ", combat_target: ", enemy.card.combat_target)
			var new_target = find_closest_target(enemy.card, allies)
			if new_target.size() > 0 and is_instance_valid(new_target.card):
				print("Новая цель: ", enemy.card.name, " -> ", new_target.card.name)
				# Добавляем в временные назначения
				if not new_assignments.ally_to_enemies.has(new_target):
					new_assignments.ally_to_enemies[new_target] = []
				new_assignments.ally_to_enemies[new_target].append(enemy)
	
	# Выполняем новые назначения с круговым позиционированием
	execute_battle(new_assignments)

# Функция для поиска ближайшей цели
func find_closest_target(attacker_card: Node, targets: Array) -> Dictionary:
	var closest_target = null
	var min_distance = INF
	
	# Проверяем, что атакующая карта все еще существует
	if !is_instance_valid(attacker_card):
		return {}
	
	for target in targets:
		if !is_instance_valid(target.card):
			continue
		# Дополнительная проверка - убеждаемся, что цель жива
		if target.card.current_health <= 0:
			continue
		var distance = attacker_card.global_position.distance_to(target.card.global_position)
		if distance < min_distance:
			min_distance = distance
			closest_target = target
	
	return closest_target if closest_target else {}

# Функция для выполнения боевых действий
func execute_battle(battle_assignments: Dictionary):
	# Союзники атакуют врагов
	for enemy in battle_assignments.enemy_to_allies.keys():
		var attackers = battle_assignments.enemy_to_allies[enemy]
		# Сортируем атакующих по расстоянию до цели (ближайшие первыми)
		attackers.sort_custom(func(a, b): 
			return a.card.global_position.distance_to(enemy.card.global_position) < b.card.global_position.distance_to(enemy.card.global_position)
		)
		

		
		for i in range(attackers.size()):
			var attacker = attackers[i]
			if !is_instance_valid(attacker.card):
				continue
			attacker.card.move_to_enemy(enemy.card, i, attackers.size())
	
	# Враги атакуют союзников
	for ally in battle_assignments.ally_to_enemies.keys():
		var attackers = battle_assignments.ally_to_enemies[ally]
		# Сортируем атакующих по расстоянию до цели (ближайшие первыми)
		attackers.sort_custom(func(a, b): 
			return a.card.global_position.distance_to(ally.card.global_position) < b.card.global_position.distance_to(ally.card.global_position)
		)
		

		
		for i in range(attackers.size()):
			var attacker = attackers[i]
			if !is_instance_valid(attacker.card):
				continue
			attacker.card.move_to_enemy(ally.card, i, attackers.size()) 
