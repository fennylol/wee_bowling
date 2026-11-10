extends Node3D
class_name BallMachine

const BALL_NODE: PackedScene = preload("res://ball/Ball.tscn")
const MIN_BALL_GAP: float = 1.5

var MaxBalls: int = 4
var BallNodes: Array[Ball]


func _ready() -> void:
   for i in MaxBalls:
      var new_ball: Ball = BALL_NODE.instantiate()
      new_ball.register(("%s:ball:%d" % [get_path(), i]).hash())
      new_ball.ParentBallMachine = self
      new_ball.cleared.connect(_handle_cleared_ball.bind(new_ball))
      BallNodes.append(new_ball)

func _handle_cleared_ball(ball:Ball) -> void:
   ball.QueueTime = ball.QUEUE_TIME
   ball.Cleared = false
   remove_child(ball)

func _return_ball(ball: Ball) -> void:
   ball.position = Vector3(0,1,-0.1)
   ball.linear_velocity = Vector3(0.0,0.0,-3.5) * basis
   ball.Cleared = true
   add_child(ball)

func _process(delta: float) -> void:
   var ball_released: bool = false
   for ball:Ball in BallNodes:
      if ball_released:
         ball.QueueTime += MIN_BALL_GAP
      elif ball.QueueTime <= 0.0 and not ball.Cleared:
         ball_released = true
         _return_ball(ball)
      else:
         ball.QueueTime -= delta
         
