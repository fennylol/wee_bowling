@tool
extends Node3D
class_name Lane

@onready var ActionCam: Camera3D = $SubViewport/Camera3D

func _ready() -> void:
   ActionCam.rotation += rotation
   ActionCam.global_position = to_global(Vector3(0, 7.5, -17.75))
