extends CharacterBody3D
class_name Player

signal grabbed_object(registry_id: int, released: bool)

## position (3) + body rotation quaternion (4) + hands pitch (1) + velocity (3)
const TRANSFORM_DATA_SIZE: int = 4*11

const _UNITS_PER_METRE   : float = 40
const _CAMERA_WALL_MARGIN: float = 0.2

const _JUMP_HEIGHT       : float = 40.0 / _UNITS_PER_METRE
const _JUMP_VELOCITY     : float = sqrt(2.0 * _BASE_GRAVITY * _JUMP_HEIGHT)
const _GRAVITY_SCALE     : float = 0.58
const _AIR_CONTROL_SCALE : float = 1.25
const _BASE_GRAVITY      : float = 800.0 / _UNITS_PER_METRE
const _GRAVITY           : float = _BASE_GRAVITY * _GRAVITY_SCALE

const _GROUND_SPEED        : float = 5
const _GROUND_ACCELLERATION: float = 10.0
const _GROUND_ACCEL_SPEED  : float = 400.0 / _UNITS_PER_METRE
const _GROUND_DECELLERATION: float = 200.0 / _UNITS_PER_METRE
const _GROUND_FRICTION     : float = 5.0

const _AIR_ACCELLERATION   : float = 10.0 * _AIR_CONTROL_SCALE
const _AIR_CAP_SLOW        : float = 80.0 / _UNITS_PER_METRE * _AIR_CONTROL_SCALE
const _AIR_CAP_FAST        : float = 50.0 / _UNITS_PER_METRE * _AIR_CONTROL_SCALE

const _WALL_DETECT_DIST    : float = 8.0 / _UNITS_PER_METRE
const _WALL_JUMP_UP        : float = _JUMP_VELOCITY
const _WALL_JUMP_OUT       : float = _JUMP_VELOCITY
const _WALL_JUMP_FATIGUE   : float = 0.5
const _WALL_JUMP_LOCKOUT   : float = 0.2
const _WALL_JUMP_RECOVERY  : float = 1.25
const _WALL_JUMP_DRIFT_TIME: float = 0.5
var _WallJumpStrength      : float = 1.0
var _TimeSinceWallJump     : float = INF
var _WallNormal            : Vector3 = Vector3.ZERO

const _AIR_JUMP_VELOCITY   : float = _JUMP_VELOCITY
const _MAX_AIR_JUMPS       : int   = 1
var _AirJumpsLeft          : int   = 0

const _GROUND_DASH_DISTANCE: float = 10.0
const _GROUND_DASH_SPEED   : float = 14.7
const _AIR_DASH_DISTANCE   : float = 8.0
const _AIR_DASH_SPEED      : float = 17.0
const _DASH_LOCKOUT        : float = 0.25
const _MAX_AIR_DASHES      : int   = 1
var _AirDashesLeft         : int   = 0
var _DashTimeLeft          : float = 0.0
var _DashLockoutLeft       : float = 0.0
var _DashVelocity          : Vector3 = Vector3.ZERO
var _PreDashSpeed          : float = 0.0
var _IsAirDash             : bool  = false

const _SLIDE_START_SPEED   : float = 350.0 / _UNITS_PER_METRE  # deadlock.wiki/Movement
const _SLIDE_END_SPEED     : float = 3.0             # on flat ground the slide ends below this; guess
const _SLIDE_FRICTION      : float = 0.5             # fraction of speed lost per second; guess
const _SLIDE_TURN_RATE     : float = deg_to_rad(60)  # radians per second of steering; guess
const _SLIDE_MIN_SLOPE     : float = deg_to_rad(5)   # steeper floors start a slide at any speed
const _SLIDE_LEAN          : float = deg_to_rad(45)
var _IsSliding             : bool  = false
var _BodyMeshRest          : Transform3D

const KILL_DEPTH    : float = -5.0
const GRAB_FORCE    : float = 150.0
const GRAB_DAMPING  : float = 0.95
const KNOCKOUT_SPEED: float = 10
const RECOVERY_TIME : float = 0.5

const THROW_SOUNDS: Array[AudioStream] = [
   preload("res://player/sounds/throw_0.mp3"),
   preload("res://player/sounds/throw_1.mp3"),
   preload("res://player/sounds/throw_2.mp3"),
   preload("res://player/sounds/throw_3.mp3"),
   preload("res://player/sounds/throw_4.mp3")]
