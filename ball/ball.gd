extends GameObject
class_name Ball

const BALL_TEXTURE := preload("res://ball/ball.png") 
const QUEUE_TIME: float = 5.0

const KILL_DEPTH: float = -5.0
const KILL_DIST : float = 3.0 

const MAX_WEIGHT: float = 100.0
const MIN_WEIGHT: float = 5.0
const MAX_BOUNCE: float = 0.75
const MIN_BOUNCE: float = 0.25

signal cleared()

@onready var BallMesh: MeshInstance3D = $BallMesh

var ParentBallMachine: BallMachine
var QueueTime: float = QUEUE_TIME
var Cleared: bool = false

func _ready() -> void:
   super()
   
   var attribute_a: float = randf()
   var attribute_b: float = randf_range(0.5,0.8)
   
   var mat := StandardMaterial3D.new()
   mat.albedo_color = Color.from_ok_hsl(attribute_a,0.75,attribute_b)
   mat.albedo_texture = BALL_TEXTURE
   mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
   
   BallMesh.material_override = mat
   
   mass = 30 #lerp(MIN_WEIGHT, MAX_WEIGHT, 1-attribute_a)
   
   var phys_mat := PhysicsMaterial.new()
   phys_mat.bounce = 0.5 #lerp(MIN_BOUNCE, MAX_BOUNCE, inverse_lerp(0.5,0.8,attribute_b))
   physics_material_override = phys_mat
   
   set_name("Ball_" + str(int(attribute_a*100)) + "_" + str(int(attribute_b)))
   
func _process(_delta: float) -> void:
   if (abs(global_position.distance_to(ParentBallMachine.global_position)) > KILL_DIST\
   and linear_velocity.length() < 0.5 and angular_velocity.length() < 0.1 ) \
   or position.y < KILL_DEPTH:
      cleared.emit()

      
   
