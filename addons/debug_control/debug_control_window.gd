@tool
extends Window

var script_list: ItemList
var print_container: VBoxContainer
var scan_button: Button
var comment_button: Button
var uncomment_button: Button
var delete_button: Button
var refresh_button: Button
var script_count_label: Label
var print_count_label: Label
var select_all_button: Button
var deselect_all_button: Button

var current_scripts = []
var current_prints = []
var print_checkboxes = []

func _ready():
	print("Окно Debug Control готово!")
	
	# Настройки окна
	title = "Debug Control"
	initial_position = Window.WINDOW_INITIAL_POSITION_CENTER_MAIN_WINDOW_SCREEN
	size = Vector2(600, 500)
	
	setup_ui()
	connect_signals()
	
	# Подключаем сигнал закрытия окна
	close_requested.connect(_on_close_requested)
	
	print("Окно настроено и готово к показу!")

func _on_close_requested():
	hide()

func setup_ui():
	# Основной контейнер
	var vbox = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(vbox)
	
	# Заголовок
	var title = Label.new()
	title.text = "Debug Control - Управление print в GDScript"
	title.add_theme_font_size_override("font_size", 18)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	
	# Разделитель
	var separator1 = HSeparator.new()
	vbox.add_child(separator1)
	
	# Кнопки управления
	var button_container = HBoxContainer.new()
	
	scan_button = Button.new()
	scan_button.text = "Сканировать скрипты"
	scan_button.custom_minimum_size = Vector2(150, 30)
	button_container.add_child(scan_button)
	
	refresh_button = Button.new()
	refresh_button.text = "Обновить print"
	refresh_button.custom_minimum_size = Vector2(150, 30)
	button_container.add_child(refresh_button)
	
	vbox.add_child(button_container)
	
	# Разделитель
	var separator2 = HSeparator.new()
	vbox.add_child(separator2)
	
	# Список скриптов
	var script_header = HBoxContainer.new()
	
	var script_label = Label.new()
	script_label.text = "Найденные скрипты:"
	script_header.add_child(script_label)
	
	script_count_label = Label.new()
	script_count_label.text = "(0)"
	script_header.add_child(script_count_label)
	
	vbox.add_child(script_header)
	
	script_list = ItemList.new()
	script_list.custom_minimum_size = Vector2(0, 120)
	vbox.add_child(script_list)
	
	# Разделитель
	var separator3 = HSeparator.new()
	vbox.add_child(separator3)
	
	# Список print
	var print_header = HBoxContainer.new()
	
	var print_label = Label.new()
	print_label.text = "Найденные print:"
	print_header.add_child(print_label)
	
	print_count_label = Label.new()
	print_count_label.text = "(0)"
	print_header.add_child(print_count_label)
	
	vbox.add_child(print_header)
	
	# Кнопки выбора всех/снятия выбора
	var select_buttons_container = HBoxContainer.new()
	
	select_all_button = Button.new()
	select_all_button.text = "Выбрать все"
	select_all_button.custom_minimum_size = Vector2(100, 25)
	select_buttons_container.add_child(select_all_button)
	
	deselect_all_button = Button.new()
	deselect_all_button.text = "Снять выбор"
	deselect_all_button.custom_minimum_size = Vector2(100, 25)
	select_buttons_container.add_child(deselect_all_button)
	
	vbox.add_child(select_buttons_container)
	
	# Контейнер для чекбоксов print
	print_container = VBoxContainer.new()
	print_container.custom_minimum_size = Vector2(0, 150)
	
	# Создаем ScrollContainer для прокрутки
	var scroll_container = ScrollContainer.new()
	scroll_container.custom_minimum_size = Vector2(0, 150)
	scroll_container.add_child(print_container)
	vbox.add_child(scroll_container)
	
	# Разделитель
	var separator4 = HSeparator.new()
	vbox.add_child(separator4)
	
	# Кнопки действий
	var action_container = HBoxContainer.new()
	
	comment_button = Button.new()
	comment_button.text = "Закомментировать"
	comment_button.custom_minimum_size = Vector2(150, 30)
	action_container.add_child(comment_button)
	
	uncomment_button = Button.new()
	uncomment_button.text = "Раскомментировать"
	uncomment_button.custom_minimum_size = Vector2(150, 30)
	action_container.add_child(uncomment_button)
	
	delete_button = Button.new()
	delete_button.text = "Удалить"
	delete_button.custom_minimum_size = Vector2(100, 30)
	action_container.add_child(delete_button)
	
	vbox.add_child(action_container)

func connect_signals():
	scan_button.pressed.connect(_on_scan_pressed)
	refresh_button.pressed.connect(_on_refresh_pressed)
	select_all_button.pressed.connect(_on_select_all_pressed)
	deselect_all_button.pressed.connect(_on_deselect_all_pressed)
	comment_button.pressed.connect(_on_comment_pressed)
	if uncomment_button:
		uncomment_button.pressed.connect(_on_uncomment_pressed)
	delete_button.pressed.connect(_on_delete_pressed)
	script_list.item_selected.connect(_on_script_selected)