const RARE_THROW_SOUNDS: Array[AudioStream] = [
   preload("res://player/sounds/throw_rare_0.mp3"),
   preload("res://player/sounds/throw_rare_1.mp3")]

@onready var _FPVCamera : Camera3D            = $FirstPersonCamera
@onready var _OTSCamera : Camera3D            = $FirstPersonCamera/ThirdPersonCamera
@onready var _CameraRay : RayCast3D           = $FirstPersonCamera/ThirdPersonCameraRay
@onready var _ObjCatcher: Area3D              = $FirstPersonCamera/ObjCatcher
@onready var _FakeEyes  : Node3D              = $FirstPersonCamera/FakeEyes
@onready var _BodyMesh  : MeshInstance3D      = $BodyMesh
@onready var _Collider  : CollisionShape3D    = $CollisionShape3D
@onready var _Mouth     : AudioStreamPlayer3D = $mouth_for_screaming
@onready var _ThumpZone : Area3D              = $thumpzone
@onready var _Ragdoll   : RigidBody3D         = $seperator/Ragdoll


var Enabled : bool  = false:
   set(new_val):
      Enabled = new_val
      Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if Enabled else Input.MOUSE_MODE_VISIBLE
var _LookSens: float = 0.005

var GrabbableObj : GameObject = null
var GrabbedObj   : GameObject = null
var KnockoutTime : float = 0.0
var KnockoutTimer: float = -RECOVERY_TIME

var SPIN_FORCE: float = 20.0
var SPIN_DAMPING: float = 0.95


func _ready():
   var register_input: Callable = func(input_name: String, keycode: Key):
      if not InputMap.get_actions().has(input_name):
         InputMap.add_action(input_name)
      var event := InputEventKey.new()
      event.keycode = keycode
      InputMap.action_add_event(input_name, event)
   var register_mouse: Callable = func(input_name: String, mousebutton: MouseButton):
      if not InputMap.get_actions().has(input_name):
         InputMap.add_action(input_name)
      var event := InputEventMouseButton.new()
      event.button_index = mousebutton
      InputMap.action_add_event(input_name, event)


   register_input.call("jump",  KEY_SPACE)
   register_input.call("left",  KEY_A)
   register_input.call("down",  KEY_S)
   register_input.call("right", KEY_D)
   register_input.call("up",    KEY_W)
   register_input.call("menu",  KEY_ESCAPE)
   register_input.call("dash",  KEY_SHIFT)
   register_input.call("slide", KEY_CTRL)

   register_mouse.call("grab",  MOUSE_BUTTON_LEFT)
   register_mouse.call("RMB",   MOUSE_BUTTON_RIGHT)
   register_mouse.call("slide", MOUSE_BUTTON_XBUTTON1)

   _CameraRay.target_position = _OTSCamera.position
   _CameraRay.collision_mask = collision_mask
   _CameraRay.add_exception(self)
   _BodyMeshRest = _BodyMesh.transform

   _ThumpZone.body_entered.connect(_on_thumpzone_body_entered)


func generate_transform_data() -> PackedByteArray:
   var data := PackedByteArray()
   data.resize(TRANSFORM_DATA_SIZE)
   var body_rot := transform.basis.get_rotation_quaternion()

   data.encode_float(0,  position.x)
   data.encode_float(4,  position.y)
   data.encode_float(8,  position.z)
   data.encode_float(12, body_rot.x)
   data.encode_float(16, body_rot.y)
   data.encode_float(20, body_rot.z)
   data.encode_float(24, body_rot.w)
   data.encode_float(28, _FPVCamera.rotation.x)
   data.encode_float(32, velocity.x)
   data.encode_float(36, velocity.y)
   data.encode_float(40, velocity.z)

   return data


# =============== #
# handle movement #
# =============== #
func _physics_process(delta: float) -> void:
   if position.y <= KILL_DEPTH:
      position = Vector3.ZERO

   KnockoutTimer -= delta
   if KnockoutTimer > 0.0:
      _handle_knockout(delta)
   elif KnockoutTimer > -RECOVERY_TIME:
      _handle_recovery(delta)
   else:
      _handle_movement(delta)
      _handle_grabbed_object(delta)

   move_and_slide()
   _place_ots_camera()


