extends RigidBody3D
class_name GameObject

static var Registry: Dictionary
var RegistryID: int

func _ready() -> void:
   RegistryID = randi()
   while Registry.has(RegistryID):
      RegistryID = randi()
   Registry[RegistryID] = self
