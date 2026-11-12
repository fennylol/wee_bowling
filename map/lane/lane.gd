@tool
extends Node3D
class_name Lane

@onready var ActionCam: Camera3D = $SubViewport/Camera3D

func _ready() -> void:
   ActionCam.global_position = global_position + Vector3(0, 7.5, -17.75)
