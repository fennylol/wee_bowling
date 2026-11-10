extends RigidBody3D
class_name GameObject

const TRANSFORM_DATA_SIZE: int = 4*12
const REGISTRY_ID_SIZE: int = 4

static var Registry: Dictionary
var RegistryID: int

func _ready() -> void:
   RegistryID = Registry.size()#randi()
   while Registry.has(RegistryID):
      print("dupelicate")
      #RegistryID = randi()
   Registry[RegistryID] = self

func generate_transform_data() -> PackedByteArray:
   var data: PackedByteArray = []
   data.resize(TRANSFORM_DATA_SIZE)
   data.encode_float(0,  position.x)
   data.encode_float(4,  position.y) 
   data.encode_float(8,  position.z)
   data.encode_float(12, rotation.x)
   data.encode_float(16, rotation.y) 
   data.encode_float(20, rotation.z)
   data.encode_float(24, linear_velocity.x)
   data.encode_float(28, linear_velocity.y) 
   data.encode_float(32, linear_velocity.z)
   data.encode_float(36, angular_velocity.x)
   data.encode_float(40, angular_velocity.y) 
   data.encode_float(44, angular_velocity.z)
   return data

func on_transform_data(data: PackedByteArray) -> void:
   position         = Vector3(data.decode_float(0),  data.decode_float(4),  data.decode_float(8))
   rotation         = Vector3(data.decode_float(12), data.decode_float(16), data.decode_float(20))
   linear_velocity  = Vector3(data.decode_float(24), data.decode_float(28), data.decode_float(32))
   angular_velocity = Vector3(data.decode_float(36), data.decode_float(40), data.decode_float(44))

   
