extends CharacterBody3D

# ВАЖНО: При внесении изменений в отображение элементов (таких как ID, полоска здоровья и т.д.),
# не забывайте вносить соответствующие изменения в префабы Card3D.tscn.
# Изменения только в этом скрипте применятся только к экземплярам, но не сохранятся в префабах.
# Для постоянного эффекта изменяйте префабы, а не только скрипт!

# Сигнал для уведомления о гибели карты
signal card_died

# Загружаем вспомогательные скрипты
const PathfindingHelper = preload("res://scripts/PathfindingHelper.gd")
const MovementHelper = preload("res://scripts/MovementHelper.gd")
const EnemyCard3D = preload("res://scripts/EnemyCard3D.gd")

var move_speed: float = 5.0
var target_position: Vector3 = Vector3.ZERO
var is_moving: bool = false
var is_fighting: bool = false
var attack_damage: float = 5.0
var attack_cooldown: float = 1.0  # Время между атаками
var current_cooldown: float = 0.0
var combat_offset: float = 1  # Увеличиваем расстояние между картами в бою

var max_health: float = 100.0
var current_health: float = 100.0

var health_bar: Node3D
var health_label: Label3D  # Используем Label3D для полоски здоровья
var id_label: Label3D  # Добавляем метку для отображения ID

var original_cell_position: Vector3  # Позиция центра ячейки
var combat_target: Node  # Цель для атаки
var enemy_ref: WeakRef  # Слабая ссылка на врага для предотвращения потери цели

# Параметры карты из JSON
var card_id: String = ""
var card_attack: float = 0.0
var card_health: float = 0.0
var card_critical_attack: float = 0.0
var card_type: String = ""
var card_super_ability: String = ""

# Система перемещения
var movement_path: Array = []  # Путь как массив позиций
var is_moving_along_path: bool = false
var current_path_index: int = 0

# Переменные для кругового позиционирования
var _attacker_index: int = 0
var _total_attackers: int = 1
var position_fixed: bool = false
var target_offset: Vector3 = Vector3.ZERO
var target_id: String = ""  # ID цели для координации

func _ready():
	# Устанавливаем слой коллизии для карты
	collision_layer = 1  # Слой 1 для карт
	collision_mask = 1   # Маска для взаимодействия с другими картами

	# Находим дочерние узлы, если они существуют
	if has_node("HealthBar"):
		health_bar = $HealthBar
		health_label = $HealthBar  # Теперь HealthBar сам является Label3D

		# Устанавливаем параметры для полоски здоровья
		health_label.text = "████"
		health_label.font_size = 32
		health_label.outline_size = 0
		# Устанавливаем режим billboarding, чтобы полоска всегда была повёрнута к камере
		health_label.billboard = 1
	else:
		health_bar = null
		health_label = null

	if has_node("IDLabel"):
		id_label = $IDLabel
	else:
		id_label = null

	# Инициализируем здоровье
	update_health_bar()

	# Отображаем ID карты
	if id_label:
		id_label.text = card_id
		# Увеличиваем размер шрифта
		id_label.font_size = 48
		# Устанавливаем жёлтый цвет
		id_label.modulate = Color.YELLOW
		# Убеждаемся, что режим billboarding включен
		id_label.billboard = 1
		# Поднимаем ID выше над капсулой
		id_label.position.y += 0.5

