@tool
extends RigidBody3D
class_name GameObject
## a networked physics object. every machine simulates every GameObject, but only
## the machine in [member OwnerID] is the authority: it broadcasts the object's
## state and everyone else steers their copy towards it.[br][br]
## ownership rules:[br]
## - picking an object up always claims it ([method claim] with by_pickup)[br]
## - an owned object that touches an unowned one claims it (collisions never steal)[br]
## - every claim bumps [member ClaimCounter]. higher counter wins, ties go to the lower ID[br]
## - clearing an object releases it

const TRANSFORM_DATA_SIZE: int   = 4*12
const REGISTRY_ID_SIZE   : int   = 4
## size in bytes of [member ClaimCounter] on the wire
const COUNTER_SIZE       : int   = 4
## [member OwnerID] + [member ClaimCounter], prepended to transform data. see [method generate_state_data]
const OWNERSHIP_DATA_SIZE: int   = 4 + COUNTER_SIZE
## how hard a remote copy is pulled towards the owner's state, per second
const CORRECTION_RATE    : float = 15.0
## past this distance the remote copy snaps instead of sliding
const SNAP_DISTANCE      : float = 2.0
## the owner's last state is projected forward along its velocity for at most this long
const MAX_EXTRAPOLATION  : float = 0.25

## emitted on this object when it is cleared, whether locally or by another machine
signal cleared()

## networking hooks shared by every GameObject. see [GameObject.EventBus]
static var Events  : EventBus   = EventBus.new()
static var Registry: Dictionary = {}
## this machine's network ID. set by whoever owns the network connection
static var LocalID : int        = 0

var RegistryID  : int  = 0
## network ID of the authority for this object. 0 means unowned
var OwnerID     : int  = 0
## bumped by every claim and clear. stale messages carry a lower count and are ignored
var ClaimCounter: int  = 0
var IsCleared   : bool = false

var _HasTarget  : bool       = false
var _TargetPos  : Vector3    = Vector3.ZERO
var _TargetRot  : Quaternion = Quaternion.IDENTITY
var _TargetLinVel: Vector3   = Vector3.ZERO
var _TargetAngVel: Vector3   = Vector3.ZERO
var _TargetTime : int        = 0
var _SentAsleep : bool       = false

## signals the network layer listens to, so it does not have to connect to every object
class EventBus:
   ## this machine just claimed [param obj]
   signal object_claimed(obj: GameObject)
   ## this machine just cleared [param obj]
   signal object_cleared(obj: GameObject)

func _ready() -> void:
   if Engine.is_editor_hint(): return
   # spawners assign deterministic IDs before adding the object. anything placed
   # directly in a scene falls back to its node path, which matches on every machine
   if RegistryID == 0: register(str(get_path()).hash())
   contact_monitor = true
   max_contacts_reported = max(max_contacts_reported, 4)
   body_entered.connect(_on_body_entered)

func _enter_tree() -> void:
   # balls leave the tree when cleared and come back when the machine returns them
   IsCleared = false

func _notification(what: int) -> void:
   if what == NOTIFICATION_PREDELETE and Registry.get(RegistryID) == self:
      Registry.erase(RegistryID)

## set this object's [member RegistryID]. must match on every machine
func register(id: int) -> void:
   if Registry.get(RegistryID) == self: Registry.erase(RegistryID)
   RegistryID = id
   if Registry.has(id) and is_instance_valid(Registry[id]) and Registry[id] != self:
      push_warning("GameObject registry collision on " + str(id))
   Registry[id] = self

# ========= #
# ownership #
# ========= #
## take ownership on this machine. a pickup always succeeds; a collision only
## takes unowned objects. returns whether we own it afterwards
func claim(by_pickup: bool) -> bool:
   if IsCleared: return false
   if OwnerID == LocalID: return true
   if OwnerID != 0 and not by_pickup: return false
   ClaimCounter += 1
   OwnerID = LocalID
   _HasTarget = false
   Events.object_claimed.emit(self)
   return true

## apply another machine's claim. returns whether it won
func accept_claim(owner_id: int, counter: int) -> bool:
   if owner_id == OwnerID and counter == ClaimCounter: return true
   if counter < ClaimCounter: return false
   if counter == ClaimCounter and OwnerID != 0 and owner_id > OwnerID: return false
   OwnerID = owner_id
   ClaimCounter = counter
   return true

