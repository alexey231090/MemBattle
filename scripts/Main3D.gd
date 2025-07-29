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

func create_test_cards():
	# Создаем больше тестовых союзных капсул на скамейке для тестирования групповых атак
	for i in range(5):  # Увеличиваем количество карт для тестирования
		var card = ally_card_scene.instantiate()
		add_child(card)
		var bench_pos = game_field.get_bench_cells()[i]
		card.global_position = bench_pos
		game_field.place_card(card, bench_pos)

func _on_battle_button_pressed():
	start_battle()

func start_battle():
	print("Начало боя!")
	var board_size = game_field.GRID_SIZE
	var board_cells = game_field.get_board_cells()
	var board_cards = game_field.board_cards
	
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
				print("Клик мышью")
				# Начало перетаскивания
				var result = raycast_from_mouse()
				print("Результат raycast: ", result)
				if result:
					var card = null
					if result.collider is CharacterBody3D:
						print("Попали по карте напрямую")
						card = result.collider
					else:
						print("Попали по ячейке, ищем карту")
						card = game_field.get_card_at_position(result.position)
						print("Найденная карта: ", card)
					
					if card:
						print("Начинаем перетаскивание карты")
						dragging_card = card
						card_original_position = dragging_card.global_position
						mouse_offset = result.position - dragging_card.global_position
						update_highlight_position(dragging_card.global_position)
					else:
						print("Карта не найдена")
			else:
				# Конец перетаскивания
				if dragging_card:
					print("Завершаем перетаскивание")
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
	
	print("Проверяем столкновение с картами (слой 1)")
	# Сначала проверяем столкновение с картами
	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 1  # Маска для карт
	var card_result = space_state.intersect_ray(query)
	
	if card_result:
		print("Нашли столкновение с картой")
		return card_result
	
	print("Проверяем столкновение с ячейками (слой 2)")
	# Если не попали по карте, проверяем ячейки
	query.collision_mask = 2  # Маска для ячеек
	query.collide_with_areas = true  # Важно для работы с Area3D
	query.collide_with_bodies = false  # Отключаем столкновения с телами
	var cell_result = space_state.intersect_ray(query)
	
	if cell_result:
		print("Нашли столкновение с ячейкой")
		return cell_result
	
	print("Столкновений не найдено")
	return {}

 