func _handle_movement(delta: float) -> void:
   var input_dir := Input.get_vector("left", "right", "up", "down")
   var wish_dir := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
   # and not (GrabbedObj and Input.is_action_pressed("spin")):

   _TimeSinceWallJump += delta
   if is_on_floor():
      _WallJumpStrength = 1.0
      _TimeSinceWallJump = INF
      _WallNormal = Vector3.ZERO
      _AirJumpsLeft = _MAX_AIR_JUMPS
      _AirDashesLeft = _MAX_AIR_DASHES

   _DashLockoutLeft -= delta
   if Input.is_action_just_pressed("dash"):
      _try_dash(wish_dir)
   _update_slide_state()
   if _DashTimeLeft > 0:
      _handle_dash(delta)
   elif is_on_floor() and Input.is_action_pressed("jump"):
      _IsSliding = false
      velocity.y = _JUMP_VELOCITY
      _handle_air_physics(wish_dir, delta)
   elif _IsSliding:
      _handle_slide_physics(wish_dir, delta)
   elif is_on_floor():
      _handle_ground_physics(wish_dir, delta)
   else:
      velocity.y -= _GRAVITY * delta
      if Input.is_action_just_pressed("jump") and not _try_wall_jump() and _AirJumpsLeft > 0:
         _AirJumpsLeft -= 1
         velocity.y = _AIR_JUMP_VELOCITY
      _handle_air_physics(wish_dir, delta)


func _handle_slide_physics(wish_dir: Vector3, delta: float) -> void:
   var horizontal := Vector3(velocity.x, 0, velocity.z)

   var downhill: Vector3 = (Vector3.DOWN * _GRAVITY).slide(get_floor_normal())
   horizontal += Vector3(downhill.x, 0, downhill.z) * delta

   horizontal *= maxf(1.0 - _SLIDE_FRICTION * delta, 0.0)

   if wish_dir != Vector3.ZERO and horizontal.dot(wish_dir) > 0:
      var turn: float = horizontal.signed_angle_to(wish_dir, Vector3.UP)
      horizontal = horizontal.rotated(Vector3.UP, clampf(turn, -_SLIDE_TURN_RATE * delta, _SLIDE_TURN_RATE * delta))

   velocity.x = horizontal.x
   velocity.z = horizontal.z
   if horizontal.length() < _SLIDE_END_SPEED and not _is_on_slope():
      _IsSliding = false


func _handle_ground_physics(wish_dir: Vector3, delta: float) -> void:
   var horizontal := Vector3(velocity.x, 0, velocity.z)
   var speed := horizontal.length()
   if speed > 0:
      var control: float = max(speed, _GROUND_DECELLERATION)
      var drop: float = control * _GROUND_FRICTION * delta
      horizontal *= max(speed - drop, 0.0) / speed

   var add_speed: float = _GROUND_SPEED - horizontal.dot(wish_dir)
   if add_speed > 0:
      var accel_base: float = max(_GROUND_SPEED, _GROUND_ACCEL_SPEED)
      var accel_speed: float = min(_GROUND_ACCELLERATION * accel_base * delta, add_speed)
      horizontal += accel_speed * wish_dir

   velocity.x = horizontal.x
   velocity.z = horizontal.z


func _handle_air_physics(wish_dir: Vector3, delta: float) -> void:
   var horizontal_speed: float = Vector2(velocity.x, velocity.z).length()
   var air_cap: float = _AIR_CAP_FAST if horizontal_speed > _GROUND_SPEED else _AIR_CAP_SLOW
   var add_speed: float = min(_GROUND_SPEED, air_cap) - velocity.dot(wish_dir)
   if add_speed > 0:
      var accel_speed: float = min(_AIR_ACCELLERATION * _GROUND_SPEED * delta, add_speed)
      var accel: Vector3 = accel_speed * wish_dir
      var toward_wall: float = accel.dot(_WallNormal)
      if toward_wall < 0:
         accel -= _WallNormal * toward_wall * (1.0 - _ease_since_wall_jump(_WALL_JUMP_DRIFT_TIME))
      velocity += accel


# ============ #
# handle slide #
# ============ #
func _update_slide_state() -> void:
   if not is_on_floor() or not Input.is_action_pressed("slide"):
      _IsSliding = false
      return
   if _DashTimeLeft > 0 and not _IsAirDash:
      _DashTimeLeft = 0.0
      _DashLockoutLeft = _DASH_LOCKOUT
      _IsSliding = true
   elif not _IsSliding:
      _IsSliding = Vector2(velocity.x, velocity.z).length() >= _SLIDE_START_SPEED or _is_on_slope()


func _is_on_slope() -> bool:
   return is_on_floor() and get_floor_normal().angle_to(Vector3.UP) > _SLIDE_MIN_SLOPE


