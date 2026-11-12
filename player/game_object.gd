extends RigidBody3D
class_name GameObject

const TRANSFORM_DATA_SIZE: int = 4*12
const REGISTRY_ID_SIZE: int = 4
const COUNTER_SIZE: int = 4
const OWNERSHIP_DATA_SIZE: int = 4 + COUNTER_SIZE
const CORRECTION_RATE: float = 15.0
const SNAP_DISTANCE: float = 2.0
const MAX_EXTRAPOLATION: float = 0.25

signal cleared()

static var Events: EventBus = EventBus.new()
static var Registry: Dictionary
static var LocalID: int = 0

var RegistryID: int
var OwnerID: int = 0
var ClaimCounter: int = 0
var IsCleared: bool = false
var IsHeld: bool = false

var _HasTarget: bool = false
var _TargetPos := Vector3.ZERO
var _TargetRot := Quaternion.IDENTITY
var _TargetLinVel := Vector3.ZERO
var _TargetAngVel := Vector3.ZERO
var _TargetTime: int = 0
var _SentAsleep: bool = false

class EventBus:
   signal object_claimed(obj: GameObject)
   signal object_cleared(obj: GameObject)

func _ready() -> void:
   if RegistryID == 0: register(str(get_path()).hash())
   contact_monitor = true
   max_contacts_reported = max(max_contacts_reported, 4)
   body_entered.connect(_handle_body_entered)

func _notification(what: int) -> void:
   if what == NOTIFICATION_PREDELETE and Registry.get(RegistryID) == self:
      Registry.erase(RegistryID)

func register(id: int) -> void:
   if Registry.get(RegistryID) == self: Registry.erase(RegistryID)
   RegistryID = id
   if Registry.has(id) and is_instance_valid(Registry[id]) and Registry[id] != self:
      push_warning("GameObject registry collision on " + str(id))
   Registry[id] = self

# ========= #
# ownership #
# ========= #
func claim(by_pickup: bool) -> bool:
   if IsCleared: return false
   if OwnerID == LocalID: return true
   if OwnerID != 0 and not by_pickup: return false
   ClaimCounter += 1
   OwnerID = LocalID
   _HasTarget = false
   Events.object_claimed.emit(self)
   return true

func accept_claim(owner_id: int, counter: int) -> bool:
   if owner_id == OwnerID and counter == ClaimCounter: return true
   # higher counter wins, ties go to the lower id
   if counter < ClaimCounter: return false
   if counter == ClaimCounter and OwnerID != 0 and owner_id > OwnerID: return false
   OwnerID = owner_id
   ClaimCounter = counter
   return true

static func release_all_owned_by(owner_id: int) -> void:
   for obj in Registry.values():
      if is_instance_valid(obj) and obj.OwnerID == owner_id: obj.OwnerID = 0

# ======== #
# clearing #
# ======== #
func try_clear() -> void:
   if IsHeld or IsCleared: return
   if OwnerID != 0 and OwnerID != LocalID: return
   ClaimCounter += 1
   _clear()
   Events.object_cleared.emit(self)

func remote_clear(counter: int) -> void:
   if IsCleared or counter < ClaimCounter: return
   ClaimCounter = counter
   _clear()

func _clear() -> void:
   IsCleared = true
   OwnerID = 0
   _HasTarget = false
   cleared.emit()

# ============= #
# data handling #
# ============= #
func should_broadcast() -> bool:
   if OwnerID != LocalID or IsCleared: return false
   if not sleeping:
      _SentAsleep = false
      return true
   # one last update after falling asleep
   if _SentAsleep: return false
   _SentAsleep = true
   return true

func generate_state_data() -> PackedByteArray:
   var data: PackedByteArray = []
   data.resize(OWNERSHIP_DATA_SIZE)
   data.encode_u32(0, OwnerID)
   data.encode_u32(4, ClaimCounter)
   data.append_array(generate_transform_data())
   return data

func on_state_data(data: PackedByteArray) -> void:
   if IsCleared or data.size() < OWNERSHIP_DATA_SIZE + TRANSFORM_DATA_SIZE: return
   if accept_claim(data.decode_u32(0), data.decode_u32(4)):
      on_transform_data(data.slice(OWNERSHIP_DATA_SIZE))

func generate_transform_data() -> PackedByteArray:
   var data: PackedByteArray = []
   data.resize(TRANSFORM_DATA_SIZE)
   data.encode_float(0,  global_position.x)
   data.encode_float(4,  global_position.y)
   data.encode_float(8,  global_position.z)
   data.encode_float(12, global_rotation.x)
   data.encode_float(16, global_rotation.y)
   data.encode_float(20, global_rotation.z)
   data.encode_float(24, linear_velocity.x)
   data.encode_float(28, linear_velocity.y)
   data.encode_float(32, linear_velocity.z)
   data.encode_float(36, angular_velocity.x)
   data.encode_float(40, angular_velocity.y)
   data.encode_float(44, angular_velocity.z)
   return data

func on_transform_data(data: PackedByteArray) -> void:
   _TargetPos    = Vector3(data.decode_float(0),  data.decode_float(4),  data.decode_float(8))
   _TargetRot    = Quaternion.from_euler(Vector3(data.decode_float(12), data.decode_float(16), data.decode_float(20)))
   _TargetLinVel = Vector3(data.decode_float(24), data.decode_float(28), data.decode_float(32))
   _TargetAngVel = Vector3(data.decode_float(36), data.decode_float(40), data.decode_float(44))
   _TargetTime   = Time.get_ticks_msec()
   _HasTarget    = true
   sleeping      = false

func _handle_body_entered(body: Node) -> void:
   if body is GameObject:
      if OwnerID == LocalID: (body as GameObject).claim(false)
   elif body is Player and OwnerID == 0:
      claim(false)

# move towards the owner's state instead of snapping to it
func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
   if not _HasTarget or OwnerID == LocalID: return
   var age: float = min((Time.get_ticks_msec() - _TargetTime) / 1000.0, MAX_EXTRAPOLATION)
   var target_pos: Vector3 = _TargetPos + _TargetLinVel * age
   var t: float = 1.0 - exp(-CORRECTION_RATE * state.step)
   if state.transform.origin.distance_to(target_pos) > SNAP_DISTANCE: t = 1.0
   var rot: Quaternion = state.transform.basis.get_rotation_quaternion().slerp(_TargetRot, t)
   state.transform        = Transform3D(Basis(rot), state.transform.origin.lerp(target_pos, t))
   state.linear_velocity  = state.linear_velocity.lerp(_TargetLinVel, t)
   state.angular_velocity = state.angular_velocity.lerp(_TargetAngVel, t)