## a peer left: whatever it owned is now unowned
static func release_all_owned_by(owner_id: int) -> void:
   for obj in Registry.values():
      if is_instance_valid(obj) and obj.OwnerID == owner_id: obj.OwnerID = 0

# ======== #
# clearing #
# ======== #
## subclasses call this when their clear condition is met. only the owner clears
## an owned object; everyone else waits for the owner's broadcast
func try_clear() -> void:
   if Engine.is_editor_hint(): cleared.emit(); return
   if IsCleared or not is_inside_tree(): return
   if OwnerID != 0 and OwnerID != LocalID: return
   ClaimCounter += 1
   _clear()
   Events.object_cleared.emit(self)

## apply a clear broadcast by another machine
func remote_clear(counter: int) -> void:
   if IsCleared or not is_inside_tree(): return
   if counter < ClaimCounter: return
   ClaimCounter = counter
   _clear()

func _clear() -> void:
   IsCleared = true
   OwnerID = 0
   _HasTarget = false
   cleared.emit()

# ========== #
# networking #
# ========== #
## true when this machine should broadcast this object's state: we own it and it
## is moving. a sleeping object is sent once more, then stays quiet until it wakes
func should_broadcast() -> bool:
   if OwnerID != LocalID or IsCleared or not is_inside_tree(): return false
   if not sleeping:
      _SentAsleep = false
      return true
   if _SentAsleep: return false
   _SentAsleep = true
   return true

## [lb]OwnerID u32[rb][lb]ClaimCounter u32[rb] followed by [method generate_transform_data]
func generate_state_data() -> PackedByteArray:
   var data: PackedByteArray = []
   data.resize(OWNERSHIP_DATA_SIZE)
   data.encode_u32(0, OwnerID)
   data.encode_u32(4, ClaimCounter)
   data.append_array(generate_transform_data())
   return data

## apply a state update from [method generate_state_data]. receiving one is an
## implicit claim by the sender, so it is dropped if that claim loses
func on_state_data(data: PackedByteArray) -> void:
   if IsCleared or not is_inside_tree(): return
   if data.size() < OWNERSHIP_DATA_SIZE + TRANSFORM_DATA_SIZE: return
   if not accept_claim(data.decode_u32(0), data.decode_u32(4)): return
   if OwnerID == LocalID: return
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

## stores the owner's state as a target. [method _integrate_forces] moves towards
## it instead of snapping, which keeps remote copies from jittering
func on_transform_data(data: PackedByteArray) -> void:
   _TargetPos    = Vector3(data.decode_float(0),  data.decode_float(4),  data.decode_float(8))
   _TargetRot    = Quaternion.from_euler(Vector3(data.decode_float(12), data.decode_float(16), data.decode_float(20)))
   _TargetLinVel = Vector3(data.decode_float(24), data.decode_float(28), data.decode_float(32))
   _TargetAngVel = Vector3(data.decode_float(36), data.decode_float(40), data.decode_float(44))
   _TargetTime   = Time.get_ticks_msec()
   _HasTarget    = true
   sleeping      = false

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
   if Engine.is_editor_hint() or not _HasTarget or OwnerID == LocalID: return
   var age: float = min((Time.get_ticks_msec() - _TargetTime) / 1000.0, MAX_EXTRAPOLATION)
   var target_pos: Vector3 = _TargetPos + _TargetLinVel * age
   var t: float = 1.0 - exp(-CORRECTION_RATE * state.step)
   if state.transform.origin.distance_to(target_pos) > SNAP_DISTANCE: t = 1.0
   var rot: Quaternion = state.transform.basis.get_rotation_quaternion().slerp(_TargetRot, t)
   state.transform        = Transform3D(Basis(rot), state.transform.origin.lerp(target_pos, t))
   state.linear_velocity  = state.linear_velocity.lerp(_TargetLinVel, t)
   state.angular_velocity = state.angular_velocity.lerp(_TargetAngVel, t)

# ========== #
# collisions #
# ========== #
func _on_body_entered(body: Node) -> void:
   if body is GameObject:
      # objects we own infect unowned objects they touch
      if OwnerID == LocalID: (body as GameObject).claim(false)
   elif body is Player and OwnerID == 0:
      # the local player bumped it. remote players have no collision, so this is always us
      claim(false)