# =========== #
# handle dash #
# =========== #
func _try_dash(wish_dir: Vector3) -> void:
   if _DashTimeLeft > 0 or _DashLockoutLeft > 0:
      return
   _IsAirDash = not is_on_floor()
   if _IsAirDash:
      if _AirDashesLeft <= 0:
         return
      _AirDashesLeft -= 1

   var dash_dir: Vector3 = wish_dir if wish_dir != Vector3.ZERO else -transform.basis.z
   var speed: float = _AIR_DASH_SPEED if _IsAirDash else _GROUND_DASH_SPEED
   var distance: float = _AIR_DASH_DISTANCE if _IsAirDash else _GROUND_DASH_DISTANCE
   _DashVelocity = dash_dir * speed
   _PreDashSpeed = Vector2(velocity.x, velocity.z).length()
   _DashTimeLeft = distance / speed


func _handle_dash(delta: float) -> void:
   velocity.x = _DashVelocity.x
   velocity.z = _DashVelocity.z
   if _IsAirDash:
      velocity.y = 0.0  # air dashes travel flat
   elif not is_on_floor():
      velocity.y -= _GRAVITY * delta  # a ground dash off a ledge still falls

   _DashTimeLeft -= delta
   if _DashTimeLeft <= 0:
      _DashLockoutLeft = _DASH_LOCKOUT
      var exit_velocity: Vector3 = _DashVelocity.normalized() * _PreDashSpeed
      velocity.x = exit_velocity.x
      velocity.z = exit_velocity.z


# =============== #
# handle walljump #
# =============== #
func _try_wall_jump() -> bool:
   if _TimeSinceWallJump < _WALL_JUMP_LOCKOUT:
      return false
   var wall_normal: Vector3 = _find_wall_normal()
   if wall_normal == Vector3.ZERO:
      return false
   var strength: float = lerpf(_WallJumpStrength, 1.0, _ease_since_wall_jump(_WALL_JUMP_RECOVERY))
   _WallJumpStrength = strength * _WALL_JUMP_FATIGUE
   _TimeSinceWallJump = 0.0
   _WallNormal = wall_normal

   var into_wall: float = velocity.dot(wall_normal)
   if into_wall < 0:
      velocity -= wall_normal * into_wall
   velocity += wall_normal * _WALL_JUMP_OUT * strength
   velocity.y = maxf(velocity.y, _WALL_JUMP_UP * strength)
   return true


func _ease_since_wall_jump(duration: float) -> float:
   return smoothstep(0.0, 1.0, clampf(_TimeSinceWallJump / duration, 0.0, 1.0))


func _find_wall_normal() -> Vector3:
   var body_shape := _Collider.shape as CapsuleShape3D
   var probe := CapsuleShape3D.new()
   probe.radius = body_shape.radius + _WALL_DETECT_DIST
   probe.height = body_shape.height

   var query := PhysicsShapeQueryParameters3D.new()
   query.shape = probe
   query.transform = _Collider.global_transform
   query.collision_mask = collision_mask
   query.exclude = [get_rid()]

   var hit: Dictionary = get_world_3d().direct_space_state.get_rest_info(query)
   if hit.is_empty():
      return Vector3.ZERO

   var normal: Vector3 = hit["normal"]
   if absf(normal.y) > 0.7: # floor or ceiling, not a wall
      return Vector3.ZERO
   return Vector3(normal.x, 0, normal.z).normalized()


# ============== #
# handle ragdoll #
# ============== #
func _on_thumpzone_body_entered(body: Node3D) -> void:
   if body is Ball and not body == GrabbedObj \
   and body.linear_velocity.length() >= KNOCKOUT_SPEED \
   and KnockoutTimer < -RECOVERY_TIME:
         _Ragdoll.global_transform = global_transform
         KnockoutTime = sqrt(body.linear_velocity.length())
         KnockoutTimer = KnockoutTime
         _DashTimeLeft = 0.0
         _IsSliding = false
         body.claim(true)


func _handle_knockout(delta: float) -> void:
   print("knocked out")
   global_transform = _Ragdoll.global_transform
   var fov: float = lerp(1, 75, (KnockoutTime-KnockoutTimer)/KnockoutTime)
   _FPVCamera.fov = fov
   _OTSCamera.fov = fov
   if not is_on_floor(): velocity.y -= _GRAVITY * delta


