extends CharacterBody3D

@onready var name_label = $Stats/NameLabel
@onready var attack_label = $Stats/AttackLabel
@onready var health_label = $Stats/HealthLabel
@onready var sprite = $Sprite3D

var card_data: Dictionary = {}
var move_speed: float = 5.0
var target_position: Vector3 = Vector3.ZERO
var is_moving: bool = false

func _ready():
    # Инициализация карты
    pass

func setup(data: Dictionary):
    card_data = data
    update_display()

func update_display():
    if card_data.is_empty():
        return
        
    name_label.text = card_data.get("name", "Без имени")
    attack_label.text = "⚔️ " + str(card_data.get("attack", 0))
    health_label.text = "❤️ " + str(card_data.get("health", 0))
    
    # Загрузка спрайта, если указан
    var sprite_path = card_data.get("sprite", "")
    if sprite_path and ResourceLoader.exists(sprite_path):
        sprite.texture = load(sprite_path)

func move_to(pos: Vector3):
    target_position = pos
    is_moving = true

func _physics_process(delta):
    if is_moving:
        var direction = (target_position - global_position)
        if direction.length() > 0.1:
            velocity = direction.normalized() * move_speed
            move_and_slide()
        else:
            is_moving = false
            global_position = target_position
            velocity = Vector3.ZERO 