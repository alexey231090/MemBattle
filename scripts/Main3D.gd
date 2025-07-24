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
	# Создаем несколько тестовых союзных капсул на скамейке
	for i in range(3):
		var card = ally_card_scene.instantiate()
		add_child(card)
		var bench_pos = game_field.get_bench_cells()[i]
		card.global_position = bench_pos
		game_field.place_card(card, bench_pos)
	
	# Создаем тестового врага на поле
	var enemy_card = enemy_card_scene.instantiate()
	add_child(enemy_card)
	# Помещаем врага в центр противоположной стороны поля
	var enemy_pos = game_field.board_cells[1][4]  # Примерно середина дальней части поля
	enemy_card.global_position = enemy_pos
	game_field.place_card(enemy_card, enemy_pos)

func _on_battle_button_pressed():
	start_battle()

func start_battle():
	print("Начало боя!")
	var board_size = game_field.GRID_SIZE
	
	# Собираем все карты на поле
	var all_cards = []
	
	# Проходим по каждой ячейке поля
	for row in range(board_size.x):
		for col in range(board_size.y):
			var cell_pos = game_field.board_cells[row][col]
			var card = game_field.get_card_at_position(cell_pos)
			if card:
				print("Найдена карта в позиции: ", cell_pos)
				all_cards.append({
					"card": card,
					"pos": cell_pos,
					"row": row,
					"col": col,
					"is_enemy": card.scene_file_path.contains("EnemyCard3D")
				})
				print("Это " + ("враг" if card.scene_file_path.contains("EnemyCard3D") else "союзник"))
	
	print("Всего найдено карт: ", all_cards.size())
	
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
	
	# Для каждого союзника ищем ближайшего врага (включая диагональ)
	for ally in allies:
		if !is_instance_valid(ally.card):
			continue
			
		var closest_enemy = null
		var min_distance = INF
		
		for enemy in enemies:
			if !is_instance_valid(enemy.card):
				continue
				
			# Вычисляем расстояние по обеим осям
			var dx = abs(enemy.col - ally.col)
			var dz = abs(enemy.row - ally.row)
			
			# Используем максимум из расстояний как общее расстояние
			# Это позволяет учитывать и прямые, и диагональные направления
			var distance = max(dx, dz)
			
			if distance < min_distance:
				min_distance = distance
				closest_enemy = enemy
		
		if closest_enemy and is_instance_valid(closest_enemy.card):
			print("Начинаем бой между: ", ally.card.name, " и ", closest_enemy.card.name)
			print("Расстояние: ", min_distance, " ячеек")
			
			# Если расстояние больше 1, нужно двигаться к противнику
			if min_distance > 1:
				# TODO: Здесь будет логика перемещения
				print("Нужно переместиться ближе к противнику")
				# Пока просто начинаем бой
				ally.card.start_combat(closest_enemy.card, ally.pos)
				closest_enemy.card.start_combat(ally.card, closest_enemy.pos)
			else:
				# Если противник рядом (включая диагональ), сразу начинаем бой
				ally.card.start_combat(closest_enemy.card, ally.pos)
				closest_enemy.card.start_combat(ally.card, closest_enemy.pos)

func check_battle_in_rows(all_cards: Array):
	# Группируем карты по строкам (для боя по оси X)
	var rows = {}
	for card_data in all_cards:
		# Проверяем, что карта всё ещё существует
		if !is_instance_valid(card_data.card):
			continue
			
		if not rows.has(card_data.row):
			rows[card_data.row] = {"allies": [], "enemies": []}
		
		if card_data.is_enemy:
			rows[card_data.row].enemies.append(card_data)
		else:
			rows[card_data.row].allies.append(card_data)
	
	# Обрабатываем каждую строку
	for row_index in rows.keys():
		var row_data = rows[row_index]
		print("Строка ", row_index, ": союзников - ", row_data.allies.size(), ", врагов - ", row_data.enemies.size())
		
		if row_data.allies.size() > 0 and row_data.enemies.size() > 0:
			print("В строке ", row_index, " найдены противники")
			
			# Сопоставляем ближайших противников
			for ally in row_data.allies:
				# Проверяем, что союзник всё ещё существует
				if !is_instance_valid(ally.card):
					continue
					
				var closest_enemy = null
				var min_distance = INF
				
				for enemy in row_data.enemies:
					# Проверяем, что враг всё ещё существует
					if !is_instance_valid(enemy.card):
						continue
						
					var distance = abs(enemy.col - ally.col)
					print("Расстояние между ", ally.card.name, " и ", enemy.card.name, " по X: ", distance)
					if distance < min_distance:
						min_distance = distance
						closest_enemy = enemy
				
				if closest_enemy and is_instance_valid(closest_enemy.card):
					print("Начинаем бой между: ", ally.card.name, " и ", closest_enemy.card.name, " в строке")
					ally.card.start_combat(closest_enemy.card, ally.pos)
					closest_enemy.card.start_combat(ally.card, closest_enemy.pos)

func check_battle_in_columns(all_cards: Array):
	# Группируем карты по колонкам (для боя по оси Z)
	var columns = {}
	for card_data in all_cards:
		# Проверяем, что карта всё ещё существует
		if !is_instance_valid(card_data.card):
			continue
			
		if not columns.has(card_data.col):
			columns[card_data.col] = {"allies": [], "enemies": []}
		
		if card_data.is_enemy:
			columns[card_data.col].enemies.append(card_data)
		else:
			columns[card_data.col].allies.append(card_data)
	
	# Обрабатываем каждую колонку
	for col_index in columns.keys():
		var col_data = columns[col_index]
		print("Колонка ", col_index, ": союзников - ", col_data.allies.size(), ", врагов - ", col_data.enemies.size())
		
		if col_data.allies.size() > 0 and col_data.enemies.size() > 0:
			print("В колонке ", col_index, " найдены противники")
			
			# Сопоставляем ближайших противников
			for ally in col_data.allies:
				# Проверяем, что союзник всё ещё существует
				if !is_instance_valid(ally.card):
					continue
					
				var closest_enemy = null
				var min_distance = INF
				
				for enemy in col_data.enemies:
					# Проверяем, что враг всё ещё существует
					if !is_instance_valid(enemy.card):
						continue
						
					var distance = abs(enemy.row - ally.row)
					print("Расстояние между ", ally.card.name, " и ", enemy.card.name, " по Z: ", distance)
					if distance < min_distance:
						min_distance = distance
						closest_enemy = enemy
				
				if closest_enemy and is_instance_valid(closest_enemy.card):
					print("Начинаем бой между: ", ally.card.name, " и ", closest_enemy.card.name, " в колонке")
					ally.card.start_combat(closest_enemy.card, ally.pos)
					closest_enemy.card.start_combat(ally.card, closest_enemy.pos)

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
