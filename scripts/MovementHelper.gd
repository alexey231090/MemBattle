extends Node

# Загружаем вспомогательные скрипты
const PathfindingHelper = preload("res://scripts/PathfindingHelper.gd")

# Функция для инициализации движения по пути
static func start_movement_along_path(mover: Node, path: Array, combat_target: Node = null):
	if path.size() > 0:
		# Устанавливаем путь
		mover.movement_path = path
		mover.current_path_index = 0
		mover.is_moving_along_path = true
		# Начинаем движение к первой точке
		move_to_next_path_point(mover, combat_target)

# Функция для перемещения к следующей точке пути
static func move_to_next_path_point(mover: Node, combat_target: Node = null):
	# Проверяем, что цель все еще существует через слабую ссылку
	var real_target = null
	if mover.has_method("enemy_ref") and mover.enemy_ref:
		real_target = mover.enemy_ref.get_ref()

	# Если цель существует через слабую ссылку, обновляем combat_target
	if real_target and is_instance_valid(real_target):
		combat_target = real_target
		mover.combat_target = real_target

	if mover.current_path_index < mover.movement_path.size():
		var next_pos = mover.movement_path[mover.current_path_index]
		if not mover.has_meta("debug_moving_to_path_point_printed"):
			print("DEBUG: ", mover.name, " moving to next path point ", mover.current_path_index, " of ", mover.movement_path.size(), " at position ", next_pos)
			mover.set_meta("debug_moving_to_path_point_printed", true)
		move_to(mover, next_pos)
	else:
		# Путь завершен
		if not mover.has_meta("debug_path_completed_printed"):
			print("DEBUG: Path completed for ", mover.name)
			mover.set_meta("debug_path_completed_printed", true)
		mover.is_moving_along_path = false
		mover.movement_path.clear()
		# Если есть цель для боя, начинаем бой с текущей позиции
		if combat_target and is_instance_valid(combat_target):
			if not mover.has_meta("debug_combat_after_path_printed"):
				print("DEBUG: Starting combat after path completion for ", mover.name, " with target ", combat_target.name)
				mover.set_meta("debug_combat_after_path_printed", true)
			mover.start_combat(combat_target, mover.global_position)
		else:
			# Цель исчезла, прекращаем бой
			if not mover.has_meta("debug_target_disappeared_path_printed"):
				print("DEBUG: Target disappeared when path completed for ", mover.name)
				mover.set_meta("debug_target_disappeared_path_printed", true)
			if mover.has_method("stop_combat"):
				mover.stop_combat()

# Функция для перемещения к указанной позиции
static func move_to(mover: Node, position: Vector3):
	# Отладочная информация перед началом движения
	if not mover.has_meta("debug_move_to_printed"):
		print("DEBUG: ", mover.name, " moving to position ", position)
		print("DEBUG: Before move_to - is_moving: ", mover.is_moving, ", target_position: ", mover.target_position, ", combat_target: ", mover.combat_target.name if mover.combat_target else "null")
		mover.set_meta("debug_move_to_printed", true)

	mover.target_position = position
	mover.is_moving = true

	# Отладочная информация после начала движения
	if not mover.has_meta("debug_move_to_after_printed"):
		print("DEBUG: After move_to - is_moving: ", mover.is_moving, ", target_position: ", mover.target_position, ", combat_target: ", mover.combat_target.name if mover.combat_target else "null")
		mover.set_meta("debug_move_to_after_printed", true)

