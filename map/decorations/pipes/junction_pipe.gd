@tool
extends Pipe
class_name JunctionPipe

@onready var _TopWindbox: Area3D = $top_windbox
@onready var _SideWindbox: Area3D = $side_windbox
@onready var _BottomWindbox: Area3D = $bottom_windbox

@onready var _Arrow1: Label3D = $Arrow
@onready var _Arrow2: Label3D = $Arrow2

#enum Directions {UP, SIDE, DOWN}
@export var IsOutputtingSide: bool = false

func _process(delta: float) -> void:
   _Arrow1.rotation.z = lerp(_Arrow1.rotation.z, 0.0 if IsOutputtingSide else -PI/2, delta)
   _Arrow2.rotation.z = lerp(_Arrow2.rotation.z, 0.0 if IsOutputtingSide else -PI/2, delta)
   _Arrow1.position.z = lerp(_Arrow1.position.z, 0.5 if IsOutputtingSide else 0.0, delta)
   _Arrow2.position.z = lerp(_Arrow2.position.z, 0.5 if IsOutputtingSide else 0.0, delta)
   
   _apply_wind(_TopWindbox, Vector3.DOWN if IsOutputtingSide else Vector3.UP, delta)
   _apply_wind(_SideWindbox, Vector3.BACK if IsOutputtingSide else Vector3.FORWARD, delta)
   _apply_wind(_BottomWindbox, Vector3.UP, delta)
         
   
