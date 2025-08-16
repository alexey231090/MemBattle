@tool
extends EditorPlugin

var debug_control_button: Button
var debug_control_window: Window

func _enter_tree():
	# Создаем кнопку в панели инструментов
	debug_control_button = Button.new()
	debug_control_button.text = "Debug Control"
	debug_control_button.pressed.connect(_on_debug_control_button_pressed)
	
	# Добавляем кнопку в панель инструментов
	add_control_to_container(CONTAINER_TOOLBAR, debug_control_button)
	
	print("Debug Control плагин загружен!")

func _exit_tree():
	# Удаляем кнопку при выгрузке плагина
	if debug_control_button:
		debug_control_button.queue_free()
	
	# Закрываем окно если оно открыто
	if debug_control_window and is_instance_valid(debug_control_window):
		debug_control_window.queue_free()
	
	print("Debug Control плагин выгружен!")

func _on_debug_control_button_pressed():
	print("Кнопка Debug Control нажата!")
	
	# Создаем окно если его нет
	if not debug_control_window or not is_instance_valid(debug_control_window):
		print("Создаем новое окно...")
		var scene = preload("res://addons/debug_control/debug_control_window.tscn")
		if scene:
			debug_control_window = scene.instantiate()
			if debug_control_window:
				# Добавляем окно как дочерний элемент редактора
				get_editor_interface().get_base_control().add_child(debug_control_window)
				print("Окно успешно создано и добавлено!")
			else:
				print("Ошибка: не удалось создать экземпляр окна!")
		else:
			print("Ошибка: не удалось загрузить сцену окна!")
	
	# Показываем окно
	if debug_control_window:
		print("Показываем окно...")
		# Устанавливаем позицию окна в центре экрана
		debug_control_window.position = Vector2(100, 100)
		debug_control_window.show()
		debug_control_window.grab_focus()
		print("Окно должно быть видимым!")
	else:
		print("Ошибка: окно не создано!")
