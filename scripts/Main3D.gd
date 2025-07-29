extends Node3D

var dragging_card = null
var card_original_position = Vector3.ZERO
var drag_plane_normal = Vector3.UP
var mouse_offset = Vector3.ZERO

# Добавляем ссылки на сцены карт
var ally_card_scene = preload("res://prefabs/Card3D.tscn")
var enemy_card_scene = preload("res://prefabs/EnemyCard3D.tscn")

@onready var game_field = $GameField
@onready var battle_button = $CanvasLayer/BattleUI/BattleButton
@onready var spawn_area = $SpawnArea

var enemy_spawn_position = Vector3(0, 0, 12)  # Позиция за доской

# Создаем экземпляр менеджера боя
var battle_manager = BattleManager.new()

# Флаг активности боя
var is_battle_active: bool = false

func _ready():
	create_test_cards()
	battle_button.pressed.connect(_on_battle_button_pressed)
	create_enemy_spawn()

func create_enemy_spawn():
	spawn_enemy_card()

func spawn_enemy_card():
	var enemy_card = enemy_card_scene.instantiate()
	add_child(enemy_card)
	# Используем позицию SpawnArea
	enemy_card.global_position = spawn_area.global_position
	# Немного поднимаем карту над платформой
	enemy_card.global_position.y += 1.0
	# Добавляем метку, что это карта для спавна
	enemy_card.set_meta("is_spawn_card", true)
	# Подключаем сигнал гибели карты
	enemy_card.card_died.connect(check_for_new_targets)

func create_test_cards():
	# Создаем больше тестовых союзных капсул на скамейке для тестирования групповых атак
	for i in range(5):  # Увеличиваем количество карт для тестирования
		var card = ally_card_scene.instantiate()
		add_child(card)
		var bench_pos = game_field.get_bench_cells()[i]
		card.global_position = bench_pos
		game_field.place_card(card, bench_pos)
		# Подключаем сигнал гибели карты
		card.card_died.connect(check_for_new_targets)

func _on_battle_button_pressed():
	start_battle()

func start_battle():
	var board_size = game_field.GRID_SIZE
	var board_cells = game_field.get_board_cells()
	
	# Собираем все карты на поле
	var all_cards = []
	
	# Проходим по каждой ячейке поля
	for row in range(board_size.x):
		for col in range(board_size.y):
			var cell_pos = board_cells[row][col]
			var card = game_field.get_card_at_position(cell_pos)
			if card:
				# --- Для каждой карты определяем её row/col на сетке ---
				var nearest_row = -1
				var nearest_col = -1
				for r in range(board_cells.size()):
					for c in range(board_cells[0].size()):
						if board_cells[r][c].distance_to(card.global_position) < 0.5:
							nearest_row = r
							nearest_col = c
							break
					if nearest_row != -1:
						break
				all_cards.append({
					"card": card,
					"pos": cell_pos,
					"row": nearest_row,
					"col": nearest_col,
					"is_enemy": card.scene_file_path.contains("EnemyCard3D")
				})
	
	# Разделяем карты на союзников и врагов
	var allies = []
	var enemies = []
	for card_data in all_cards:
		if !is_instance_valid(card_data.card):
			continue
		if card_data.is_enemy:
			enemies.append(card_data)
		else:
			allies.append(card_data)
	
	# Используем BattleManager для поиска целей и выполнения боя
	var battle_assignments = battle_manager.find_battle_targets(allies, enemies)
	battle_manager.execute_battle(battle_assignments)
	
	# Устанавливаем флаг активности боя
	is_battle_active = true

