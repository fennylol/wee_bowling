extends Pipe
class_name StraightPipe

@onready var _Windbox: Area3D = $upward_windbox

func _process(delta: float) -> void:
   _apply_wind(_Windbox, Vector3.UP, delta)

   
   
