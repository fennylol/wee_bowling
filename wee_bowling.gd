extends Node
class_name WeeBowling

const DUMMY_NODE := preload("res://player/dummy/dummy.tscn")

var GO_REGISTRY = GameObject.Registry

@onready var _Player: Player = $Player
@onready var _WBM: WeeBowlingMenu = $WeeBowlingMenu
var _OTP := OneTruePingus.new()
var Dummies: Dictionary = {}

var DEBUG_PRINT_CONTROL_MESSAGES: bool = true

func _ready() -> void:
   _Player.grabbed_object.connect(_send_gameobject_transform_data)

   _WBM.network_type_selected.connect (_on_wbm_network_type_selected)
   _WBM.resume_button_pressed.connect (_on_wbm_resume_button_pressed)
   _WBM.connect_button_pressed.connect(_on_wbm_connect_button_pressed)
   _WBM.quit_button_pressed.connect   (_on_wbm_quit_button_pressed)

   _OTP.recieved_data.connect(_recieve_data)
   _OTP.connection_established.connect(_on_connection_established)

   _OTP.set_name("OneTruePingus")
   add_child(_OTP)
func _notification(what: int) -> void:
   if what == NOTIFICATION_WM_CLOSE_REQUEST:
     _send_disconnection_data()

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

func _on_wbm_resume_button_pressed(resume: bool) -> void:
   _WBM.visible = not resume
   _Player.Enabled = resume

func _on_wbm_connect_button_pressed(target_address: String) -> void:
   var parts := target_address.rsplit(":", true, 1)
   if parts.size() < 2: return
   _OTP.add_peer(parts[0], parts[1].to_int())
   _refresh_peer_list()

func _on_wbm_quit_button_pressed() -> void:
   _send_disconnection_data()
   for peer:OneTruePingus.PingusPeer in _OTP.Peers.duplicate():
     _despawn_dummy(peer.NetworkID)
     _OTP.Peers.erase(peer)
   _refresh_peer_list()


# =================== #
# connection handling #
# =================== #
## gossip: whenever anyone connects, broadcast the new peer to everyone, and
## broadcast every other connected peer too. each machine add_peer()s whoever
## it is missing, so the mesh fills itself in.
func _on_connection_established(network_id: int, peer_address: String, peer_port: int) -> void:
   _spawn_dummy(network_id)
   _send_connection_data(network_id, peer_address, peer_port)
   for peer in _OTP.Peers:
     if peer.NetworkID == network_id: continue
     if peer.State != OneTruePingus.PingusStates.CONNECTED: continue
     _send_connection_data(peer.NetworkID, peer.Addr, peer.Port)
   _refresh_peer_list()
func _refresh_peer_list() -> void:
   for peer:OneTruePingus.PingusPeer in _OTP.Peers.duplicate():
     if peer.KeepAliveNum*OneTruePingus._KEEP_ALIVE_TIME >= OneTruePingus._TIMEOUT_TIME:
       _despawn_dummy(peer.NetworkID)
       _OTP.Peers.erase(peer)
   _WBM.update_peers(_OTP.Peers)

func _spawn_dummy(network_id: int) -> void:
   if network_id == 0 or network_id == _OTP.NetworkID: return
   if Dummies.has(network_id): return
   var dummy: Dummy = DUMMY_NODE.instantiate()
   dummy.NetworkID = network_id
   dummy.name = "dummy_" + str(network_id)
   Dummies.set(network_id, dummy)
   add_child(dummy)
func _despawn_dummy(network_id: int) -> void:
   var dummy: Dummy = Dummies.get(network_id)
   if dummy: dummy.queue_free()
   Dummies.erase(network_id)

# ============= #
# data handling #
# ============= #
enum DataTypes {
   # do not use 0xC0 #
   ConnectionData          = 0x11,
   DisconnectionData       = 0xDD,
   PlayerTransformData     = 0x22,
   GameObjectTransformData = 0x33
}

func _send_connection_data(network_id: int, peer_address: String, peer_port: int) -> void:
   var data: PackedByteArray = []
   data.resize(OneTruePingus.NETWORK_ID_SIZE + OneTruePingus.PORT_SIZE)
   data.encode_u32(0, network_id)
   data.encode_u16(OneTruePingus.NETWORK_ID_SIZE, peer_port)
   data.append_array(peer_address.to_utf8_buffer())
   _OTP.send_data(DataTypes.ConnectionData, data)
func _send_disconnection_data(disconnecting_id: int = _OTP.NetworkID) -> void:
   var data: PackedByteArray = []
   data.resize(OneTruePingus.NETWORK_ID_SIZE)
   data.encode_u32(0, disconnecting_id)
   _OTP.send_data(DataTypes.DisconnectionData, data)
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
      DataTypes.DisconnectionData       : _recieve_disconnection_data       (data)
      DataTypes.PlayerTransformData     : _recieve_player_transform_data     (data)
      DataTypes.GameObjectTransformData : _recieve_gameobject_transform_data (data)

      OneTruePingus.DataTypes.CONTROL:
         if DEBUG_PRINT_CONTROL_MESSAGES:
            print(data.get_string_from_utf8())
         if _OTP.ExternAddr != "" and _WBM.IPLabel.text == "PEE.POO.CUM.POO:WEINER":
            _WBM.set_ip_label(_OTP.get_addr_port(true))
         _refresh_peer_list()

func _recieve_connection_data          (data: PackedByteArray) -> void:
   var peer_id = data.decode_u32(0)
   var peer_port = data.decode_u16(OneTruePingus.NETWORK_ID_SIZE)
   var peer_address = data.slice(OneTruePingus.NETWORK_ID_SIZE + OneTruePingus.PORT_SIZE).get_string_from_utf8()

   if (peer_id == _OTP.NetworkID) \
   or (peer_address == _OTP.ExternAddr and peer_port == _OTP.ExternPort) \
   or (peer_address == _OTP.LocalAddr and peer_port == _OTP.LocalPort):
     return

   _OTP.add_peer(peer_address, peer_port, peer_id)
func _recieve_disconnection_data       (data: PackedByteArray) -> void:
   var peer_id: int = data.decode_u32(0)
   for peer:OneTruePingus.PingusPeer in _OTP.Peers.duplicate():
     if peer.NetworkID == peer_id:
       _OTP.Peers.erase(peer)
       _despawn_dummy(peer.NetworkID)
   _refresh_peer_list()
func _recieve_player_transform_data    (data: PackedByteArray) -> void:
   var peer_id: int = data.decode_u32(0)
   var dummy: Dummy = Dummies.get(peer_id)
   if dummy:
      var trans_data: PackedByteArray = data.slice(OneTruePingus.NETWORK_ID_SIZE)
      dummy.recieve_transform_data(trans_data)


func _recieve_gameobject_transform_data(data: PackedByteArray) -> void:
   var registry_id = data.decode_u32(0)
   print("got: ", registry_id)
   var game_obj: GameObject = GameObject.Registry.get(registry_id)
   if game_obj: game_obj.on_transform_data(data.slice(GameObject.REGISTRY_ID_SIZE))
