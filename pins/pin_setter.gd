@tool
extends Node3D
class_name PinSetter

const PIN_NODE : PackedScene = preload("res://pins/Pin.tscn")
const SPOT_NODE: PackedScene = preload("res://pins/spot.tscn")

@export var PinSpacing: float = 1:
   set(new_spacing):
      PinSpacing = new_spacing
      QueuePinRegeneration = true
@export var MaxPins: int = 10:
   set(new_max):
      MaxPins = max(1, min(new_max, 120))
      QueuePinRegeneration = true

signal regenerating()

## networking hooks shared by every PinSetter. see [PinSetter.EventBus]
static var Events  : EventBus   = EventBus.new()
static var Registry: Dictionary = {}

var PinNodes: Array[Pin] = []
var SpotNodes: Array[MeshInstance3D] = []
var QueuePinRegeneration: bool = true
## matches on every machine. see [member GameObject.RegistryID]
var SetterID  : int = 0
## bumped by every regeneration. a higher generation from another machine resets this rack
var Generation: int = 0

## signals the network layer listens to
class EventBus:
   ## [param setter] regenerated because of something on this machine
   signal regenerated(setter: PinSetter)

func _ready() -> void:
   if Engine.is_editor_hint(): return
   SetterID = str(get_path()).hash()
   Registry[SetterID] = self

## pass [param new_generation] when following another machine; leave it at -1 for
## a local regeneration, which is then broadcast
func _regenerate_pins(new_generation: int = -1) -> void:
   Generation = Generation + 1 if new_generation < 0 else new_generation
   for pin:Pin in PinNodes:
      if pin and not pin.is_queued_for_deletion():
         pin.queue_free()
   PinNodes.clear()
   
   for spot in SpotNodes:
      if spot and not spot.is_queued_for_deletion():
         spot.queue_free()
   SpotNodes.clear()
      
   for i:int in MaxPins:
      var y: float = floorf((sqrt(8*i+1)-1)/2.0)
      var x: float = i-((y*(y+2))/2.0)
      
      var pin :Pin            = PIN_NODE.instantiate()
      pin.set_name("Pin_"+str(i))
      if not Engine.is_editor_hint(): pin.register(_pin_id(Generation, i))
      pin.position = Vector3(x*PinSpacing, 0, y*PinSpacing)
      pin.cleared.connect(_handle_cleared_pin.bind(pin))
      PinNodes.append(pin)
      add_child(pin)
      
      var spot:MeshInstance3D = SPOT_NODE.instantiate()
      spot.set_name("Spot_"+str(i))
      spot.position = Vector3(x*PinSpacing, 0, y*PinSpacing)
      SpotNodes.append(spot)
      add_child(spot)
      
   #_reset_pins()
   QueuePinRegeneration = false
   if new_generation < 0 and not Engine.is_editor_hint(): Events.regenerated.emit(self)

## registry ID of pin [param index] in [param generation]. new generations get new
## IDs, so late updates for knocked-over pins can't grab the fresh ones
func _pin_id(generation: int, index: int) -> int:
   return ("%d:%d:%d" % [SetterID, generation, index]).hash()

## which pins of the current generation are still standing, one bit per pin
func get_standing_mask() -> PackedByteArray:
   var mask: PackedByteArray = []
   mask.resize(ceili(MaxPins / 8.0))
   for i:int in MaxPins:
      var pin = GameObject.Registry.get(_pin_id(Generation, i))
      if is_instance_valid(pin) and not pin.IsCleared: mask[i >> 3] |= 1 << (i & 7)
   return mask

## follow another machine's view of this rack: a newer generation resets it, and
## any pin missing from [param mask] has been cleared over there, so clear it here
func apply_remote_state(generation: int, mask: PackedByteArray) -> void:
   if generation < Generation: return
   if generation > Generation: _regenerate_pins(generation)
   for i:int in MaxPins:
      if (i >> 3) < mask.size() and mask[i >> 3] & (1 << (i & 7)): continue
      var pin = GameObject.Registry.get(_pin_id(Generation, i))
      if is_instance_valid(pin) and not pin.IsCleared: pin.remote_clear(pin.ClaimCounter)

#func _reset_pins() -> void:
   #for i:int in MaxPins:
      #var pin: RigidBody3D = PinNodes[i]
      #var y: float = floorf((sqrt(8*i+1)-1)/2.0)
      #var x: float = i-((y*(y+2))/2.0)
      #pin.position = Vector3(x*PinSpacing, 0, y*PinSpacing)

func _handle_cleared_pin(pin: Pin) -> void:
   PinNodes.erase(pin)
   if PinNodes.is_empty(): QueuePinRegeneration = true
   pin.queue_free()

func _process(_delta: float) -> void:
   if QueuePinRegeneration:
      regenerating.emit()
      _regenerate_pins()
