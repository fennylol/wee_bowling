extends Area3D
class_name MessageZone

@export var Msg          : String
@export var Size         : float   = 0.15
@export var TravelTime   : float   = 0.5
@export var HoverTime    : float   = 1.0
@export var StartPos     : Vector3 = Vector3.ZERO
@export var TargetPos    : Vector3 = Vector3.UP

func _ready() -> void:
   body_entered.connect(
      func(body: Node3D) -> void:
         if body is Ball:
            var msg := Message.new(
               Msg, 
               Size,
               body._BallMesh.material_override.albedo_color,
               body._OutlineColor,
               TravelTime, 
               HoverTime, 
               StartPos, 
               TargetPos
            ) 
               
            add_child(msg)
   )
