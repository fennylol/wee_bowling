extends Pipe
class_name CurvePipe

@onready var _UpwardWindbox: Area3D = $upward_windbox
@onready var _ForwardWindbox: Area3D = $forward_windbox

func _process(delta: float) -> void:
   _apply_wind(_UpwardWindbox, Vector3.UP , delta)
   _apply_wind(_ForwardWindbox, Vector3.FORWARD, delta)
      
