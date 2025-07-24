extends Control

@onready var name_label = $MarginContainer/VBoxContainer/Name
@onready var type_label = $MarginContainer/VBoxContainer/Type
@onready var image = $MarginContainer/VBoxContainer/ImageContainer/Image
@onready var attack_label = $MarginContainer/VBoxContainer/Stats/Attack
@onready var health_label = $MarginContainer/VBoxContainer/Stats/Health
@onready var speed_label = $MarginContainer/VBoxContainer/Stats/Speed
@onready var ability_label = $MarginContainer/VBoxContainer/Ability
@onready var description_label = $MarginContainer/VBoxContainer/Description

var card_data: Dictionary = {}

func _ready():
	# Проверяем, что все узлы найдены
	var nodes = {
		"name_label": name_label,
		"type_label": type_label,
		"image": image,
		"attack_label": attack_label,
		"health_label": health_label,
		"speed_label": speed_label,
		"ability_label": ability_label,
		"description_label": description_label
	}
	
	for node_name in nodes:
		if nodes[node_name] == null:
			print("Ошибка: Узел ", node_name, " не найден")
			return
	
	# Добавляем hover эффект
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

func setup(data: Dictionary):
	if data == null:
		print("Ошибка: Получены пустые данные карты")
		return
		
	card_data = data
	update_display()

func update_display():
	if card_data.is_empty():
		print("Предупреждение: Пустые данные карты")
		return
	
	# Безопасное обновление текста
	if name_label:
		name_label.text = card_data.get("name", "Без имени")
	if type_label:
		type_label.text = card_data.get("type", "Без типа")
	if attack_label:
		attack_label.text = "⚔️ " + str(card_data.get("attack", 0))
	if health_label:
		health_label.text = "❤️ " + str(card_data.get("health", 0))
	if speed_label:
		speed_label.text = "⚡ " + str(card_data.get("speed", 0))
	
	var ability = card_data.get("ability", {})
	if ability and ability_label:
		ability_label.text = ability.get("name", "")
	
	if description_label:
		description_label.text = card_data.get("description", "")
	
	# Загрузка спрайта, если указан
	if image:
		var sprite_path = card_data.get("sprite", "")
		if sprite_path and ResourceLoader.exists(sprite_path):
			image.texture = load(sprite_path)
		else:
			image.texture = null

func _on_mouse_entered():
	# Эффект при наведении мыши
	scale = Vector2(1.05, 1.05)
	
func _on_mouse_exited():
	# Возврат к нормальному размеру
	scale = Vector2(1.0, 1.0) 
