extends CharacterBody3D

# Сигнал для уведомления о гибели карты
signal card_died

# Загружаем вспомогательные скрипты
const PathfindingHelper = preload("res://scripts/PathfindingHelper.gd")
const MovementHelper = preload("res://scripts/MovementHelper.gd")

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

func _physics_process(delta):
	# Обрабатываем движение с помощью вспомогательного скрипта
	MovementHelper.handle_movement_physics(self, delta)

	# Обрабатываем бой
	if is_fighting and combat_target and is_instance_valid(combat_target):
		# Проверяем, что текущая карта жива
		if current_health <= 0:
			# Текущая карта мертва, прекращаем бой
			stop_combat()
			return

		# Проверяем, что цель жива
		if combat_target.current_health <= 0:
			# Цель мертва, прекращаем бой
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
					stop_combat()
			else:
				# Цель исчезла, прекращаем бой
				stop_combat()

# Функция для получения урона
func take_damage(damage: float):
	current_health -= damage
	update_health_bar()

	if current_health <= 0:
		die()

# Функция для обновления полоски здоровья
func update_health_bar():
	if health_label:
		# Рассчитываем процент здоровья
		var health_percent = max(0, current_health / max_health)

		# Обновляем текст полоски здоровья в зависимости от процента здоровья
		var full_blocks = int(4 * health_percent)  # Максимум 4 блока
		var health_text = ""
		for i in range(full_blocks):
			health_text += "█"
		health_label.text = health_text

		# Убеждаемся, что режим billboarding включен
		health_label.billboard = 1

		# Меняем цвет в зависимости от количества здоровья
		if health_percent > 0.6:
			health_label.modulate = Color.GREEN
		elif health_percent > 0.3:
			health_label.modulate = Color.YELLOW
		else:
			health_label.modulate = Color.RED

# Функция для смерти карты
func die():
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
		return

	combat_target = target
	original_cell_position = cell_pos
	is_fighting = true
	current_cooldown = 0.0  # Сбрасываем таймер атаки

	# Если цель еще не в бою, инициируем бой с её стороны
	if combat_target and is_instance_valid(combat_target) and not combat_target.is_fighting:
		combat_target.start_combat(self, combat_target.global_position)

# Функция для прекращения боя
func stop_combat():
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
	# Если мы уже в бою, проверяем, не слишком ли близко новая позиция к цели
	if is_fighting and combat_target and is_instance_valid(combat_target):
		var distance_to_combat_target = target_position.distance_to(combat_target.global_position)
		if distance_to_combat_target < combat_offset:
			# Корректируем позицию, чтобы она не была слишком близко к цели
			var direction_away = (target_position - combat_target.global_position).normalized()
			target_position = combat_target.global_position + direction_away * combat_offset

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
		return

	# Устанавливаем цель для боя
	combat_target = enemy
	_attacker_index = attacker_idx
	_total_attackers = total_attackers_count

	# Генерируем уникальный ID для координации позиций
	target_id = str(enemy.get_instance_id())

	# Находим лучшую позицию для атаки
	var best_position = find_nearest_free_position(enemy, attacker_idx, total_attackers_count)

	# Сохраняем позицию для координации с другими атакующими
	var position_offset = best_position - enemy.global_position
	PathfindingHelper.save_attacker_position(enemy, attacker_idx, position_offset)

	# Двигаемся к найденной позиции
	move_to(best_position)

	# Начинаем бой после достижения позиции
	start_combat(enemy, best_position)

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

# Функция для создания спрайта кулака при атаке
func create_fist_sprite():
	# Проверяем, что цель существует и находится на достаточном расстоянии для атаки
	if !combat_target or !is_instance_valid(combat_target):
		return

	# Проверяем расстояние до цели - создаем спрайт только если карты достаточно близко
	var distance_to_target = global_position.distance_to(combat_target.global_position)
	if distance_to_target > combat_offset + 0.5:  # Если цель слишком далеко, не создаем спрайт
		return

	# Загружаем сцену спрайта кулака
	var fist_scene = preload("res://Prefabs/FistSprite.tscn")
	var fist_sprite = fist_scene.instantiate()

	# Добавляем спрайт в сцену как дочерний элемент атакующего
	add_child(fist_sprite)

	# Устанавливаем начальную позицию (немного впереди атакующего)
	var direction_to_target = (combat_target.global_position - global_position).normalized()

	# Начальная позиция - из центра капсулы атакующего
	var center_position = global_position + Vector3.UP * 0.5  # Поднимаем позицию до центра капсулы
	fist_sprite.start_position = center_position
	fist_sprite.global_position = fist_sprite.start_position

	# Устанавливаем целевую позицию - в центр капсулы цели
	var target_center = combat_target.global_position + Vector3.UP * 0.5  # Центр цели
	fist_sprite.target_position = target_center
