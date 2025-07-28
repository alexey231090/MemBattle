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
	
	# --- ГРУППИРУЕМ АТАКУЮЩИХ ПО ЦЕЛЯМ ---
	var enemy_to_allies := {}
	for ally in allies:
		if !is_instance_valid(ally.card):
			continue
		var closest_enemy = null
		var min_distance = INF
		for enemy in enemies:
			if !is_instance_valid(enemy.card):
				continue
			var dx = abs(enemy.col - ally.col)
			var dz = abs(enemy.row - ally.row)
			var distance = max(dx, dz)
			if distance < min_distance:
				min_distance = distance
				closest_enemy = enemy
		if closest_enemy and is_instance_valid(closest_enemy.card):
			if not enemy_to_allies.has(closest_enemy):
				enemy_to_allies[closest_enemy] = []
			enemy_to_allies[closest_enemy].append(ally)
	
	# --- СОЮЗНИКИ ПРОСТО ДВИГАЮТСЯ К ВРАГУ ---
	for enemy in enemy_to_allies.keys():
		var attackers = enemy_to_allies[enemy]
		for i in range(attackers.size()):
			var ally = attackers[i]
			if !is_instance_valid(ally.card):
				continue
			ally.card.combat_target = enemy.card
			ally.card.move_to(enemy.card.global_position)

func get_lowest_f_score(open_set: Array, f_score: Dictionary) -> Vector2:
	var lowest = open_set[0]
	for point in open_set:
		if f_score[point] < f_score[lowest]:
			lowest = point
	return lowest

func optimize_path(path: Array, occupied: Dictionary) -> Array:
	if path.size() < 3:
		return path
		
	var optimized = []
	var i = 0
	optimized.append(path[0])
	
	while i < path.size() - 1:
		var current = path[i]
		
		# Ищем самую дальнюю точку, до которой можно дойти по диагонали
		var max_look_ahead = min(path.size() - i - 1, 3) # Смотрим максимум на 3 шага вперед
		var best_diagonal = -1
		
		for j in range(1, max_look_ahead + 1):
			var target = path[i + j]
			var dx = target.x - current.x
			var dy = target.y - current.y
			
			# Проверяем, можно ли дойти по диагонали
			if abs(dx) == abs(dy) and can_move_diagonal(current, target, occupied):
				best_diagonal = i + j
		
		if best_diagonal != -1:
			# Если нашли диагональный путь, добавляем конечную точку
			optimized.append(path[best_diagonal])
			i = best_diagonal
		else:
			# Иначе добавляем следующую точку из оригинального пути
			optimized.append(path[i + 1])
			i += 1
	
	return optimized

func can_move_diagonal(start: Vector2, end: Vector2, occupied: Dictionary) -> bool:
	# Проверяем, не заблокирован ли диагональный путь
	var dx = sign(end.x - start.x)
	var dy = sign(end.y - start.y)
	var current = start
	
	while current != end:
		current = Vector2(current.x + dx, current.y + dy)
		if occupied.has(current) and current != end:
			return false
	
	return true

func astar_pathfinding(start: Vector2, end: Vector2, occupied: Dictionary) -> Array:
	var open_set = [start]
	var came_from = {}
	
	var g_score = {}
	g_score[start] = 0
	
	var f_score = {}
	f_score[start] = heuristic(start, end)
	
	while open_set.size() > 0:
		var current = get_lowest_f_score(open_set, f_score)
		if current == end:
			var path = reconstruct_path(came_from, current)
			return optimize_path(path, occupied)
		
		open_set.erase(current)
		
		# Проверяем соседние клетки (только по горизонтали и вертикали)
		var neighbors = [
			Vector2(current.x + 1, current.y), # вправо
			Vector2(current.x - 1, current.y), # влево
			Vector2(current.x, current.y + 1), # вниз
			Vector2(current.x, current.y - 1)  # вверх
		]
		
		for neighbor in neighbors:
			# Проверяем границы поля
			if neighbor.x < 0 or neighbor.x >= game_field.GRID_SIZE.x or \
			   neighbor.y < 0 or neighbor.y >= game_field.GRID_SIZE.y:
				continue
			
			# Проверяем, не занята ли клетка
			if occupied.has(neighbor) and neighbor != end:
				continue
			
			var tentative_g_score = g_score[current] + 1
			
			if !g_score.has(neighbor) or tentative_g_score < g_score[neighbor]:
				came_from[neighbor] = current
				g_score[neighbor] = tentative_g_score
				f_score[neighbor] = g_score[neighbor] + heuristic(neighbor, end)
				
				if !open_set.has(neighbor):
					open_set.append(neighbor)
	
	return []