func _on_scan_pressed():
	scan_for_scripts()

func _on_refresh_pressed():
	if current_scripts.size() > 0:
		scan_prints_in_scripts()

func _on_comment_pressed():
	comment_selected_prints()

func _on_uncomment_pressed():
	uncomment_selected_prints()

func _on_delete_pressed():
	delete_selected_prints()

func _on_select_all_pressed():
	for checkbox in print_checkboxes:
		checkbox.button_pressed = true

func _on_deselect_all_pressed():
	for checkbox in print_checkboxes:
		checkbox.button_pressed = false

func _on_script_selected(index: int):
	if index >= 0 and index < current_scripts.size():
		scan_prints_in_script(current_scripts[index])

func scan_for_scripts():
	print("Сканирование скриптов...")
	
	# Очищаем предыдущие результаты
	current_scripts.clear()
	script_list.clear()
	current_prints.clear()
	
	# Получаем путь к проекту
	var project_path = ProjectSettings.get_setting("application/config/name")
	if project_path.is_empty():
		project_path = "res://"
	
	# Ищем все .gd файлы в проекте
	var dir = DirAccess.open("res://")
	if dir:
		scan_directory_recursive(dir, "res://")
	else:
		print("Ошибка: Не удалось открыть директорию проекта")
	
	# Обновляем список скриптов
	update_script_list()
	
	print("Найдено скриптов: ", current_scripts.size())

func scan_directory_recursive(dir: DirAccess, current_path: String):
	# Ищем .gd файлы в текущей директории
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		var full_path = current_path.path_join(file_name)
		
		if dir.current_is_dir():
			# Пропускаем системные папки
			if file_name != "." and file_name != ".." and file_name != ".git" and file_name != "addons":
				var sub_dir = DirAccess.open(full_path)
				if sub_dir:
					scan_directory_recursive(sub_dir, full_path)
		else:
			# Проверяем, является ли файл GDScript
			if file_name.ends_with(".gd"):
				current_scripts.append(full_path)
		
		file_name = dir.get_next()
	
	dir.list_dir_end()

func update_script_list():
	script_list.clear()
	for script_path in current_scripts:
		# Показываем только имя файла, но храним полный путь
		var file_name = script_path.get_file()
		script_list.add_item(file_name, null, false)
		# Сохраняем полный путь в метаданных
		script_list.set_item_metadata(script_list.get_item_count() - 1, script_path)
	
	# Обновляем счетчик
	script_count_label.text = "(" + str(current_scripts.size()) + ")"

func scan_prints_in_scripts():
	print("Сканирование print во всех скриптах...")
	
	current_prints.clear()
	
	for script_path in current_scripts:
		scan_prints_in_script(script_path)
	
	update_print_list()
	print("Найдено print: ", current_prints.size())

func scan_prints_in_script(script_path: String):
	print("Сканирование print в: ", script_path)
	
	var file = FileAccess.open(script_path, FileAccess.READ)
	if not file:
		print("Ошибка: Не удалось открыть файл ", script_path)
		return
	
	var line_number = 1
	var line = file.get_line()
	
	while not file.eof_reached():
		# Ищем print в строке
		var print_pos = line.find("print(")
		if print_pos >= 0:
			# Проверяем, что это не закомментированная строка
			var comment_pos = line.find("#")
			var is_commented = (comment_pos != -1 and comment_pos < print_pos)
			
			# Нашли print (включая закомментированные)
			var print_info = {
				"script_path": script_path,
				"line_number": line_number,
				"line_content": line.strip_edges(),
				"print_start": print_pos,
				"is_commented": is_commented
			}
			current_prints.append(print_info)
		
		line = file.get_line()
		line_number += 1
	
	file.close()

func update_print_list():
	# Очищаем старые чекбоксы
	for checkbox in print_checkboxes:
		checkbox.queue_free()
	print_checkboxes.clear()
	
	# Очищаем контейнер
	for child in print_container.get_children():
		child.queue_free()
	
	# Создаем новые чекбоксы для каждого print
	for i in range(current_prints.size()):
		var print_info = current_prints[i]
		var display_text = "%s:%d - %s" % [
			print_info.script_path.get_file(),
			print_info.line_number,
			print_info.line_content
		]
		
		# Добавляем префикс для закомментированных print
		if print_info.is_commented:
			display_text = "[ЗАКОММЕНТИРОВАН] " + display_text
		
		# Создаем контейнер для строки
		var row_container = HBoxContainer.new()
		
		# Создаем чекбокс
		var checkbox = CheckBox.new()
		checkbox.text = display_text
		checkbox.custom_minimum_size = Vector2(0, 25)
		
		# Устанавливаем цвет для закомментированных print (темнее)
		if print_info.is_commented:
			checkbox.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		
		# Сохраняем информацию о print в чекбоксе
		checkbox.set_meta("print_info", print_info)
		checkbox.set_meta("print_index", i)
		
		row_container.add_child(checkbox)
		print_container.add_child(row_container)
		print_checkboxes.append(checkbox)
	
	# Обновляем счетчик
	print_count_label.text = "(" + str(current_prints.size()) + ")"