func _physics_process(delta):
	# Обрабатываем движение с помощью вспомогательного скрипта
	MovementHelper.handle_movement_physics(self, delta)

	# Если мы движемся к врагу, обновляем целевую позицию
	if is_moving and is_fighting and combat_target and is_instance_valid(combat_target):
		update_target_position()

	# Обрабатываем бой
	if is_fighting and combat_target and is_instance_valid(combat_target):
		# Проверяем, что текущая карта жива
		if current_health <= 0:
			# Текущая карта мертва, прекращаем бой
			if not has_meta("debug_self_dead_printed"):
				print("DEBUG: ", name, " is dead, stopping combat")
				set_meta("debug_self_dead_printed", true)
			stop_combat()
			return

		# Проверяем, что цель жива
		if combat_target.current_health <= 0:
			# Цель мертва, прекращаем бой
			if not has_meta("debug_target_dead_printed"):
				print("DEBUG: Target ", combat_target.name, " is dead, stopping combat for ", name)
				set_meta("debug_target_dead_printed", true)
			stop_combat()
			return

		# Отслеживаем расстояние до цели во время боя
		var distance_to_target = global_position.distance_to(combat_target.global_position)

		# Проверяем, не слишком ли мы близко к цели
		if distance_to_target < combat_offset:
			# Если мы слишком близко, отходим на исходную позицию
			var direction_away = (global_position - combat_target.global_position).normalized()
			var desired_position = combat_target.global_position + direction_away * combat_offset
			move_to(desired_position)

		current_cooldown -= delta
		if current_cooldown <= 0:
			# Дополнительная проверка перед атакой
			if is_instance_valid(combat_target):
				# Создаем спрайт кулака
				create_fist_sprite()
				# Атакуем противника
				combat_target.take_damage(attack_damage)
				# Проверяем, выжила ли цель после атаки
				if is_instance_valid(combat_target) and combat_target.current_health > 0:
					current_cooldown = attack_cooldown
				else:
					# Цель погибла, прекращаем бой
					if not has_meta("debug_target_killed_printed"):
						print("DEBUG: Target ", combat_target.name, " was killed by ", name)
						set_meta("debug_target_killed_printed", true)
					stop_combat()
			else:
				# Цель исчезла, прекращаем бой
				if not has_meta("debug_target_invalid_printed"):
					print("DEBUG: Target became invalid for ", name)
					set_meta("debug_target_invalid_printed", true)
				stop_combat()
	else:
		# Отладочная информация о том, почему не обрабатывается бой
		if is_fighting and not has_meta("debug_not_fighting_printed"):
			if not combat_target:
				print("DEBUG: ", name, " is_fighting=true but combat_target=null")
				set_meta("debug_not_fighting_printed", true)
			elif not is_instance_valid(combat_target):
				print("DEBUG: ", name, " is_fighting=true but combat_target is not valid")
				set_meta("debug_not_fighting_printed", true)

		# Проверяем, была ли цель удалена из сцены
		if is_fighting and combat_target and not is_instance_valid(combat_target):
			if not has_meta("debug_target_removed_printed"):
				print("DEBUG: Target was removed from scene for ", name)
				set_meta("debug_target_removed_printed", true)
			stop_combat()

# Функция для получения урона
func take_damage(damage: float):
	if not has_meta("debug_take_damage_printed"):
		print("DEBUG: ", name, " taking damage: ", damage, ", current health: ", current_health)
		print("DEBUG: Before taking damage - is_fighting: ", is_fighting, ", combat_target: ", combat_target.name if combat_target else "null")
		set_meta("debug_take_damage_printed", true)

	current_health -= damage
	update_health_bar()

	# Проверяем, что полоска здоровья пустая, и удаляем капсулу в этом случае
	if health_label and health_label.text == "[      ]":
		# Проверяем, находится ли карта в бою, и если да, то есть ли шанс выжить при взаимном уничтожении
		if is_fighting and combat_target and is_instance_valid(combat_target):
			# Проверяем, что у цели тоже пустая полоска здоровья (взаимное уничтожение)
			if combat_target.health_label and combat_target.health_label.text == "[      ]":
				# 10% шанс, что обе карты умрут одновременно
				if randf() < 0.1:
					die()
					combat_target.die()
					return
				# В остальных случаях одна карта выживает
				else:
					# Эта карта выживает с минимальным здоровьем для отображения полоски
					current_health = max_health * 0.17  # Немного больше 1/6 для отображения одного блока
					update_health_bar()
					return
		die()
	# Также проверяем стандартное условие здоровья <= 0
	elif current_health <= 0:
		# Аналогичная проверка для случая, когда здоровье <= 0
		if is_fighting and combat_target and is_instance_valid(combat_target):
			# Проверяем, что у цели тоже здоровье <= 0
			if combat_target.current_health <= 0:
				# 10% шанс, что обе карты умрут одновременно
				if randf() < 0.1:
					die()
					combat_target.die()
					return
				# В остальных случаях одна карта выживает
				else:
					# Эта карта выживает с минимальным здоровьем для отображения полоски
					current_health = max_health * 0.17  # Немного больше 1/6 для отображения одного блока
					update_health_bar()
					return
		die()