func heuristic(pos: Vector2, end: Vector2) -> float:
	# Используем манхэттенское расстояние
	return abs(end.x - pos.x) + abs(end.y - pos.y)

func reconstruct_path(came_from: Dictionary, current: Vector2) -> Array:
	var path = [current]
	while came_from.has(current):
		current = came_from[current]
		path.push_front(current)
	return path

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

func find_path_to_enemy(ally, enemy, all_cards: Array) -> Array:
	var start_pos = Vector2(ally.row, ally.col)
	var end_pos = Vector2(enemy.row, enemy.col)
	var final_path = []
	
	print("Ищем путь от ", start_pos, " к ", end_pos)
	
	# Создаем карту занятых позиций
	var occupied_positions = {}
	for card in all_cards:
		if is_instance_valid(card.card) and card.card != ally.card and card.card != enemy.card:
			occupied_positions[Vector2(card.row, card.col)] = true
	
	# Сначала пробуем прямой путь
	if start_pos.x == end_pos.x or start_pos.y == end_pos.y:
		var direct_path = try_direct_path(start_pos, end_pos, occupied_positions)
		if direct_path.size() > 0:
			for point in direct_path:
				final_path.append(game_field.board_cells[point.x][point.y])
			return final_path
	
	# Если прямой путь невозможен, используем A* с оптимизацией диагоналей
	var path = astar_pathfinding(start_pos, end_pos, occupied_positions)
	
	# Убираем последнюю точку (позицию врага)
	if path.size() > 1:
		path.pop_back()
	
	# Преобразуем путь в мировые координаты
	for point in path:
		if point.x >= 0 and point.x < game_field.GRID_SIZE.x and \
		   point.y >= 0 and point.y < game_field.GRID_SIZE.y:
			final_path.append(game_field.board_cells[point.x][point.y])
	
	return final_path

func try_direct_path(start: Vector2, end: Vector2, occupied: Dictionary) -> Array:
	var path = []
	var current = start
	
	# Определяем направление движения
	var dx = 0
	var dy = 0
	if start.x == end.x:  # Движение по вертикали
		dy = sign(end.y - start.y)
	else:  # Движение по горизонтали
		dx = sign(end.x - start.x)
	
	# Строим путь
	while current != end:
		var next = Vector2(current.x + dx, current.y + dy)
		if occupied.has(next):
			return []  # Путь заблокирован
		path.append(next)
		current = next
	
	# Убираем последнюю точку (позицию врага)
	if path.size() > 0:
		path.pop_back()
	
	return path 

# --- ВСПОМОГАТЕЛЬНАЯ ФУНКЦИЯ: поиск свободных ячеек вокруг цели ---
func get_free_cells_around_target(enemy_row: int, enemy_col: int, board_cards: Dictionary, board_cells: Array, max_count: int) -> Array:
	var directions = [
		Vector2(-1, -1), Vector2(-1, 0), Vector2(-1, 1),
		Vector2(0, -1),                Vector2(0, 1),
		Vector2(1, -1), Vector2(1, 0), Vector2(1, 1)
	]
	var free_cells = []
	for dir in directions:
		var r = enemy_row + int(dir.x)
		var c = enemy_col + int(dir.y)
		if r >= 0 and r < board_cells.size() and c >= 0 and c < board_cells[0].size():
			var cell_pos = board_cells[r][c]
			if not board_cards.has(cell_pos):
				free_cells.append(cell_pos)
				if free_cells.size() >= max_count:
					break
	return free_cells

# --- ДОБАВЛЯЕМ ВСПОМОГАТЕЛЬНУЮ ФУНКЦИЮ ---
func get_positions_around_target(center: Vector3, count: int, radius: float = 2.0) -> Array:
	var positions = []
	for i in range(count):
		var angle = (TAU / count) * i
		var offset = Vector3(radius * cos(angle), 0, radius * sin(angle))
		positions.append(center + offset)
	return positions 
