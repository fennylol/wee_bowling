extends Area3D
class_name Trigger

signal gameobject_entered(game_object: GameObject)
signal ball_entered(ball: Ball)
signal pin_entered(pin: Pin)

func _ready() -> void:
   body_entered.connect(
      func(body: Node3D) -> void:
         if body is GameObject:
            _on_gameobject_entered(body)
            gameobject_entered.emit(body)
         if body is Ball:
            _on_ball_entered(body)
            ball_entered.emit(body)
         if body is Pin:
            _on_pin_entered(body)
            pin_entered.emit(body)
   )

func _on_gameobject_entered(_game_object: GameObject) -> void: pass
func _on_ball_entered(_ball: Ball) -> void: pass
func _on_pin_entered(_pin: Pin) -> void: pass
