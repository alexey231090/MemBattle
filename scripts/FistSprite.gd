extends Sprite3D

var start_position: Vector3
var target_position: Vector3
var move_speed: float = 5.0
var lifetime: float = 0.5

func _ready():
	# Уменьшаем размер спрайта
	pixel_size = 0.001  # Уменьшенный размер

	# Проверяем, что позиции не совпадают перед использованием look_at
	if not start_position.is_equal_approx(target_position):
		# Смотрим в направлении цели
		look_at(target_position, Vector3.UP)
		# Поворачиваем на 90 градусов по Y, чтобы кулак был направлен правильно
		rotate_y(deg_to_rad(90))
	else:
		# Если позиции совпадают, просто поворачиваем в случайном направлении
		rotate_y(deg_to_rad(90))

func _physics_process(delta):
	# Двигаемся к цели
	var direction = (target_position - global_position).normalized()
	global_position += direction * move_speed * delta

	# Уменьшаем время жизни
	lifetime -= delta
	if lifetime <= 0:
		queue_free()
