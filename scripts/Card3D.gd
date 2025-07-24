extends CharacterBody3D

var move_speed: float = 5.0
var target_position: Vector3 = Vector3.ZERO
var is_moving: bool = false
var is_fighting: bool = false
var attack_damage: float = 5.0
var attack_cooldown: float = 1.0  # Время между атаками
var current_cooldown: float = 0.0
var combat_offset: float = 0.7  # Насколько близко подходят карты друг к другу

var max_health: float = 100.0
var current_health: float = 100.0

var health_bar: Node3D
var health_sprite: Sprite3D

var original_cell_position: Vector3  # Позиция центра ячейки
var combat_target: Node  # Цель для атаки

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
	print(name + ": Здоровье обновлено: " + str(current_health))
	update_health_bar()

func start_combat(target: Node, cell_pos: Vector3):
	print(name + ": Начинаю бой с " + target.name)
	print(name + ": Моя позиция: " + str(global_position) + ", позиция цели: " + str(target.global_position))
	
	combat_target = target
	original_cell_position = cell_pos
	is_fighting = true
	current_cooldown = 0.0  # Сбрасываем таймер атаки
	
	# Вычисляем позицию для боя (смещение к противнику)
	var direction = (combat_target.global_position - global_position).normalized()
	var combat_position = original_cell_position + direction * combat_offset
	print(name + ": Двигаюсь к позиции: " + str(combat_position))
	move_to(combat_position)

func stop_combat():
	print(name + ": Прекращаю бой")
	is_fighting = false
	combat_target = null
	move_to(original_cell_position)  # Возвращаемся в центр ячейки

func take_damage(amount: float):
	print(name + ": Получаю урон: " + str(amount))
	set_health(current_health - amount)
	if current_health <= 0:
		die()

func die():
	print(name + ": Погибаю!")
	queue_free()

func _physics_process(delta):
	if is_moving:
		var direction = (target_position - global_position)
		if direction.length() > 0.1:
			velocity = direction.normalized() * move_speed
			move_and_slide()
		else:
			is_moving = false
			global_position = target_position
			velocity = Vector3.ZERO
	
	if is_fighting and combat_target and combat_target.current_health > 0:
		current_cooldown -= delta
		if current_cooldown <= 0:
			print(name + ": Атакую " + combat_target.name)
			# Атакуем противника
			combat_target.take_damage(attack_damage)
			current_cooldown = attack_cooldown

func move_to(pos: Vector3):
	print(name + ": Двигаюсь к позиции: " + str(pos))
	target_position = pos
	is_moving = true 
