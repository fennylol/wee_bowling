extends MeshInstance3D

@onready var _010  : MessageTrigger      = $"10"
@onready var _020  : MessageTrigger      = $"20"
@onready var _030  : MessageTrigger      = $"30"
@onready var _040  : MessageTrigger      = $"40"
@onready var _050  : MessageTrigger      = $"50"
@onready var _100  : MessageTrigger      = $"100"
@onready var _101  : MessageTrigger      = $"101"
@onready var _Mouth: AudioStreamPlayer3D = $MouthForScreaming

const PLOP_SOUNDS: Array[AudioStream] = [
   preload("res://map/decorations/skiball/sounds/plop_10.mp3"),
   preload("res://map/decorations/skiball/sounds/plop_20.mp3"),
   preload("res://map/decorations/skiball/sounds/plop_30.mp3"),
   preload("res://map/decorations/skiball/sounds/plop_40.mp3"),
   preload("res://map/decorations/skiball/sounds/plop_50.mp3"),
   preload("res://map/decorations/skiball/sounds/plot_100.mp3")]

func _ready() -> void:
   _100.ball_entered.connect(_play_sound.bind(5))
   _101.ball_entered.connect(_play_sound.bind(5))
   _050.ball_entered.connect(_play_sound.bind(4))
   _040.ball_entered.connect(_play_sound.bind(3))
   _030.ball_entered.connect(_play_sound.bind(2))
   _020.ball_entered.connect(_play_sound.bind(1))
   _010.ball_entered.connect(_play_sound.bind(0))

func _play_sound(_ball: Ball, idx: int) -> void:
   _Mouth.stream = PLOP_SOUNDS[idx]
   _Mouth.play()  
