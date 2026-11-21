extends Area3D
class_name Trigger

func _ready() -> void:
   body_entered.connect(
      func(body: Node3D) -> void:
         if body is GameObject:
            _on_gameobject_entered(body)
         if body is Ball:
            _on_ball_entered(body)
         if body is Pin:
            _on_pin_entered(body)
   )

func _on_gameobject_entered(game_object: GameObject) -> void:
   pass

func _on_ball_entered(ball: Ball) -> void:
   pass
   
func _on_pin_entered(pin: Pin) -> void:
   pass
