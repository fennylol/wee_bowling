@tool
extends GameObject
class_name Pin

const UPRIGHT_DEGREES: float = 15.0
const KILL_DEPTH: float = -5.0
const BONK_SOUNDS: Array[AudioStream] = [
   preload("res://pins/sounds/knock_0.mp3"),
   preload("res://pins/sounds/knock_1.mp3"),
   preload("res://pins/sounds/knock_2.mp3"),
   preload("res://pins/sounds/knock_3.mp3"),
   preload("res://pins/sounds/knock_4.mp3"),
   preload("res://pins/sounds/knock_5.mp3"),
   preload("res://pins/sounds/knock_6.mp3"),
   preload("res://pins/sounds/knock_7.mp3"),
   preload("res://pins/sounds/knock_8.mp3"),
   preload("res://pins/sounds/knock_9.mp3"),
   preload("res://pins/sounds/knock_a.mp3"),
   preload("res://pins/sounds/knock_b.mp3"),
   preload("res://pins/sounds/knock_c.mp3")
]
const RARE_BONK_SOUNDS: Array[AudioStream] = []

signal cleared()

@onready var Mouth: AudioStreamPlayer3D = $mouth_for_screaming

func _ready() -> void:
   super()
   body_entered.connect(_handle_collision)

func _handle_collision(_body:Node3D) -> void:
   if linear_velocity.length() > 0.5 \
   or angular_velocity.length() > 0.5:
      if not Mouth.playing:
         Mouth.stream = BONK_SOUNDS[randi_range(0,BONK_SOUNDS.size()-1)]
         Mouth.play()

func _physics_process(_delta: float) -> void:
   if linear_velocity.length() < 0.1 \
   and angular_velocity.length() < 0.1 \
   and basis.y.dot(Vector3.UP) <= cos(deg_to_rad(UPRIGHT_DEGREES)) \
   or position.y <= KILL_DEPTH:
      cleared.emit()

   