# Функция для обновления полоски здоровья
func update_health_bar():
	if health_label:
		# Рассчитываем процент здоровья
		var health_percent = max(0, current_health / max_health)

		# Создаем визуальную полоску здоровья с использованием символа блока
		var bar_length = 6  # Уменьшаем длину полоски в символах
		var filled_length = int(bar_length * health_percent)

		# Создаем полоску с использованием символа блока для заполненной части
		# и пробела для пустой части, обрамленную скобками
		var health_text = "["
		for i in range(bar_length):
			if i < filled_length:
				health_text += "█"  # Заполненная часть
			else:
				health_text += " "  # Пустая часть
		health_text += "]"

		health_label.text = health_text

		# Убеждаемся, что режим billboarding включен
		health_label.billboard = 1

		# Плавно меняем цвет в зависимости от количества здоровья
		if health_percent > 0.6:
			health_label.modulate = Color.GREEN
		elif health_percent > 0.3:
			health_label.modulate = Color.YELLOW
		else:
			health_label.modulate = Color.RED

# Функция для смерти карты
func die():
	# Отладочная информация перед смертью
	if not has_meta("debug_die_printed"):
		print("DEBUG: ", name, " is dying")
		print("DEBUG: Before die - is_fighting: ", is_fighting, ", combat_target: ", combat_target.name if combat_target else "null")
		set_meta("debug_die_printed", true)

	# Если мы в бою, прекращаем бой
	if is_fighting and combat_target and is_instance_valid(combat_target):
		stop_combat()

	# Уведомляем всех, кто атакует нас, о прекращении боя
	var cards = get_tree().get_nodes_in_group("cards")
	for card in cards:
		if card != self and card.is_fighting and card.combat_target == self:
			card.stop_combat()

	# Уведомляем о смерти
	emit_signal("card_died", self)

	# Очищаем сохраненные позиции
	if target_id != "":
		PathfindingHelper.clear_target_positions(self)

	# Удаляем карту из сцены
	queue_free()

# Функция для начала боя
func start_combat(target: Node, cell_pos: Vector3):
	# Проверяем, что цель существует
	if !is_instance_valid(target):
		if not has_meta("debug_invalid_target_printed"):
			print("DEBUG: start_combat called with invalid target for ", name)
			set_meta("debug_invalid_target_printed", true)
		return

	if not has_meta("debug_starting_combat_printed"):
		print("DEBUG: ", name, " starting combat with ", target.name, " at position ", target.global_position)
		print("DEBUG: Before starting combat - is_fighting: ", is_fighting, ", combat_target: ", combat_target if combat_target else "null")
		set_meta("debug_starting_combat_printed", true)

	combat_target = target
	original_cell_position = cell_pos
	is_fighting = true
	current_cooldown = 0.0  # Сбрасываем таймер атаки

	# Проверяем, что combat_target установлен правильно
	if not has_meta("debug_combat_target_set_printed"):
		print("DEBUG: After setting combat_target - is_fighting: ", is_fighting, ", combat_target: ", combat_target.name if combat_target else "null")
		set_meta("debug_combat_target_set_printed", true)

	# Если цель еще не в бою, инициируем бой с её стороны
	if combat_target and is_instance_valid(combat_target) and not combat_target.is_fighting:
		if not has_meta("debug_initiating_combat_printed"):
			print("DEBUG: Initiating combat from target side for ", combat_target.name)
			set_meta("debug_initiating_combat_printed", true)
		combat_target.start_combat(self, combat_target.global_position)

# Функция для прекращения боя
func stop_combat():
	if not has_meta("debug_stop_combat_printed"):
		print("DEBUG: ", name, " stopping combat")
		print("DEBUG: Before stopping combat - is_fighting: ", is_fighting, ", combat_target: ", combat_target if combat_target else "null")
		set_meta("debug_stop_combat_printed", true)
	is_fighting = false
	combat_target = null
	current_cooldown = 0.0

