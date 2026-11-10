extends Node3D
class_name BallMachine

const BALL_NODE: PackedScene = preload("res://ball/Ball.tscn")
const MIN_BALL_GAP: float = 1.5

static var Registry: Dictionary

var MaxBalls: int = 4
var BallNodes: Array[Ball]
var MachineID: int = 0


func _ready() -> void:
   MachineID = str(get_path()).hash()
   Registry[MachineID] = self
   for i in MaxBalls:
      var new_ball: Ball = BALL_NODE.instantiate()
      new_ball.register(("%s:ball:%d" % [get_path(), i]).hash())
      new_ball.ParentBallMachine = self
      new_ball.Cleared = true
      new_ball.cleared.connect(_handle_cleared_ball.bind(new_ball))
      BallNodes.append(new_ball)

func _handle_cleared_ball(ball:Ball) -> void:
   ball.QueueTime = ball.QUEUE_TIME
   remove_child(ball)

func _return_ball(ball: Ball) -> void:
   ball.position = Vector3(0,1,-0.1)
   ball.linear_velocity = Vector3(0.0,0.0,-3.5) * basis
   ball.Cleared = false
   # so a peer that hasn't returned this ball yet can't clear it again
   ball.ClaimCounter += 1
   add_child(ball)

func get_ball_states() -> PackedByteArray:
   var data: PackedByteArray = []
   data.resize(BallNodes.size() * 5)
   for i in BallNodes.size():
      data.encode_u32(i*5, BallNodes[i].ClaimCounter)
      data.encode_u8(i*5 + 4, BallNodes[i].Cleared)
   return data

@warning_ignore("integer_division")
func apply_remote_state(data: PackedByteArray) -> void:
   for i in min(BallNodes.size(), data.size() / 5):
      if data.decode_u8(i*5 + 4): BallNodes[i].remote_clear(data.decode_u32(i*5))

func _process(delta: float) -> void:
   var ball_released: bool = false
   for ball:Ball in BallNodes:
      if ball_released:
         ball.QueueTime += MIN_BALL_GAP
      elif ball.QueueTime <= 0.0 and ball.Cleared:
         ball_released = true
         _return_ball(ball)
      else:
         ball.QueueTime -= delta
         
