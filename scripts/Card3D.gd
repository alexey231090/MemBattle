extends CharacterBody3D

# Сигнал для уведомления о гибели карты
signal card_died

var move_speed: float = 5.0
var target_position: Vector3 = Vector3.ZERO
var is_moving: bool = false
var is_fighting: bool = false
var attack_damage: float = 5.0
var attack_cooldown: float = 1.0  # Время между атаками
var current_cooldown: float = 0.0
var combat_offset: float = 1.0  # Увеличиваем расстояние между картами в бою

var max_health: float = 100.0
var current_health: float = 100.0

var health_bar: Node3D
var health_sprite: Sprite3D

var original_cell_position: Vector3  # Позиция центра ячейки
var combat_target: Node  # Цель для атаки

# Система перемещения
var movement_path: Array = []  # Путь как массив позиций
var is_moving_along_path: bool = false
var current_path_index: int = 0

# Переменные для кругового позиционирования
var attacker_index: int = 0
var total_attackers: int = 1
var position_fixed: bool = false
var target_offset: Vector3 = Vector3.ZERO

func _ready():
	# Устанавливаем слой коллизии для карты
	collision_layer = 1  # Слой для карт
	collision_mask = 0   # Не проверяем столкновения с другими объектами
	
	# Создаем полоску здоровья
	setup_health_bar()
	update_health_bar()

func setup_health_bar():
	# Создаем контейнер для полоски здоровья
	health_bar = Node3D.new()
	health_bar.name = "HealthBar"
	add_child(health_bar)
	
	# Поднимаем полоску здоровья над капсулой
	health_bar.position.y = 2.0
	
	# Создаем спрайт для здоровья
	health_sprite = Sprite3D.new()
	health_sprite.name = "HealthSprite"
	health_sprite.pixel_size = 0.01  # Размер пикселя
	health_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED  # Всегда смотрит на камеру
	health_sprite.shaded = false
	health_sprite.double_sided = false
	health_sprite.transparent = true
	health_sprite.no_depth_test = true  # Всегда отображается поверх объектов
	health_bar.add_child(health_sprite)
	
	# Создаем текстуру для полоски здоровья
	var img = Image.create(100, 10, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0.5))  # Фон полоски (полупрозрачный черный)
	
	# Заполняем зеленым цветом
	for x in range(100):
		for y in range(10):
			if y >= 2 and y <= 7:  # Оставляем рамку в 2 пикселя
				img.set_pixel(x, y, Color(0, 1, 0, 1))  # Зеленый цвет
	
	var texture = ImageTexture.create_from_image(img)
	health_sprite.texture = texture

func update_health_bar():
	if health_sprite and health_sprite.texture:
		var health_percent = current_health / max_health
		health_sprite.scale.x = health_percent  # Масштабируем спрайт по X в зависимости от здоровья

# Функция для изменения здоровья
func set_health(new_health: float):
	current_health = clamp(new_health, 0, max_health)
	update_health_bar()

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

func stop_combat():
	is_fighting = false
	combat_target = null
	position_fixed = false  # Сбрасываем фиксацию позиции
	# Не возвращаемся на исходную позицию, чтобы система переназначения целей могла найти новую цель

func take_damage(amount: float):
	set_health(current_health - amount)
	if current_health <= 0:
		die()

func die():
	# Уведомляем о гибели карты
	card_died.emit()
	queue_free()

func move_along_path(path: Array):
	if path.size() > 0:
		movement_path = path
		current_path_index = 0
		is_moving_along_path = true
		# Начинаем движение к первой точке
		move_to_next_path_point()

func move_to_next_path_point():
	if current_path_index < movement_path.size():
		var next_pos = movement_path[current_path_index]
		move_to(next_pos)
	else:
		is_moving_along_path = false
		movement_path.clear()
		# Если есть цель для боя, начинаем бой с текущей позиции
		if combat_target and is_instance_valid(combat_target):
			start_combat(combat_target, global_position)

