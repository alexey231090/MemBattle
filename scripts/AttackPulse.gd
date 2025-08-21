extends MeshInstance3D

# Constants for configuration
const FLIGHT_SPEED: float = 15.0  # Высокая скорость для эффекта выстрела
const LIFETIME: float = 1.0

var _start_position: Vector3
var _target_position: Vector3
var _timer: Timer
var _flight_time: float = 0.0
var _total_flight_time: float
var _hit_target: bool = false
var _trail_particles: Array = []  # Массив для частиц хвоста

func _ready():
	print("=== Инициализация импульса атаки ===")

	# Создаем материал с нашим шейдером для импульса атаки
	var material = ShaderMaterial.new()
	material.shader = preload("res://shaders/magic_pulse_shader.gdshader")
	material.set_shader_parameter("color", Color(1.0, 0.5, 0.0, 0.9))  # Оранжевый цвет для атаки

	# Создаем текстуру шума
	var noise_tex = NoiseTexture2D.new()
	noise_tex.noise = FastNoiseLite.new()
	var noise_texture: NoiseTexture2D = noise_tex  # Создаем локальную переменную с явным указанием типа
	material.set_shader_parameter("noise_texture", noise_texture)


	material_override = material

	# Рассчитываем время полета
	_total_flight_time = _start_position.distance_to(_target_position) / FLIGHT_SPEED
	if _total_flight_time < 0.1:  # Защита от деления на ноль
		_total_flight_time = 0.1

	# Инициализируем таймер времени жизни
	_timer = Timer.new()
	_timer.one_shot = true
	_timer.wait_time = LIFETIME
	add_child(_timer)
	_timer.connect("timeout", Callable(self, "queue_free"))
	_timer.start()

	# Устанавливаем начальную позицию
	global_position = _start_position

	# Направляем импульс к цели
	if not _start_position.is_equal_approx(_target_position):
		look_at(_target_position, Vector3.UP)
	else:
		rotation_degrees = Vector3(90, 0, 0)

	print("Импульс атаки инициализирован, время жизни: ", LIFETIME)

func _process(delta):
	# Проверяем, что узел все еще в дереве сцены
	if not is_inside_tree() or not is_instance_valid(self):
		return

	_flight_time += delta

	if not _hit_target:
		# Движемся к цели
		var progress = min(_flight_time / _total_flight_time, 1.0)
		global_position = _start_position.lerp(_target_position, progress)

		# Создаем частицы хвоста
		if Engine.get_physics_frames() % 2 == 0:
			_create_trail_particle()

		# Обновляем существующие частицы
		_update_trail_particles(delta)

		# Проверяем достижение цели
		if progress >= 1.0:
			_on_hit_target()
			_hit_target = true
			_timer.wait_time = 0.3
			_timer.start()

func _create_trail_particle():
	# Проверяем состояние ноды
	if not is_inside_tree() or not is_instance_valid(self):
		return

	# Проверяем родительский узел
	var parent = get_parent()
	if not parent or not parent.is_inside_tree():
		return

	# Создаем частицу
	var particle = MeshInstance3D.new()
	particle.mesh = SphereMesh.new()
	particle.mesh.radius = 0.1
	particle.mesh.height = 0.1

	# Настраиваем материал частицы
	var particle_material = ShaderMaterial.new()
	particle_material.shader = preload("res://shaders/magic_pulse_shader.gdshader")
	particle_material.set_shader_parameter("color", Color(1.0, 0.5, 0.0, 0.8))  # Оранжевый цвет
	particle.material_override = particle_material


	# Добавляем частицу в сцену
	parent.add_child(particle)
	
	# Позиционируем частицу
	if is_inside_tree() and is_instance_valid(self):
		var direction = Vector3.ZERO
		if _target_position != _start_position:
			direction = (_target_position - _start_position).normalized()
		particle.global_position = global_position - direction * 0.2

	# Сохраняем данные частицы
	_trail_particles.append({
		"node": particle,
		"creation_time": _flight_time,
		"lifetime": 0.5
	})

func _update_trail_particles(delta):
	var particles_to_remove = []

	for i in range(_trail_particles.size()):
		var particle_data = _trail_particles[i]
		var particle = particle_data["node"]

		# Проверяем валидность частицы
		if not is_instance_valid(particle) or not particle.is_inside_tree():
			particles_to_remove.append(i)
			continue

		# Вычисляем возраст частицы
		var age = _flight_time - particle_data["creation_time"]
		if age > particle_data["lifetime"]:
			particles_to_remove.append(i)
			continue

		# Обновляем визуал частицы
		var life_progress = age / particle_data["lifetime"]
		var new_scale = 1.0 - life_progress
		particle.scale = Vector3.ONE * new_scale * 0.2

		if particle.material_override is ShaderMaterial:
			var new_alpha = 0.8 * (1.0 - life_progress)
			particle.material_override.set_shader_parameter("color", Color(1.0, 0.5, 0.0, new_alpha))


	# Удаляем старые частицы
	particles_to_remove.sort()
	particles_to_remove.reverse()  # Заменяем .invert() на .reverse()
	for i in particles_to_remove:
		var particle = _trail_particles[i]["node"]
		if is_instance_valid(particle):
			particle.queue_free()
		_trail_particles.remove_at(i)


func _on_hit_target():
	print("Импульс атаки достиг цели!")
	visible = false

	# Проверяем состояние ноды
	if not is_inside_tree() or not is_instance_valid(self):
		_clear_trail_particles()
		return

	# Создаем вспышку при попадании
	var flash = MeshInstance3D.new()
	flash.mesh = SphereMesh.new()
	flash.mesh.radius = 0.2  # Уменьшаем радиус с 0.4 на 0.2
	flash.mesh.height = 0.2  # Уменьшаем высоту с 0.4 на 0.2

	# Настраиваем материал вспышки
	var flash_material = ShaderMaterial.new()
	flash_material.shader = preload("res://shaders/magic_pulse_shader.gdshader")
	flash_material.set_shader_parameter("color", Color(1.0, 0.5, 0.0, 1.0))  # Оранжевый цвет
	flash.material_override = flash_material


	# Добавляем вспышку в сцену
	var parent = get_parent()
	if parent and parent.is_inside_tree():
		parent.add_child(flash)
		flash.global_position = global_position

	# Анимируем вспышку
	var tween = create_tween()
	tween.parallel().tween_property(flash, "scale", Vector3.ONE * 5.0, 0.2)

	# Создаем временный цвет для анимации прозрачности
	var flash_color = Color(1.0, 0.5, 0.0, 1.0)
	tween.parallel().tween_method(func(alpha): 
		flash_color.a = alpha
		flash.material_override.set_shader_parameter("color", flash_color)
	, 1.0, 0.0, 0.2)
	tween.tween_callback(flash.queue_free)

	# Очищаем частицы
	_clear_trail_particles()

func _clear_trail_particles():
	for particle_data in _trail_particles:
		if is_instance_valid(particle_data["node"]):
			particle_data["node"].queue_free()
	_trail_particles.clear()

func set_positions(start: Vector3, target: Vector3):
	_start_position = start
	_target_position = target
	print("Установлены позиции: начальная=", start, ", целевая=", target)