func _input(event):
	# Временное управление камерой для тестирования
	if event is InputEventKey:
		if event.pressed:
			if event.keycode == KEY_Q:  # Поворот камерой влево
				$Camera3D.rotate_y(0.1)
			elif event.keycode == KEY_E:  # Поворот камерой вправо
				$Camera3D.rotate_y(-0.1)
			elif event.keycode == KEY_W:  # Приблизить
				$Camera3D.translate(Vector3(0, 0, -1))
			elif event.keycode == KEY_S:  # Отдалить
				$Camera3D.translate(Vector3(0, 0, 1))
	
	# Обработка перетаскивания карт
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				# Начало перетаскивания
				var result = raycast_from_mouse()
				if result:
					var card = null
					if result.collider is CharacterBody3D:
						card = result.collider
					else:
						card = game_field.get_card_at_position(result.position)
					
					if card:
						dragging_card = card
						card_original_position = dragging_card.global_position
						mouse_offset = result.position - dragging_card.global_position
						update_highlight_position(dragging_card.global_position)
			else:
				# Конец перетаскивания
				if dragging_card:
					var board_pos = game_field.find_nearest_board_cell(dragging_card.global_position)
					var bench_pos = game_field.find_nearest_bench_cell(dragging_card.global_position)
					
					var target_position
					if dragging_card.global_position.distance_to(board_pos) < dragging_card.global_position.distance_to(bench_pos):
						target_position = board_pos
					else:
						target_position = bench_pos
					
					# Проверяем, была ли это карта для спавна
					if dragging_card.has_meta("is_spawn_card"):
						# Создаем новую карту на месте спавна
						spawn_enemy_card()
						# Убираем метку со старой карты
						dragging_card.remove_meta("is_spawn_card")
					
					dragging_card.move_to(target_position)
					game_field.place_card(dragging_card, target_position)
					dragging_card = null
					game_field.hide_highlights()
	
	# Обновление позиции при перетаскивании
	elif event is InputEventMouseMotion and dragging_card:
		var camera = $Camera3D
		var from = camera.project_ray_origin(event.position)
		var to = from + camera.project_ray_normal(event.position) * 1000
		
		# Создаем плоскость на уровне карты
		var plane = Plane(drag_plane_normal, card_original_position.y)
		var intersection = plane.intersects_ray(from, to - from)
		
		if intersection:
			# Учитываем смещение при установке позиции
			var new_pos = intersection - mouse_offset
			new_pos.y = card_original_position.y
			dragging_card.global_position = new_pos
			update_highlight_position(new_pos)

func update_highlight_position(pos: Vector3):
	var board_pos = game_field.find_nearest_board_cell(pos)
	var bench_pos = game_field.find_nearest_bench_cell(pos)
	
	# Сначала скрываем обе подсветки
	game_field.hide_highlights()
	
	# Затем показываем нужную
	if pos.distance_to(board_pos) < pos.distance_to(bench_pos):
		game_field.show_board_highlight(board_pos)
	else:
		game_field.show_bench_highlight(bench_pos)

func raycast_from_mouse() -> Dictionary:
	var mouse_pos = get_viewport().get_mouse_position()
	var camera = $Camera3D
	var from = camera.project_ray_origin(mouse_pos)
	var to = from + camera.project_ray_normal(mouse_pos) * 1000
	var space_state = get_world_3d().direct_space_state
	
	# Сначала проверяем столкновение с картами
	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 1  # Маска для карт
	var card_result = space_state.intersect_ray(query)
	
	if card_result:
		return card_result
	
	# Если не попали по карте, проверяем ячейки
	query.collision_mask = 2  # Маска для ячеек
	query.collide_with_areas = true  # Важно для работы с Area3D
	query.collide_with_bodies = false  # Отключаем столкновения с телами
	var cell_result = space_state.intersect_ray(query)
	
	if cell_result:
		return cell_result
	
	return {}

# Функция для проверки новых целей при гибели карты
func check_for_new_targets():
	if not is_battle_active:
		return
	
	# Очищаем мертвые карты из словарей
	game_field.cleanup_dead_cards()
	
	# Собираем все карты на поле
	var board_size = game_field.GRID_SIZE
	var board_cells = game_field.get_board_cells()
	var all_cards = []
	
	# Проходим по каждой ячейке поля
	for row in range(board_size.x):
		for col in range(board_size.y):
			var cell_pos = board_cells[row][col]
			var card = game_field.get_card_at_position(cell_pos)
			if card:
				all_cards.append({
					"card": card,
					"pos": cell_pos,
					"is_enemy": card.scene_file_path.contains("EnemyCard3D")
				})
	
	# Разделяем карты на союзников и врагов
	var allies = []
	var enemies = []
	for card_data in all_cards:
		if !is_instance_valid(card_data.card):
			continue
		if card_data.is_enemy:
			enemies.append(card_data)
		else:
			allies.append(card_data)
	
	# Дополнительная фильтрация - убираем мертвые карты
	allies = allies.filter(func(card_data): return is_instance_valid(card_data.card))
	enemies = enemies.filter(func(card_data): return is_instance_valid(card_data.card))
	
	# Проверяем, есть ли еще живые карты обеих команд
	if allies.size() == 0 or enemies.size() == 0:
		# Бой закончен
		is_battle_active = false
		return
	
	# Ищем новые цели для карт без целей
	battle_manager.find_new_targets_for_orphaned_cards(allies, enemies)

 
