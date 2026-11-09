@tool
extends GameObject
class_name Pin

signal cleared()

const UPRIGHT_DEGREES: float = 15.0
const KILL_DEPTH: float = -5.0

func _physics_process(_delta: float) -> void:
   if linear_velocity.length() < 0.1 \
   and angular_velocity.length() < 0.1 \
   and basis.y.dot(Vector3.UP) <= cos(deg_to_rad(UPRIGHT_DEGREES)) \
   or position.y <= KILL_DEPTH:
      cleared.emit()