# Функция для перемещения к указанной позиции
	# Если мы уже в бою, проверяем, не слишком ли близко новая позиция к цели
	if is_fighting and combat_target and is_instance_valid(combat_target):
		var distance_to_combat_target = target_position.distance_to(combat_target.global_position)
		if distance_to_combat_target < combat_offset:
			# Корректируем позицию, чтобы она не была слишком близко к цели
			var direction_away = (target_position - combat_target.global_position).normalized()
			target_position = combat_target.global_position + direction_away * combat_offset

	MovementHelper.move_to(self, target_position)

# Функция для движения по пути
func move_along_path(path: Array):
	MovementHelper.start_movement_along_path(self, path, combat_target)

# Функция для перемещения к следующей точке пути
func move_to_next_path_point():
	MovementHelper.move_to_next_path_point(self, combat_target)

# Функция для перемещения к указанной позиции
func move_to(target_position: Vector3):
	# Отладочная информация перед началом движения
	if not has_meta("debug_move_to_card_printed"):
		print("DEBUG: Card ", name, " move_to called with position ", target_position)
		print("DEBUG: Before move_to - is_fighting: ", is_fighting, ", combat_target: ", combat_target.name if combat_target else "null")
		set_meta("debug_move_to_card_printed", true)

	# Если мы уже в бою, проверяем, не слишком ли близко новая позиция к цели
	if is_fighting and combat_target and is_instance_valid(combat_target):
		var distance_to_combat_target = target_position.distance_to(combat_target.global_position)
		if distance_to_combat_target < combat_offset:
			# Корректируем позицию, чтобы она не была слишком близко к цели
			var direction_away = (target_position - combat_target.global_position).normalized()
			target_position = combat_target.global_position + direction_away * combat_offset
			if not has_meta("debug_position_corrected_printed"):
				print("DEBUG: Position corrected for ", name, " to ", target_position)
				print("DEBUG: Original position was too close to target, distance: ", distance_to_combat_target)
				set_meta("debug_position_corrected_printed", true)

			# Обновляем сохраненную абсолютную позицию после корректировки
			if has_method("_attacker_index"):
				var attacker_idx = _attacker_index
				var target_id = str(combat_target.get_instance_id())
				PathfindingHelper.save_attacker_position(combat_target, attacker_idx, target_position)
				print("DEBUG: Updated saved position for ", name, " to ", target_position)

	MovementHelper.move_to(self, target_position)

# Функция для расчета позиции на окружности вокруг цели
func calculate_circle_position(target: Node, attacker_idx: int, total_attackers_count: int, circle_radius: float = 2.5) -> Vector3:
	return PathfindingHelper.calculate_circle_position(target, attacker_idx, total_attackers_count, circle_radius)

# Функция для поиска ближайшей свободной позиции по краю круга
func find_nearest_free_position(target: Node, attacker_idx: int, total_attackers_count: int, circle_radius: float = 2.5, min_distance: float = 1.2) -> Vector3:
	return PathfindingHelper.find_nearest_free_position(target, self, attacker_idx, total_attackers_count, circle_radius, min_distance)