func comment_selected_prints():
	print("Закомментирование выбранных print...")
	
	var selected_prints = get_selected_prints()
	if selected_prints.size() == 0:
		print("Не выбрано ни одного print для закомментирования")
		return
	
	for print_info in selected_prints:
		if not print_info.is_commented:
			comment_print_in_file(print_info)
	
	# Обновляем список после изменений
	scan_prints_in_scripts()

func uncomment_selected_prints():
	print("Раскомментирование выбранных print...")
	
	var selected_prints = get_selected_prints()
	if selected_prints.size() == 0:
		print("Не выбрано ни одного print для раскомментирования")
		return
	
	for print_info in selected_prints:
		if print_info.is_commented:
			uncomment_print_in_file(print_info)
	
	# Обновляем список после изменений
	scan_prints_in_scripts()

func delete_selected_prints():
	print("Удаление выбранных print...")
	
	var selected_prints = get_selected_prints()
	if selected_prints.size() == 0:
		print("Не выбрано ни одного print для удаления")
		return
	
	for print_info in selected_prints:
		delete_print_from_file(print_info)
	
	# Обновляем список после изменений
	scan_prints_in_scripts()

func comment_print_in_file(print_info: Dictionary):
	var script_path = print_info.script_path
	var line_number = print_info.line_number
	
	# Читаем весь файл
	var file = FileAccess.open(script_path, FileAccess.READ)
	if not file:
		print("Ошибка: Не удалось открыть файл для чтения ", script_path)
		return
	
	var lines = []
	while not file.eof_reached():
		lines.append(file.get_line())
	file.close()
	
	# Добавляем комментарий к нужной строке
	if line_number <= lines.size():
		var line = lines[line_number - 1]
		if not line.begins_with("#"):
			lines[line_number - 1] = "# " + line
	
	# Записываем файл обратно
	file = FileAccess.open(script_path, FileAccess.WRITE)
	if not file:
		print("Ошибка: Не удалось открыть файл для записи ", script_path)
		return
	
	for line in lines:
		file.store_line(line)
	file.close()
	
	print("Закомментирован print в ", script_path, " строка ", line_number)

func uncomment_print_in_file(print_info: Dictionary):
	var script_path = print_info.script_path
	var line_number = print_info.line_number
	
	# Читаем весь файл
	var file = FileAccess.open(script_path, FileAccess.READ)
	if not file:
		print("Ошибка: Не удалось открыть файл для чтения ", script_path)
		return
	
	var lines = []
	while not file.eof_reached():
		lines.append(file.get_line())
	file.close()
	
	# Убираем комментарий с нужной строки
	if line_number <= lines.size():
		var line = lines[line_number - 1]
		if line.begins_with("# "):
			lines[line_number - 1] = line.substr(2)  # Убираем "# "
		elif line.begins_with("#"):
			lines[line_number - 1] = line.substr(1)  # Убираем "#"
	
	# Записываем файл обратно
	file = FileAccess.open(script_path, FileAccess.WRITE)
	if not file:
		print("Ошибка: Не удалось открыть файл для записи ", script_path)
		return
	
	for line in lines:
		file.store_line(line)
	file.close()
	
	print("Раскомментирован print в ", script_path, " строка ", line_number)

func get_selected_prints() -> Array:
	var selected_prints = []
	for checkbox in print_checkboxes:
		if checkbox.button_pressed:
			var print_info = checkbox.get_meta("print_info")
			if print_info:
				selected_prints.append(print_info)
	return selected_prints

func delete_print_from_file(print_info: Dictionary):
	var script_path = print_info.script_path
	var line_number = print_info.line_number
	
	# Читаем весь файл
	var file = FileAccess.open(script_path, FileAccess.READ)
	if not file:
		print("Ошибка: Не удалось открыть файл для чтения ", script_path)
		return
	
	var lines = []
	while not file.eof_reached():
		lines.append(file.get_line())
	file.close()
	
	# Удаляем нужную строку
	if line_number <= lines.size():
		lines.remove_at(line_number - 1)
	
	# Записываем файл обратно
	file = FileAccess.open(script_path, FileAccess.WRITE)
	if not file:
		print("Ошибка: Не удалось открыть файл для записи ", script_path)
		return
	
	for line in lines:
		file.store_line(line)
	file.close()
	
	print("Удален print из ", script_path, " строка ", line_number)
