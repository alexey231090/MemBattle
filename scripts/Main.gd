extends Control

@onready var card_manager = $CardManager
@onready var cards_grid = $MarginContainer/VBoxContainer/ScrollContainer/CardsGrid

func _ready():
    # Даем время на загрузку карт
    await get_tree().create_timer(0.1).timeout
    display_all_cards()

func display_all_cards():
    # Очищаем grid перед добавлением карт
    for child in cards_grid.get_children():
        child.queue_free()
    
    # Создаем экземпляр каждой карты
    for card_data in card_manager.get_all_cards():
        if card_data.has("id"):
            var card_instance = card_manager.create_card_instance(card_data["id"])
            if card_instance:
                cards_grid.add_child(card_instance) 