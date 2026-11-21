@tool
extends Node3D
class_name DuelLane

@onready var Side1Cam: Camera3D = $Side/SubViewport/Camera3D
@onready var Side2Cam: Camera3D = $Side2/SubViewport/Camera3D

@onready var Side1Setter: PinSetter = $Side/PinSetter
@onready var Side2Setter: PinSetter = $Side2/PinSetter

func _ready() -> void:
   Side1Cam.rotation += rotation
   Side2Cam.rotation += rotation
   Side1Cam.global_position = to_global(Vector3(+18.0, 7.5, 0))
   Side2Cam.global_position = to_global(Vector3(-18.0, 7.5, 0))
   
   Side1Setter.regenerating.connect(Side2Setter.follow_generation)
   Side2Setter.regenerating.connect(Side1Setter.follow_generation)
