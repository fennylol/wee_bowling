extends CharacterBody3D
class_name Player

const SPEED = 5.0
const JUMP_VELOCITY = 4.5
const KILL_DEPTH: float = -5.0
const TRANSFORM_DATA_SIZE = 4*9
const REGISTRY_ID_SIZE: int = 4

static var Registry: Dictionary
var RegistryID: int

@onready var _Camera = $Camera3D
@onready var ObjCatcher: Area3D = $Camera3D/ObjCatcher
@onready var ObjectVisualizerMesh: MeshInstance3D = $Camera3D/ObjCatcher/ObjectVisualizerMesh

signal grabbed_object(registry_id: int, released: bool)

var Enabled: bool = false:
   set(new_val):
      Enabled = new_val
      if Enabled:
         Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
      else:
         Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

var _SadMaterial := StandardMaterial3D.new()
var _CanGrabMatial := StandardMaterial3D.new()
var _DidGrabMatial := StandardMaterial3D.new()

var GrabbableObj: GameObject = null
var GrabbedObj: GameObject = null

var GrabForce: float = 150.0
var GRAB_DAMPING: float = 0.95

# ╭----------------╮
# |    UTILITY     |
# ╰----------------╯
func register_input(input_name: String, keycode: Key):
   InputMap.add_action(input_name)
   var event = InputEventKey.new()
   event.keycode = keycode
   InputMap.action_add_event(input_name, event)


func generate_transform_data() -> PackedByteArray:
   var data := PackedByteArray()
   data.resize(TRANSFORM_DATA_SIZE)
   
   data.encode_float(0,  position.x)
   data.encode_float(4,  position.y) 
   data.encode_float(8,  position.z)
   data.encode_float(12, _Camera.rotation.x)
   data.encode_float(16, rotation.y) 
   data.encode_float(20, rotation.z)
   data.encode_float(24, velocity.x)
   data.encode_float(28, velocity.y)
   data.encode_float(32, velocity.z)
   
   return data


func _ready():
   register_input("jump", KEY_SPACE)
   register_input("left", KEY_A)
   register_input("down", KEY_S)
   register_input("right", KEY_D)
   register_input("up", KEY_W)
   register_input("menu", KEY_ESCAPE)
   
   _SadMaterial.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
   _SadMaterial.albedo_color = Color.RED
   _SadMaterial.albedo_color.a = 0.25
   
   _CanGrabMatial.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
   _CanGrabMatial.albedo_color = Color.GREEN
   _CanGrabMatial.albedo_color.a = 0.25
   
   _DidGrabMatial.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
   _DidGrabMatial.albedo_color = Color.DEEP_SKY_BLUE
   _DidGrabMatial.albedo_color.a = 0.25
   
   ObjCatcher.body_entered.connect(_handle_body_entered)
   ObjCatcher.body_exited.connect(_handle_body_exited)

func _handle_body_entered(body: Node3D) -> void:
   if body is GameObject:
      GrabbableObj = body
      
func _handle_body_exited(body: Node3D) -> void:
   if body is GameObject:
      GrabbableObj = null
      for other_body in ObjCatcher.get_overlapping_bodies():
         if other_body is GameObject:
            GrabbableObj = other_body
            break

# mouse
func _unhandled_input(event):
   if event is InputEventMouseMotion and Enabled:
      rotate_y(-event.relative.x * .005)
      _Camera.rotate_x(-event.relative.y * .005)
      _Camera.rotation.x = clamp(_Camera.rotation.x, -PI/2, PI/2)

# mouse capture
func _process(_delta):
   if Input.is_action_just_pressed("grab") and GrabbableObj:
      grabbed_object.emit(GrabbableObj.RegistryID, false)
      GrabbedObj = GrabbableObj
   if Input.is_action_just_released("grab") and GrabbedObj:
      grabbed_object.emit(GrabbedObj.RegistryID, true)
      GrabbedObj = null
   
   if position.y <= KILL_DEPTH:
      position = Vector3.ZERO
   
   ObjectVisualizerMesh.mesh.material = _DidGrabMatial if GrabbedObj else \
                                        _CanGrabMatial if GrabbableObj else \
                                        _SadMaterial 

# movement
func _physics_process(delta):
   if !Enabled: return
   if not is_on_floor(): velocity.y -= gravity * delta
   
   if Input.is_action_just_pressed("jump") and is_on_floor(): velocity.y = JUMP_VELOCITY
   
   var input_dir = Input.get_vector("left", "right", "up", "down")
   var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
   if direction:
      velocity.x = direction.x * SPEED
      velocity.z = direction.z * SPEED
   else:
      velocity.x = move_toward(velocity.x, 0, SPEED)
      velocity.z = move_toward(velocity.z, 0, SPEED)
   
   if GrabbedObj:
      var vec_to := ObjCatcher.global_position - GrabbedObj.global_position
      GrabbedObj.linear_velocity *= GRAB_DAMPING 
      GrabbedObj.linear_velocity += vec_to * delta * GrabForce
      grabbed_object.emit(GrabbedObj.RegistryID, false)
   
   move_and_slide()