# Функция для движения к врагу с распределением по кругу
func move_to_enemy(enemy: Node, attacker_idx: int = 0, total_attackers_count: int = 1):
	# Проверяем, что враг все еще существует
	if !is_instance_valid(enemy):
		if not has_meta("debug_invalid_enemy_printed"):
			print("DEBUG: move_to_enemy called with invalid enemy")
			set_meta("debug_invalid_enemy_printed", true)
		return

	# Устанавливаем цель для боя
	combat_target = enemy
	_attacker_index = attacker_idx
	_total_attackers = total_attackers_count

	# Генерируем уникальный ID для координации позиций
	target_id = str(enemy.get_instance_id())

	# Сохраняем ссылку на врага для предотвращения её потери
	enemy_ref = weakref(enemy)

	# Отладочная информация о создании слабой ссылки
	if not has_meta("debug_weakref_created_printed"):
		print("DEBUG: Created WeakRef for ", name, " targeting ", enemy.name)
		set_meta("debug_weakref_created_printed", true)

	# Отладочная информация
	if not has_meta("debug_moving_to_enemy_printed"):
		print("DEBUG: Card ", name, " moving to enemy ", enemy.name, " at position ", enemy.global_position)
		set_meta("debug_moving_to_enemy_printed", true)

	# Рассчитываем позицию атаки с учетом распределения по кругу
	var attack_position = find_nearest_free_position(enemy, attacker_idx, total_attackers_count, combat_offset)

	# Сохраняем абсолютную позицию для этого атакующего
	PathfindingHelper.save_attacker_position(enemy, attacker_idx, attack_position)

	# Отладочная информация о рассчитанной позиции
	if not has_meta("debug_attack_position_printed"):
		print("DEBUG: Calculated attack position: ", attack_position)
		set_meta("debug_attack_position_printed", true)

	# Начинаем движение к врагу
	move_to(attack_position)

	# Устанавливаем флаг, что мы в бою, но бой начнется только при достижении цели
	is_fighting = true

	# Бой начнется автоматически при достижении цели в MovementHelper.handle_movement_physics

# Добавляем функцию для обновления позиции цели во время движения
func update_target_position():
	if is_fighting and combat_target and is_instance_valid(combat_target):
		# Рассчитываем новую позицию атаки с учетом текущей позиции цели
		var new_attack_position = find_nearest_free_position(combat_target, _attacker_index, _total_attackers, combat_offset)

		# Обновляем сохраненную позицию
		PathfindingHelper.save_attacker_position(combat_target, _attacker_index, new_attack_position)

		# Если мы все еще движемся, обновляем целевую позицию
		if is_moving:
			target_position = new_attack_position
			if not has_meta("debug_position_updated_printed"):
				print("DEBUG: Updated target position for ", name, " to ", new_attack_position)
				set_meta("debug_position_updated_printed", true)

# Функция для установки параметров карты из JSON
func set_card_data(data: Dictionary):
	# Заполняем параметры карты из JSON
	card_id = data.get("id", "")
	card_attack = data.get("attack", 0.0)
	card_health = data.get("health", 0.0)
	card_critical_attack = data.get("critical_attack", 0.0)
	card_type = data.get("type", "")
	card_super_ability = data.get("super_ability", "")

	# Устанавливаем параметры боя
	max_health = card_health
	current_health = max_health
	attack_damage = card_attack

	# Обновляем полоску здоровья
	update_health_bar()

	# Отображаем ID карты
	if id_label:
		id_label.text = card_id
		# Увеличиваем размер шрифта
		id_label.font_size = 48
		# Устанавливаем жёлтый цвет
		id_label.modulate = Color.YELLOW
		# Убеждаемся, что режим billboarding включен
		id_label.billboard = 1
		# Поднимаем ID выше над капсулой
		id_label.position.y += 0.5

# Функция для создания спрайта кулака при атаке
func create_fist_sprite():
	# Проверяем, что цель существует и находится на достаточном расстоянии для атаки
	if !combat_target or !is_instance_valid(combat_target):
		return

	# Проверяем расстояние до цели
	var distance_to_target = global_position.distance_to(combat_target.global_position)
	if distance_to_target > combat_offset + 0.5:  # Если цель слишком далеко
		return

	# Создаем импульс атаки
	var attack_pulse_scene = preload("res://Prefabs/AttackPulse.tscn")
	var attack_pulse = attack_pulse_scene.instantiate()

	# Устанавливаем тип атаки (союзник или враг)
	attack_pulse.set_attack_type(self is EnemyCard3D)

	# Добавляем импульс в сцену как дочерний элемент атакующего
	add_child(attack_pulse)

	# Определяем начальную и конечную позиции
	# Начальная позиция - от атакующего
	var start_position = global_position + Vector3.UP * 0.5  # Центр атакующего
	# Конечная позиция - на цели
	var target_position = combat_target.global_position + Vector3.UP * 0.5  # Центр цели

	# Устанавливаем позиции для импульса атаки
	attack_pulse.set_positions(start_position, target_position)