func _handle_recovery(delta: float) -> void:
   print("recovering ", Time.get_unix_time_from_system() )
   var remaining := KnockoutTimer + RECOVERY_TIME
   var to_upright := Quaternion(basis.y.normalized(), Vector3.UP)
   quaternion = Quaternion.IDENTITY.slerp(to_upright, minf(1.0, delta / remaining)) * quaternion
   if not is_on_floor(): velocity.y -= _GRAVITY * delta


# =============== #
# handle grabbing #
# =============== #
func _handle_grabbed_object(delta: float) -> void:
   if GrabbedObj and GrabbedObj.OwnerID != GameObject.LocalID: GrabbedObj = null
   if GrabbedObj:
      var vec_to := _ObjCatcher.global_position - GrabbedObj.global_position
      GrabbedObj.linear_velocity *= GRAB_DAMPING
      GrabbedObj.linear_velocity += vec_to * GRAB_FORCE * delta

      #if Input.is_action_pressed("spin"):
         #var spin_local := Vector3(input_dir.y, 0.0, -input_dir.x)
         #GrabbedObj.angular_velocity += _Camera.global_basis * spin_local * SPIN_FORCE * delta
      #else: GrabbedObj.angular_velocity *= SPIN_DAMPING

      grabbed_object.emit(GrabbedObj.RegistryID, false)


func _find_closest_game_object() -> void:
   if GrabbedObj:
      GrabbedObj.toggle_outline(true)
      return

   if GrabbableObj:
      GrabbableObj.toggle_outline(false)
      GrabbableObj = null

   for body in _ObjCatcher.get_overlapping_bodies():
      if body is GameObject:
         body.toggle_outline(false)
         var body_dist: float = body.global_position.distance_to(_ObjCatcher.global_position)
         var grabbable_dist: float = GrabbableObj.global_position.distance_to(_ObjCatcher.global_position) if GrabbableObj else INF
         if (body_dist < grabbable_dist):
            GrabbableObj = body

   if GrabbableObj:
      GrabbableObj.toggle_outline(true)


# ============= #
# handle inputs #
# ============= #
func _process(_delta: float) -> void:
   if Input.is_action_just_pressed("grab") and GrabbableObj and GrabbableObj.claim(true):
      grabbed_object.emit(GrabbableObj.RegistryID, false)
      GrabbedObj = GrabbableObj
      GrabbedObj.IsHeld = true
   if Input.is_action_just_released("grab") and GrabbedObj:
      if GrabbedObj.linear_velocity.length() > 3.0:
         _Mouth.stream = THROW_SOUNDS[randi_range(0,THROW_SOUNDS.size()-1)] if randi_range(0,25) < 25 else  RARE_THROW_SOUNDS[randi_range(0,RARE_THROW_SOUNDS.size()-1)]
         _Mouth.play()

      grabbed_object.emit(GrabbedObj.RegistryID, true)
      GrabbedObj.IsHeld = false
      GrabbedObj = null

   _find_closest_game_object()

   if Input.is_action_just_pressed("RMB"): _toggle_view()
      

   _BodyMesh.transform = Transform3D(Basis(Vector3.RIGHT, _SLIDE_LEAN) * _BodyMeshRest.basis, _BodyMeshRest.origin) \
      if _IsSliding else _BodyMeshRest

func _toggle_view() -> void:
   if _FPVCamera.current:
      _OTSCamera.current = true
      _FakeEyes.position.y = -0.5
      _ObjCatcher.position.x = 0.5
   else:
      _FPVCamera.current = true
      _FakeEyes.position.y = -0.045
      _ObjCatcher.position.x = 0.0

func _unhandled_input(event):
   if event is InputEventMouseMotion and Enabled and KnockoutTimer < 0.0:
      rotate_object_local(Vector3.UP, -event.relative.x * _LookSens)
      _FPVCamera.rotate_x(-event.relative.y * _LookSens)
      _FPVCamera.rotation.x = clamp(_FPVCamera.rotation.x, -PI/2, PI/2)


func _place_ots_camera() -> void:
   _CameraRay.force_raycast_update()
   var ray_end: Vector3 = _CameraRay.position + _CameraRay.target_position
   if not _CameraRay.is_colliding():
      _OTSCamera.position = ray_end
      return
   var ray_dir: Vector3 = _CameraRay.target_position.normalized()
   var hit_distance: float = _CameraRay.to_local(_CameraRay.get_collision_point()).length()
   _OTSCamera.position = _CameraRay.position + ray_dir * maxf(hit_distance - _CAMERA_WALL_MARGIN, 0.0)
