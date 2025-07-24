extends Node3D

var dragging_card = null
var card_original_position = Vector3.ZERO
var drag_plane_normal = Vector3.UP
var mouse_offset = Vector3.ZERO

# Добавляем ссылки на сцены карт
var bench_card_scene = preload("res://prefabs/BenchCard3D.tscn")
var field_card_scene = preload("res://prefabs/Card3D.tscn")

@onready var game_field = $GameField

func _ready():
    create_test_card()

func create_test_card():
    var test_card_data = {
        "name": "Тралалеро",
        "attack": 5,
        "health": 10,
        "type": "Поющий"
    }
    
    # Создаем карту на скамейке
    var card = bench_card_scene.instantiate()
    add_child(card)
    card.setup(test_card_data)
    # Помещаем карту в первый слот скамейки
    card.global_position = game_field.get_bench_cells()[0]
    
    # Создаем еще одну карту для теста
    var card2 = bench_card_scene.instantiate()
    add_child(card2)
    card2.setup({
        "name": "Капучина",
        "attack": 3,
        "health": 7,
        "type": "Танцующий"
    })
    card2.global_position = game_field.get_bench_cells()[1]

func _input(event):
    # Временное управление камерой для тестирования
    if event is InputEventKey:
        if event.pressed:
            if event.keycode == KEY_Q:  # Поворот камеры влево
                $Camera3D.rotate_y(0.1)
            elif event.keycode == KEY_E:  # Поворот камеры вправо
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
                if result and result.collider is CharacterBody3D:
                    dragging_card = result.collider
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
                    
                    dragging_card.move_to(target_position)
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
    var query = PhysicsRayQueryParameters3D.create(from, to)
    query.collision_mask = 1  # Маска для карт
    var card_result = space_state.intersect_ray(query)
    
    if card_result:
        return card_result
    
    # Если не попали по карте, проверяем плоскость перетаскивания
    query.collision_mask = 2  # Маска для плоскости перетаскивания
    return space_state.intersect_ray(query) 