func _physics_process(delta):
	if is_moving:
		# Проверяем цель во время движения
		if combat_target and is_instance_valid(combat_target) and combat_target.current_health <= 0:
			# Цель мертва, прекращаем движение
			is_moving = false
			velocity = Vector3.ZERO
			stop_combat()
			return
		
		# Обновляем целевую позицию во время движения (если есть combat_target и позиция не зафиксирована)
		if combat_target and is_instance_valid(combat_target) and not position_fixed:
			# Пересчитываем позицию по кругу
			var new_target_position = calculate_circle_position(combat_target, attacker_index, total_attackers)
			target_position = new_target_position
		elif position_fixed and combat_target and is_instance_valid(combat_target):
			# Обновляем позицию относительно движущейся цели
			target_position = combat_target.global_position + target_offset
			
		var direction = (target_position - global_position)
		if direction.length() > 0.1:
			velocity = direction.normalized() * move_speed
			move_and_slide()
		else:
			is_moving = false
			global_position = target_position
			
			# Если движемся по пути, переходим к следующей точке
			if is_moving_along_path:
				current_path_index += 1
				move_to_next_path_point()
		# --- ОСТАНАВЛИВАЕМСЯ, ЕСЛИ ДОСТИГЛИ ЦЕЛЕВОЙ ПОЗИЦИИ ИЛИ БЛИЗКО К ВРАГУ ---
	if is_moving and combat_target and is_instance_valid(combat_target):
		# Проверяем, что цель все еще жива
		if combat_target.current_health <= 0:
			# Цель мертва, прекращаем движение и бой
			is_moving = false
			velocity = Vector3.ZERO
			stop_combat()
			return
			
		# Проверяем, достигли ли мы целевой позиции
		if global_position.distance_to(target_position) <= 0.5:
			is_moving = false
			velocity = Vector3.ZERO
			start_combat(combat_target, global_position)
	
	if is_fighting and combat_target and is_instance_valid(combat_target):
		# Проверяем, что цель жива
		if combat_target.current_health <= 0:
			# Цель мертва, прекращаем бой
			stop_combat()
			return
			
		current_cooldown -= delta
		if current_cooldown <= 0:
			# Дополнительная проверка перед атакой
			if is_instance_valid(combat_target):
				# Атакуем противника
				combat_target.take_damage(attack_damage)
				current_cooldown = attack_cooldown
			else:
				# Цель погибла, прекращаем бой
				stop_combat()

func move_to(pos: Vector3):
	target_position = pos
	is_moving = true

# Функция для расчета точки встречи двух движущихся объектов
func calculate_interception_point(target: Node, my_speed: float, target_speed: float = 0.0) -> Vector3:
	if !is_instance_valid(target):
		return global_position
	
	# Если цель не движется, идем прямо к ней
	if target_speed <= 0.0 or not target.has_method("get_velocity") or target.get_velocity().length() < 0.1:
		return target.global_position
	
	var target_velocity = target.get_velocity()
	var relative_position = target.global_position - global_position
	var relative_velocity = target_velocity
	
	# Рассчитываем время до встречи
	var a = target_velocity.length_squared() - my_speed * my_speed
	var b = 2.0 * relative_position.dot(target_velocity)
	var c = relative_position.length_squared()
	
	var discriminant = b * b - 4.0 * a * c
	if discriminant < 0:
		# Нет решения, идем прямо к цели
		return target.global_position
	
	var time = (-b - sqrt(discriminant)) / (2.0 * a)
	if time < 0:
		time = (-b + sqrt(discriminant)) / (2.0 * a)
	
	# Рассчитываем позицию встречи
	var interception_point = target.global_position + target_velocity * time
	return interception_point

# Функция для расчета позиции по кругу вокруг цели
func calculate_circle_position(target: Node, attacker_index: int, total_attackers: int, closest_attacker_position: Vector3 = Vector3.ZERO, circle_radius: float = 1.2) -> Vector3:
	if !is_instance_valid(target):
		return global_position
	
	# Если только один атакующий, он идет прямо к цели
	if total_attackers == 1:
		var direction = (target.global_position - global_position).normalized()
		return target.global_position - direction * circle_radius
	
	# Первый атакующий (индекс 0) идет в ближайшую точку к врагу
	if attacker_index == 0:
		var direction = (target.global_position - global_position).normalized()
		return target.global_position - direction * circle_radius
	
	# Остальные атакующие равномерно распределяются по кругу вокруг врага
	# Начинаем с угла первого атакующего и распределяем остальных
	var first_attacker_direction = (target.global_position - global_position).normalized()
	var first_angle = atan2(first_attacker_direction.z, first_attacker_direction.x)
	
	# Распределяем остальных атакующих по кругу
	var angle_step = 2.0 * PI / total_attackers
	var current_angle = first_angle + (attacker_index * angle_step)
	
	# Рассчитываем позицию на окружности вокруг врага
	var circle_pos = Vector3(
		target.global_position.x + cos(current_angle) * circle_radius,
		target.global_position.y,  # Сохраняем ту же высоту
		target.global_position.z + sin(current_angle) * circle_radius
	)
	
	return circle_pos

func move_to_enemy(enemy: Node, attacker_index: int = 0, total_attackers: int = 1):
	# Проверяем, что враг все еще существует
	if !is_instance_valid(enemy):
		return
	
	# Сохраняем параметры позиционирования
	self.attacker_index = attacker_index
	self.total_attackers = total_attackers
	
	combat_target = enemy
	is_fighting = true
	current_cooldown = 0.0
	
	# Рассчитываем позицию по кругу вокруг врага
	var circle_position = calculate_circle_position(enemy, attacker_index, total_attackers)
	
	# Сохраняем смещение относительно цели
	target_offset = circle_position - enemy.global_position
	position_fixed = true
	
	target_position = circle_position
	is_moving = true 
