extends Node3D
class_name Dummy

var NetworkID : int

## NODES AND TEXTURES
@onready var Body: Node3D = $DummyMesh
@onready var FakeEyes: Node3D = $FakeEyes
@onready var NameLabel: Label3D = $NameLabel


## MOVEMENT DATA
var velocity := Vector3.ZERO
var _net_pos := Vector3.ZERO
var _net_rot := Vector3.ZERO
var _net_vel := Vector3.ZERO
var _has_net_state: bool = false
var _time_since_packet: float = 0.0
const EXTRAPOLATION_LIMIT: float = 0.5  # seconds


func _physics_process(delta: float) -> void:
   if not _has_net_state: return

   _time_since_packet += delta
   if _time_since_packet < EXTRAPOLATION_LIMIT:
      _net_pos += _net_vel * delta   # only extrapolate while data is fresh

   var t := 1.0 - exp(-20.0 * delta)
   position = position.lerp(_net_pos, t)

   #FakeEyes.quaternion = quaternion.slerp(Quaternion.from_euler(_net_rot), t)
   FakeEyes.rotation.x = clamp(_net_rot.x, -PI/2, PI/2)
   rotation.y = _net_rot.y
   
   velocity = _net_vel

func set_name_tag(new_name: String) -> void:
   NameLabel.text = new_name

func recieve_transform_data(data: PackedByteArray) -> void:
   _net_pos = Vector3(data.decode_float(0),  data.decode_float(4),  data.decode_float(8))
   _net_rot = Vector3(data.decode_float(12), data.decode_float(16), data.decode_float(20))
   _net_vel = Vector3(data.decode_float(24), data.decode_float(28), data.decode_float(32))
   
   
   #var flags := data.decode_u8(36)
   #L_HAND.texture = HAND_IMG if flags & (1 << 0) else POINT_IMG
   #R_HAND.texture = HAND_IMG if flags & (1 << 1) else POINT_IMG
   #var lefthand_dir = 0 if flags & (1 << 0) else 90
   #var righthand_dir = 0 if flags & (1 << 1) else 90
   #BODY.point_with_left(lefthand_dir)
   #BODY.point_with_right(righthand_dir)
   
   _has_net_state = true
   _time_since_packet = 0.0
   
