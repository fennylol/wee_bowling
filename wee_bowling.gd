extends Node
class_name WeeBowling

const DUMMY_NODE := preload("res://player/dummy/dummy.tscn")

var GO_REGISTRY = GameObject.Registry

@onready var _Player: Player = $Player
@onready var _WBM: WeeBowlingMenu = $WeeBowlingMenu
var _OTP := OneTruePingus.new()
var Dummies: Dictionary = {}
var Hosting: bool = false

var DEBUG_PRINT_CONTROL_MESSAGES: bool = true

func _ready() -> void:
   _Player.grabbed_object.connect(_send_gameobject_transform_data)
   
   _WBM.network_type_selected.connect (_on_wbm_network_type_selected)
   _WBM.hosting_type_selected.connect (_on_wbm_hosting_type_selected)
   _WBM.resume_button_pressed.connect (_on_wbm_resume_button_pressed)
   _WBM.connect_button_pressed.connect(_on_wbm_connect_button_pressed)

   _OTP.recieved_data.connect(_recieve_data)
   _OTP.connection_established.connect(_on_connection_established)
   
   _OTP.set_name("OneTruePingus")
   add_child(_OTP)

func _process(_delta: float) -> void:
   if Input.is_action_just_pressed("menu"):
      _on_wbm_resume_button_pressed(not _Player.Enabled)

func _physics_process(_delta: float) -> void:
   _send_player_transform_data(_Player.generate_transform_data(), _OTP.NetworkID)


# ========================= #
# Wee Bowling Menu handlers #
# ========================= #
func _on_wbm_network_type_selected(global: bool) -> void:
   _WBM.set_ip_label(_OTP.get_addr_port(global))
   if not global: 
     _OTP._discover_address()
     _OTP.ExternAddr = "PEE.POO.CUM.POO"
   
func _on_wbm_hosting_type_selected(client: bool) -> void:
   Hosting = not client

func _on_wbm_resume_button_pressed(resume: bool) -> void:
   _WBM.visible = not resume
   _Player.Enabled = resume

func _on_wbm_connect_button_pressed(target_address: String) -> void:
   var parts := target_address.rsplit(":", true, 1)
   if parts.size() < 2: return
   _OTP.add_peer(parts[0], parts[1].to_int())


# =================== #
# connection handling #
# =================== #
func _on_connection_established(network_id: int, peer_address: String, peer_port: int) -> void:
   #if Hosting:
      #for peer in _OTP.Peers:
         #if peer.NetworkID == network_id: continue
         #if peer.State != OneTruePingus.PingusStates.CONNECTED: continue
         #_send_connection_data(peer.NetworkID, peer.Addr, peer.Port)
   _WBM.update_peer(peer_address+":"+str(peer_port), OneTruePingus.PingusStates.CONNECTED)
   
   var dummy: Dummy = DUMMY_NODE.instantiate()
   dummy.NetworkID = network_id
   dummy.name = "dummy_" + str(network_id)
   Dummies.set(network_id, dummy)
   add_child(dummy)

# ============= #
# data handling #
# ============= #
enum DataTypes { 
   # do not use 0xC0 #
   ConnectionData         = 0x11,
   PlayerTransformData     = 0x22,
   GameObjectTransformData = 0x33
}

func _send_connection_data() -> void: pass
func _send_player_transform_data(data: PackedByteArray, owner_id: int) -> void: 
   var data_with_id: PackedByteArray = []
   data_with_id.resize(OneTruePingus.NETWORK_ID_SIZE)
   data_with_id.encode_u32(0, owner_id)
   data_with_id.append_array(data)
   _OTP.send_data(DataTypes.PlayerTransformData, data_with_id)
func _send_gameobject_transform_data(registry_id: int, _released: bool) -> void:
   var game_obj: GameObject = GameObject.Registry.get(registry_id)
   if game_obj: 
      var data: PackedByteArray = []
      data.resize(GameObject.REGISTRY_ID_SIZE)
      data.encode_u32(0, registry_id)
      print("sent: ", registry_id)
      data.append_array(game_obj.generate_transform_data())
      _OTP.send_data(DataTypes.GameObjectTransformData, data)

func _recieve_data(_sender_id: int, data_type: int, data: PackedByteArray) -> void:
   #if data_type != OneTruePingus.DataTypes.CONTROL and data.size() < MinSizes[data_type]: 
     #if DEBUG_PRINT_CONTROL_MESSAGES:
       #print("ERROR: undersized data of type %s from %d" % [DataTypes.find_key(data_type), sender_id])
     #return
   match data_type:
      DataTypes.ConnectionData          : _recieve_connection_data          (data)
      DataTypes.PlayerTransformData     : _recieve_player_transform_data     (data)
      DataTypes.GameObjectTransformData : _recieve_gameobject_transform_data (data)
      
      OneTruePingus.DataTypes.CONTROL:
         if DEBUG_PRINT_CONTROL_MESSAGES: 
            print(data.get_string_from_utf8())
         if _OTP.ExternAddr != "" and _WBM.IPLabel.text == "PEE.POO.CUM.POO:WEINER":
            _WBM.set_ip_label(_OTP.get_addr_port(true))
         #_refresh_peer_list()

func _recieve_connection_data          (data: PackedByteArray) -> void: pass
func _recieve_player_transform_data    (data: PackedByteArray) -> void:
   var peer_id: int = data.decode_u32(0)
   var dummy: Dummy = Dummies[peer_id]
   if dummy:
      var trans_data: PackedByteArray = data.slice(OneTruePingus.NETWORK_ID_SIZE)
      dummy.recieve_transform_data(trans_data)
   
   
func _recieve_gameobject_transform_data(data: PackedByteArray) -> void:
   var registry_id = data.decode_u32(0)
   print("got: ", registry_id)
   var game_obj: GameObject = GameObject.Registry.get(registry_id)
   if game_obj: game_obj.on_transform_data(data.slice(GameObject.REGISTRY_ID_SIZE))
   
   
