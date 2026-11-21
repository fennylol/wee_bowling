extends Trigger
class_name KillTrigger

func _on_gameobject_entered(game_object: GameObject) -> void:
   game_object.try_clear()
