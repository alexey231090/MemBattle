extends Node

var cards: Dictionary = {}

func _ready():
	load_cards()

func load_cards():
	var json_path = "res://resources/data/cards.json"
	if not FileAccess.file_exists(json_path):
		print("Ошибка: Файл cards.json не найден")
		return
		
	var file = FileAccess.open(json_path, FileAccess.READ)
	if not file:
		print("Ошибка: Не удалось открыть файл cards.json")
		return
		
	var json = JSON.new()
	var error = json.parse(file.get_as_text())
	
	if error == OK:
		var data = json.data
		if data.has("cards"):
			cards = {}
			for card_data in data["cards"]:
				if card_data.has("id"):
					cards[card_data["id"]] = card_data
			print("Загружено карт: ", cards.size())
	else:
		print("Ошибка парсинга JSON: ", json.get_error_message())

func get_all_cards() -> Array:
	return cards.values() 
