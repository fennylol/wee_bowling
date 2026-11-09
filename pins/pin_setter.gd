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

var PinNodes: Array[Pin] = []
var SpotNodes: Array[MeshInstance3D] = []
var QueuePinRegeneration: bool = true

func _regenerate_pins() -> void:
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
