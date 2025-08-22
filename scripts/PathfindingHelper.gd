extends Node

# Статическая переменная для координации позиций атакующих
static var target_positions: Dictionary = {}

# Функция для поиска ближайшей свободной позиции по краю круга
static func find_nearest_free_position(target: Node, attacker: Node, attacker_idx: int, total_attackers_count: int, circle_radius: float = 2.5, min_distance: float = 1.2) -> Vector3:
	if !is_instance_valid(target) or !is_instance_valid(attacker):
		return attacker.global_position if is_instance_valid(attacker) else Vector3.ZERO

	# Если только один атакующий, он идет прямо к цели
	if total_attackers_count == 1:
		var direction = (target.global_position - attacker.global_position).normalized()
		var result = target.global_position - direction * circle_radius
		return result

	# Находим направление от атакующего к цели
	var target_pos: Vector3
	var my_pos: Vector3

	if target.is_inside_tree():
		target_pos = target.global_position
	else:
		target_pos = target.position

	if attacker.is_inside_tree():
		my_pos = attacker.global_position
	else:
		my_pos = attacker.position

	var direction_to_target = (target_pos - my_pos).normalized()
	var start_angle = atan2(direction_to_target.z, direction_to_target.x)

	# Проверяем все возможные позиции по кругу
	var best_position = Vector3.ZERO
	var min_total_distance = INF

	# Ищем позиции в секторе 120 градусов вокруг направления к цели (вместо полного круга)
	var search_angle_range = deg_to_rad(120.0)  # 120 градусов в каждую сторону
	var angle_step = deg_to_rad(5.0)  # 5 градусов для точности
	var max_attempts = int(search_angle_range * 2 / angle_step)  # Количество попыток в секторе

	# Начинаем поиск с направления к цели и расширяемся в обе стороны
	for attempt in range(max_attempts):
		# Чередуем поиск влево и вправо от направления к цели
		var offset = (attempt + 1) / 2.0
		var direction = 1 if attempt % 2 == 0 else -1
		var test_angle = start_angle + (direction * offset * angle_step)

		# Ограничиваем поиск сектором
		if abs(test_angle - start_angle) > search_angle_range:
			continue

		# Рассчитываем тестовую позицию
		var test_position = Vector3(
			target_pos.x + cos(test_angle) * circle_radius,
			target_pos.y,
			target_pos.z + sin(test_angle) * circle_radius
		)

		# Проверяем, не занята ли эта позиция другими атакующими
		var is_position_free = true
		var total_distance = my_pos.distance_to(test_position)

		# Проверяем расстояние до других уже назначенных позиций
		var target_id = str(target.get_instance_id())
		if target_positions.has(target_id):
			for i in range(total_attackers_count):
				if i != attacker_idx and target_positions[target_id].has(i):
					var other_offset = target_positions[target_id][i]
					# Важно: используем текущую позицию цели, а не начальную
					var other_position = target_pos + other_offset
					var distance_to_other = test_position.distance_to(other_position)

					if distance_to_other < min_distance:
						is_position_free = false
						break

		# Если позиция свободна и ближе к текущему атакующему
		if is_position_free and total_distance < min_total_distance:
			min_total_distance = total_distance
			best_position = test_position

	# Если не нашли свободную позицию в секторе, используем равномерное распределение
	if best_position == Vector3.ZERO:
		var angle_step_uniform = 2.0 * PI / total_attackers_count
		var current_angle = start_angle + (attacker_idx * angle_step_uniform)
		# Увеличиваем радиус если не можем найти место
		var adjusted_radius = circle_radius * 1.2
		best_position = Vector3(
			target_pos.x + cos(current_angle) * adjusted_radius,
			target_pos.y,
			target_pos.z + sin(current_angle) * adjusted_radius
		)

	return best_position

# Функция для расчета позиции на окружности вокруг цели
static func calculate_circle_position(target: Node, attacker_idx: int, total_attackers_count: int, circle_radius: float = 2.5) -> Vector3:
	if !is_instance_valid(target):
		return Vector3.ZERO

	# Получаем текущую позицию цели
	var target_pos: Vector3
	if target.is_inside_tree():
		target_pos = target.global_position
	else:
		target_pos = target.position

	# Рассчитываем равномерное распределение атакующих по кругу
	var angle_step = 2.0 * PI / total_attackers_count
	var current_angle = attacker_idx * angle_step

	# Рассчитываем позицию на окружности вокруг врага
	var circle_pos = Vector3(
		target_pos.x + cos(current_angle) * circle_radius,
		target_pos.y,  # Сохраняем ту же высоту
		target_pos.z + sin(current_angle) * circle_radius
	)

	return circle_pos

# Функция для сохранения позиции атакующего для координации с другими атакующими
static func save_attacker_position(target: Node, attacker_idx: int, position_offset: Vector3):
	var target_id = str(target.get_instance_id())

	if !target_positions.has(target_id):
		target_positions[target_id] = {}

	target_positions[target_id][attacker_idx] = position_offset

# Функция для очистки сохраненных позиций для цели
static func clear_target_positions(target: Node):
	var target_id = str(target.get_instance_id())
	if target_positions.has(target_id):
		target_positions.erase(target_id)
