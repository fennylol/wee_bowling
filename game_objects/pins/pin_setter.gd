#@tool
extends Node3D
class_name PinSetter

static var Events: EventBus = EventBus.new()
static var Registry: Dictionary
signal regenerating(generation: int)

const PIN_NODE : PackedScene = preload("res://game_objects/pins/Pin.tscn")
const SPOT_NODE: PackedScene = preload("res://game_objects/pins/spot.tscn")

@export var PinSpacing: float = 1:
   set(new_spacing):
      PinSpacing = new_spacing
      _QueuePinRegeneration = true
@export var MaxPins: int = 10:
   set(new_max):
      MaxPins = max(1, min(new_max, 120))
      _QueuePinRegeneration = true

var SetterID: int = 0
var Generation: int = 0
var _PinNodes: Array[Pin] = []
var _SpotNodes: Array[MeshInstance3D] = []
var _QueuePinRegeneration: bool = true

func _ready() -> void:
   SetterID = str(get_path()).hash()
   Registry[SetterID] = self

# new_generation is only passed when following another peer, so those aren't rebroadcast
func _regenerate_pins(new_generation: int = -1) -> void:
   Generation = Generation + 1 if new_generation < 0 else new_generation
   for pin:Pin in _PinNodes:
      if pin and not pin.is_queued_for_deletion():
         pin.queue_free()
   _PinNodes.clear()
   
   for spot in _SpotNodes:
      if spot and not spot.is_queued_for_deletion():
         spot.queue_free()
   _SpotNodes.clear()
      
   for i:int in MaxPins:
      var y: float = floorf((sqrt(8*i+1)-1)/2.0)
      var x: float = i-((y*(y+2))/2.0)
      y *= 0.85 # technically, real life pins are spaced at an x:y ratio of 20.75/24 (~0.86453) but 0.85 is cleaner.
      
      var pin: Pin = PIN_NODE.instantiate()
      pin.set_name("Pin_"+str(i))
      pin.register(_pin_id(Generation, i))
      pin.position = Vector3(x*PinSpacing, 0, y*PinSpacing)
      pin.cleared.connect(_handle_cleared_pin.bind(pin))
      _PinNodes.append(pin)
      add_child(pin)
      
      var spot:MeshInstance3D = SPOT_NODE.instantiate()
      spot.set_name("Spot_"+str(i))
      spot.position = Vector3(x*PinSpacing, 0, y*PinSpacing)
      _SpotNodes.append(spot)
      add_child(spot)
      
   #_reset_pins()
   _QueuePinRegeneration = false
   if new_generation < 0: Events.regenerated.emit(self)
   regenerating.emit(Generation)

func follow_generation(generation: int) -> void:
   if generation > Generation: _regenerate_pins(generation)

# each generation gets fresh ids so late updates for old pins can't move new ones
func _pin_id(generation: int, index: int) -> int:
   return ("%d:%d:%d" % [SetterID, generation, index]).hash()

func get_standing_mask() -> PackedByteArray:
   var mask: PackedByteArray = []
   mask.resize(ceili(MaxPins / 8.0))
   for i:int in MaxPins:
      var pin = GameObject.Registry.get(_pin_id(Generation, i))
      if is_instance_valid(pin) and not pin.IsCleared: mask[i >> 3] |= 1 << (i & 7)
   return mask

func apply_remote_state(generation: int, mask: PackedByteArray) -> void:
   if generation < Generation: return
   follow_generation(generation)
   for i:int in MaxPins:
      if (i >> 3) < mask.size() and mask[i >> 3] & (1 << (i & 7)): continue
      var pin = GameObject.Registry.get(_pin_id(Generation, i))
      if is_instance_valid(pin) and not pin.IsCleared: pin.remote_clear(pin.ClaimCounter)

#func _reset_pins() -> void:
   #for i:int in MaxPins:
      #var pin: RigidBody3D = _PinNodes[i]
      #var y: float = floorf((sqrt(8*i+1)-1)/2.0)
      #var x: float = i-((y*(y+2))/2.0)
      #pin.position = Vector3(x*PinSpacing, 0, y*PinSpacing)

func _handle_cleared_pin(pin: Pin) -> void:
   _PinNodes.erase(pin)
   if _PinNodes.is_empty(): _QueuePinRegeneration = true
   pin.queue_free()

func _process(_delta: float) -> void:
   if _QueuePinRegeneration:
      _regenerate_pins()


class EventBus:
   signal regenerated(setter: PinSetter)
