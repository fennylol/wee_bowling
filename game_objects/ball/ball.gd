extends GameObject
class_name Ball

const QUEUE_TIME: float = 5.0
const KILL_DEPTH: float = -5.0
const KILL_DIST : float = 5.0 
const MAX_WEIGHT: float = 100.0
const MIN_WEIGHT: float = 5.0
const MAX_BOUNCE: float = 0.75
const MIN_BOUNCE: float = 0.25

const BALL_TEXTURE := preload("res://game_objects/ball/ball.png") 
const BONK_SOUNDS: Array[AudioStream] = [
   preload("res://game_objects/ball/sounds/thud_0.mp3"),
   preload("res://game_objects/ball/sounds/thud_1.mp3"),
   preload("res://game_objects/ball/sounds/thud_2.mp3"),
   preload("res://game_objects/ball/sounds/thud_3.mp3"),
   preload("res://game_objects/ball/sounds/thud_4.mp3"),
   preload("res://game_objects/ball/sounds/thud_5.mp3"),
   preload("res://game_objects/ball/sounds/thud_6.mp3")]

@onready var _Mouth: AudioStreamPlayer3D = $mouth_for_screaming
@onready var _BallMesh: MeshInstance3D = $BallMesh

var ParentBallMachine: BallMachine
var QueueTime: float = QUEUE_TIME

func _ready() -> void:
   super()
   body_entered.connect(_handle_collision)
   
   var rng := RandomNumberGenerator.new()
   rng.seed = RegistryID 
   var attribute_a: float = rng.randf()
   var attribute_b: float = rng.randf_range(0.5,0.8)
   _OutlineColor = (Color.from_ok_hsl(attribute_a,0.75,attribute_b)) * 0.6 + (Color.WHITE * 0.4)
   
   _MeshMaterial = StandardMaterial3D.new()
   _MeshMaterial.albedo_color = Color.from_ok_hsl(attribute_a,0.75,attribute_b)
   _MeshMaterial.albedo_texture = BALL_TEXTURE
   _MeshMaterial.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
   _BallMesh.material_override = _MeshMaterial
   
   _BallMesh.mesh = _outline_mesh(_BallMesh.mesh)
   
   mass = 50 #lerp(MIN_WEIGHT, MAX_WEIGHT, 1-attribute_a)
   
   var phys_mat := PhysicsMaterial.new()
   phys_mat.bounce = 0.35 #lerp(MIN_BOUNCE, MAX_BOUNCE, inverse_lerp(0.5,0.8,attribute_b))
   physics_material_override = phys_mat
   
   set_name("Ball_" + str(int(attribute_a*100)) + "_" + str(int(attribute_b)))

func _handle_collision(_body:Node3D) -> void:
   if not _Mouth.playing and not IsHeld \
   and linear_velocity.length() > 3.0:
      _Mouth.volume_linear = lerp(0.1, 1.0, inverse_lerp(3.0, 100.0, linear_velocity.length()))
      _Mouth.stream = BONK_SOUNDS[randi_range(0,BONK_SOUNDS.size()-1)]
      _Mouth.play()  

func _process(_delta: float) -> void:
   if (abs(global_position.distance_to(ParentBallMachine.global_position)) > KILL_DIST \
   and sleeping) or position.y < KILL_DEPTH:
      try_clear()

      
   
