extends Area3D
class_name KillZone

func _ready() -> void:
   body_entered.connect(
      func(body: Node3D) -> void:
         if body is GameObject:
            body.try_clear()
   )
