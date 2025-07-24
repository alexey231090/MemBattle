extends Node3D

const GRID_SIZE = Vector2(4, 6)  # 4 строки, 6 столбцов
const CELL_SIZE = Vector2(2, 2)  # размер ячейки сетки
const BENCH_SLOTS = 10  # количество слотов на скамейке

var board_cells = []  # массив для хранения позиций ячеек поля
var bench_cells = []  # массив для хранения позиций ячеек скамейки

# Добавляем ссылки на подсветку ячеек
@onready var board_highlight = $GameBoard/CellHighlight
@onready var bench_highlight = $Bench/CellHighlight
@onready var game_board = $GameBoard
@onready var bench = $Bench

func _ready():
    calculate_grid_positions()
    create_grid_cells()

func calculate_grid_positions():
    board_cells.clear()
    bench_cells.clear()
    
    # Получаем глобальные позиции узлов
    var board_pos = game_board.global_position
    var bench_pos = bench.global_position
    
    # Рассчитываем позиции ячеек на поле относительно GameBoard
    for row in range(GRID_SIZE.x):
        var row_cells = []
        for col in range(GRID_SIZE.y):
            var pos = Vector3(
                board_pos.x + (col - GRID_SIZE.y/2 + 0.5) * CELL_SIZE.x,
                board_pos.y,
                board_pos.z + (row - GRID_SIZE.x/2 + 0.5) * CELL_SIZE.y
            )
            row_cells.append(pos)
        board_cells.append(row_cells)
    
    # Рассчитываем позиции ячеек на скамейке относительно Bench
    for i in range(BENCH_SLOTS):
        var pos = Vector3(
            bench_pos.x + (i - BENCH_SLOTS/2 + 0.5) * 1.8,
            bench_pos.y,
            bench_pos.z
        )
        bench_cells.append(pos)

func create_grid_cells():
    # Очищаем старые ячейки
    for child in $GameBoard/GridCells.get_children():
        child.queue_free()
    for child in $Bench/BenchCells.get_children():
        child.queue_free()
    
    # Создаем ячейки на поле
    var grid_material = StandardMaterial3D.new()
    grid_material.transparency = 1
    grid_material.albedo_color = Color(1, 1, 1, 0.1)
    grid_material.emission_enabled = true
    grid_material.emission = Color(0.4, 0.6, 0.8, 1)
    
    var cell_mesh = PlaneMesh.new()
    cell_mesh.size = Vector2(1.8, 1.8)  # Немного меньше чем CELL_SIZE
    
    for row in range(GRID_SIZE.x):
        for col in range(GRID_SIZE.y):
            var cell = MeshInstance3D.new()
            cell.mesh = cell_mesh
            cell.material_override = grid_material
            $GameBoard/GridCells.add_child(cell)
            var local_pos = $GameBoard.to_local(board_cells[row][col])
            cell.position = local_pos
            cell.position.y = 0.01  # Чуть выше поля
    
    # Создаем ячейки на скамейке
    var bench_material = StandardMaterial3D.new()
    bench_material.transparency = 1
    bench_material.albedo_color = Color(1, 1, 1, 0.1)
    bench_material.emission_enabled = true
    bench_material.emission = Color(0.6, 0.4, 0.2, 1)
    
    for i in range(BENCH_SLOTS):
        var cell = MeshInstance3D.new()
        cell.mesh = cell_mesh
        cell.material_override = bench_material
        $Bench/BenchCells.add_child(cell)
        var local_pos = $Bench.to_local(bench_cells[i])
        cell.position = local_pos
        cell.position.y = 0.01

# Функции для внешнего использования
func get_board_cells() -> Array:
    return board_cells

func get_bench_cells() -> Array:
    return bench_cells

func show_board_highlight(pos: Vector3):
    board_highlight.visible = true
    board_highlight.global_position = pos
    board_highlight.position.y = 0.02

func show_bench_highlight(pos: Vector3):
    bench_highlight.visible = true
    bench_highlight.global_position = pos
    bench_highlight.position.y = 0.02

func hide_highlights():
    board_highlight.visible = false
    bench_highlight.visible = false

func find_nearest_board_cell(pos: Vector3) -> Vector3:
    var min_dist = INF
    var target_pos = Vector3.ZERO
    
    for row in range(GRID_SIZE.x):
        for col in range(GRID_SIZE.y):
            var cell_pos = board_cells[row][col]
            var dist = pos.distance_to(cell_pos)
            if dist < min_dist:
                min_dist = dist
                target_pos = cell_pos
    
    return target_pos

func find_nearest_bench_cell(pos: Vector3) -> Vector3:
    var min_dist = INF
    var target_pos = Vector3.ZERO
    
    for cell_pos in bench_cells:
        var dist = pos.distance_to(cell_pos)
        if dist < min_dist:
            min_dist = dist
            target_pos = cell_pos
    
    return target_pos 