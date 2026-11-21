extends Trigger
class_name MessageTrigger

@export var Msg          : String
@export var Size         : float   = 0.15
@export var TravelTime   : float   = 0.5
@export var HoverTime    : float   = 1.0
@export var StartPos     : Vector3 = Vector3.ZERO
@export var TargetPos    : Vector3 = Vector3.UP

func _on_ball_entered(ball: Ball) -> void:
   var msg := Message.new(
      Msg, 
      Size,
      ball._BallMesh.material_override.albedo_color,
      ball._OutlineColor,
      TravelTime, 
      HoverTime, 
      StartPos, 
      TargetPos
   ) 
      
   add_child(msg)