# Функция для обработки физического процесса перемещения
static func handle_movement_physics(mover: Node, delta: float):
	if mover.is_moving:
		# Проверяем, что цель все еще существует через слабую ссылку
		var real_target = null
		if mover.has_method("enemy_ref") and mover.enemy_ref:
			real_target = mover.enemy_ref.get_ref()

			# Отладочная информация о состоянии слабой ссылки
			if real_target == null and not mover.has_meta("debug_weakref_null_printed"):
				print("DEBUG: WeakRef is null for ", mover.name)
				mover.set_meta("debug_weakref_null_printed", true)

		# Если цель существует через слабую ссылку, обновляем combat_target
		if real_target and is_instance_valid(real_target):
			mover.combat_target = real_target

		# Проверяем, что цель все еще существует
		if mover.combat_target and is_instance_valid(mover.combat_target):
			# Проверяем, что цель все еще жива
			if mover.combat_target.current_health <= 0:
				# Цель мертва, прекращаем движение и бой
				if not mover.has_meta("debug_dead_target_printed"):
					print("DEBUG: Target is dead, stopping movement for ", mover.name)
					mover.set_meta("debug_dead_target_printed", true)
				mover.is_moving = false
				mover.velocity = Vector3.ZERO
				if mover.has_method("stop_combat"):
					mover.stop_combat()
				return

			# Если мы в бою и цель двигается, обновляем нашу целевую позицию
			if mover.is_fighting and mover.has_method("_attacker_index") and mover.has_method("_total_attackers"):
				# Получаем сохраненную абсолютную позицию для этого атакующего
				var target_id = str(mover.combat_target.get_instance_id())
				var attacker_idx = mover._attacker_index if mover.has_method("_attacker_index") else 0

				# Проверяем, есть ли сохраненная позиция
				if PathfindingHelper.target_positions.has(target_id) and PathfindingHelper.target_positions[target_id].has(attacker_idx):
					# Используем сохраненную абсолютную позицию
					var saved_position = PathfindingHelper.target_positions[target_id][attacker_idx]

					# Отладочная информация при обновлении позиции
					if not mover.target_position.is_equal_approx(saved_position):
						print("DEBUG: Updating target position for ", mover.name, " from ", mover.target_position, " to saved position ", saved_position)
						print("DEBUG: Enemy position: ", mover.combat_target.global_position)

					# Обновляем целевую позицию только если она отличается от сохраненной
					if not mover.target_position.is_equal_approx(saved_position):
						mover.target_position = saved_position
		else:
			# Цель исчезла, прекращаем движение
			if not mover.has_meta("debug_target_disappeared_printed"):
				print("DEBUG: Target disappeared, stopping movement for ", mover.name)
				if mover.combat_target:
					print("DEBUG: combat_target exists but is not valid for ", mover.name)
				else:
					print("DEBUG: combat_target is null for ", mover.name)
				mover.set_meta("debug_target_disappeared_printed", true)
			mover.is_moving = false
			mover.velocity = Vector3.ZERO
			if mover.has_method("stop_combat"):
				mover.stop_combat()
			return

		# Вычисляем направление к цели
		var direction = (mover.target_position - mover.global_position).normalized()
		var distance_to_target = mover.global_position.distance_to(mover.target_position)

		# Устанавливаем скорость
		mover.velocity = direction * mover.move_speed

		# Двигаемся
		if mover.has_method("move_and_slide"):
			mover.move_and_slide()
		else:
			mover.global_position += mover.velocity * delta

		# Проверяем, достигли ли мы цели
		if distance_to_target <= 0.3:
			if not mover.has_meta("debug_target_reached_printed"):
				print("DEBUG: Reached target position for ", mover.name)
				mover.set_meta("debug_target_reached_printed", true)
			mover.is_moving = false
			mover.velocity = Vector3.ZERO

			# Если мы двигались по пути, переходим к следующей точке
			if mover.is_moving_along_path:
				mover.current_path_index += 1
				move_to_next_path_point(mover, mover.combat_target)
			# Если есть цель для боя, начинаем бой с текущей позиции
			elif mover.combat_target and is_instance_valid(mover.combat_target) and mover.is_fighting:
				if mover.has_method("start_combat"):
					if not mover.has_meta("debug_starting_combat_printed"):
						print("DEBUG: Starting combat for ", mover.name, " with target ", mover.combat_target.name)
						mover.set_meta("debug_starting_combat_printed", true)
					mover.start_combat(mover.combat_target, mover.global_position)
