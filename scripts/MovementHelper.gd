extends Node

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
	if mover.current_path_index < mover.movement_path.size():
		var next_pos = mover.movement_path[mover.current_path_index]
		move_to(mover, next_pos)
	else:
		# Путь завершен
		mover.is_moving_along_path = false
		mover.movement_path.clear()
		# Если есть цель для боя, начинаем бой с текущей позиции
		if combat_target and is_instance_valid(combat_target):
			mover.start_combat(combat_target, mover.global_position)

# Функция для перемещения к указанной позиции
static func move_to(mover: Node, position: Vector3):
	mover.target_position = position
	mover.is_moving = true

# Функция для обработки физического процесса перемещения
static func handle_movement_physics(mover: Node, delta: float):
	if mover.is_moving:
		# Проверяем, что цель все еще существует
		if mover.combat_target and is_instance_valid(mover.combat_target):
			# Проверяем, что цель все еще жива
			if mover.combat_target.current_health <= 0:
				# Цель мертва, прекращаем движение и бой
				print("Target is dead, stopping movement")
				mover.is_moving = false
				mover.velocity = Vector3.ZERO
				if mover.has_method("stop_combat"):
					mover.stop_combat()
				return
		else:
			# Цель исчезла, прекращаем движение
			print("Target disappeared, stopping movement")
			mover.is_moving = false
			mover.velocity = Vector3.ZERO
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
			mover.is_moving = false
			mover.velocity = Vector3.ZERO

			# Если мы двигались по пути, переходим к следующей точке
			if mover.is_moving_along_path:
				mover.current_path_index += 1
				move_to_next_path_point(mover, mover.combat_target)
