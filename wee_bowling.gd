extends Node
class_name WeeBowling

const DUMMY_NODE := preload("res://player/dummy/dummy.tscn")
const GAMEOBJECT_SEND_INTERVAL: int = 2 # physics ticks
const HEARTBEAT_TIME: float = 1.0

var GO_REGISTRY = GameObject.Registry

@onready var _Player: Player = $Player
@onready var _WBM: WeeBowlingMenu = $WeeBowlingMenu
var _OTP := OneTruePingus.new()
var Dummies: Dictionary = {}
var PlayerName: String = ""
var PeerNames: Dictionary = {}

var _PhysicsTick: int = 0
var _HeartbeatTimer: float = 0.0

var DEBUG_PRINT_CONTROL_MESSAGES: bool = false

func _ready() -> void:
   GameObject.LocalID = _OTP.NetworkID
   PlayerName = str(_OTP.NetworkID)
   GameObject.Events.object_claimed.connect(_send_claim_ownership_data)
   GameObject.Events.object_cleared.connect(_send_gameobject_cleared_data)
   PinSetter.Events.regenerated.connect(_send_pinsetter_state_data)

   _WBM.network_type_selected.connect (_on_wbm_network_type_selected)
   _WBM.resume_button_pressed.connect (_on_wbm_resume_button_pressed)
   _WBM.connect_button_pressed.connect(_on_wbm_connect_button_pressed)
   _WBM.quit_button_pressed.connect   (_on_wbm_quit_button_pressed)
   _WBM.name_changed.connect          (_on_wbm_name_changed)

   _OTP.recieved_data.connect(_recieve_data)
   _OTP.connection_established.connect(_on_connection_established)

   _OTP.set_name("OneTruePingus")
   add_child(_OTP)
func _notification(what: int) -> void:
   if what == NOTIFICATION_WM_CLOSE_REQUEST:
     _send_disconnection_data()

func _process(delta: float) -> void:
   if Input.is_action_just_pressed("menu"):
      _on_wbm_resume_button_pressed(not _Player.Enabled)

   _HeartbeatTimer += delta
   if _HeartbeatTimer >= HEARTBEAT_TIME:
      _HeartbeatTimer = 0.0
      for setter: PinSetter in PinSetter.Registry.values():
         _send_pinsetter_state_data(setter)
      for machine: BallMachine in BallMachine.Registry.values():
         _send_ballmachine_state_data(machine)
      _send_identity_data()

func _physics_process(_delta: float) -> void:
   _send_player_transform_data(_Player.generate_transform_data(), _OTP.NetworkID)

   _PhysicsTick += 1
   if _PhysicsTick % GAMEOBJECT_SEND_INTERVAL == 0:
      for game_obj in GameObject.Registry.values():
         if is_instance_valid(game_obj) and game_obj.should_broadcast():
            _send_gameobject_transform_data(game_obj)


# ========================= #
# Wee Bowling Menu handlers #
# ========================= #
func _on_wbm_network_type_selected(global: bool) -> void:
   _WBM.set_ip_label(_OTP.get_addr_port(global))
   # refresh stun so global is preloaded with a fresh address
   if not global: _OTP._discover_address()

func _on_wbm_resume_button_pressed(resume: bool) -> void:
   _WBM.visible = not resume
   _Player.Enabled = resume

func _on_wbm_connect_button_pressed(target_address: String) -> void:
   var parts := target_address.rsplit(":", true, 1)
   if parts.size() < 2: return
   _OTP.add_peer(parts[0], parts[1].to_int())
   _refresh_peer_list()

func _on_wbm_name_changed(new_name: String) -> void:
   PlayerName = new_name
   _send_identity_data()

func _on_wbm_quit_button_pressed() -> void:
   _send_disconnection_data()
   for peer:OneTruePingus.PingusPeer in _OTP.Peers.duplicate():
     _despawn_dummy(peer.NetworkID)
     GameObject.release_all_owned_by(peer.NetworkID)
     _OTP.Peers.erase(peer)
   _refresh_peer_list()


# =================== #
# connection handling #
# =================== #
func _on_connection_established(network_id: int, peer_address: String, peer_port: int) -> void:
   _spawn_dummy(network_id)
   _send_connection_data(network_id, peer_address, peer_port)
   for peer in _OTP.Peers:
     if peer.NetworkID == network_id: continue
     if peer.State != OneTruePingus.PingusStates.CONNECTED: continue
     _send_connection_data(peer.NetworkID, peer.Addr, peer.Port)
   _send_world_state_data(network_id)
   _send_identity_data()
   _refresh_peer_list()
func _refresh_peer_list() -> void:
   for peer:OneTruePingus.PingusPeer in _OTP.Peers.duplicate():
     if peer.KeepAliveNum*OneTruePingus._KEEP_ALIVE_TIME >= OneTruePingus._TIMEOUT_TIME:
       _despawn_dummy(peer.NetworkID)
       GameObject.release_all_owned_by(peer.NetworkID)
       _OTP.Peers.erase(peer)
   _WBM.update_peers(_OTP.Peers, PeerNames)

func _spawn_dummy(network_id: int) -> void:
   if network_id == 0 or network_id == _OTP.NetworkID: return
   if Dummies.has(network_id): return
   var dummy: Dummy = DUMMY_NODE.instantiate()
   dummy.NetworkID = network_id
   dummy.name = "dummy_" + str(network_id)
   Dummies.set(network_id, dummy)
   add_child(dummy)
   dummy.set_name_tag(PeerNames.get(network_id, str(network_id)))
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
   GameObjectTransformData = 0x33,
   ClaimOwnershipData      = 0x44,
   GameObjectClearedData   = 0x55,
   PinSetterStateData      = 0x66,
   BallMachineStateData    = 0x77,
   IdentityData            = 0x15
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
func _send_identity_data() -> void:
   var data: PackedByteArray = []
   data.resize(OneTruePingus.NETWORK_ID_SIZE)
   data.encode_u32(0, _OTP.NetworkID)
   data.append_array(PlayerName.to_utf8_buffer())
   _OTP.send_data(DataTypes.IdentityData, data)
func _send_player_transform_data(data: PackedByteArray, owner_id: int) -> void:
   var data_with_id: PackedByteArray = []
   data_with_id.resize(OneTruePingus.NETWORK_ID_SIZE)
   data_with_id.encode_u32(0, owner_id)
   data_with_id.append_array(data)
   _OTP.send_data(DataTypes.PlayerTransformData, data_with_id)
func _send_gameobject_transform_data(game_obj: GameObject, target_id: int = 0) -> void:
   var data: PackedByteArray = []
   data.resize(GameObject.REGISTRY_ID_SIZE)
   data.encode_u32(0, game_obj.RegistryID)
   data.append_array(game_obj.generate_state_data())
   if target_id: _OTP.send_data_to(target_id, DataTypes.GameObjectTransformData, data)
   else: _OTP.send_data(DataTypes.GameObjectTransformData, data)
func _send_claim_ownership_data(game_obj: GameObject) -> void:
   var data: PackedByteArray = []
   data.resize(GameObject.REGISTRY_ID_SIZE + GameObject.OWNERSHIP_DATA_SIZE)
   data.encode_u32(0, game_obj.RegistryID)
   data.encode_u32(GameObject.REGISTRY_ID_SIZE, game_obj.OwnerID)
   data.encode_u32(GameObject.REGISTRY_ID_SIZE + 4, game_obj.ClaimCounter)
   _OTP.send_data(DataTypes.ClaimOwnershipData, data)
func _send_gameobject_cleared_data(game_obj: GameObject) -> void:
   var data: PackedByteArray = []
   data.resize(GameObject.REGISTRY_ID_SIZE + GameObject.COUNTER_SIZE)
   data.encode_u32(0, game_obj.RegistryID)
   data.encode_u32(GameObject.REGISTRY_ID_SIZE, game_obj.ClaimCounter)
   _OTP.send_data(DataTypes.GameObjectClearedData, data)
func _send_pinsetter_state_data(setter: PinSetter, target_id: int = 0) -> void:
   var data: PackedByteArray = []
   data.resize(8)
   data.encode_u32(0, setter.SetterID)
   data.encode_u32(4, setter.Generation)
   data.append_array(setter.get_standing_mask())
   if target_id: _OTP.send_data_to(target_id, DataTypes.PinSetterStateData, data)
   else: _OTP.send_data(DataTypes.PinSetterStateData, data)
func _send_ballmachine_state_data(machine: BallMachine, target_id: int = 0) -> void:
   var data: PackedByteArray = []
   data.resize(4)
   data.encode_u32(0, machine.MachineID)
   data.append_array(machine.get_ball_states())
   if target_id: _OTP.send_data_to(target_id, DataTypes.BallMachineStateData, data)
   else: _OTP.send_data(DataTypes.BallMachineStateData, data)

# unowned objects haven't moved since they spawned, so only owned ones are sent
func _send_world_state_data(network_id: int) -> void:
   for game_obj in GameObject.Registry.values():
     if is_instance_valid(game_obj) and game_obj.OwnerID == _OTP.NetworkID and not game_obj.Cleared:
       _send_gameobject_transform_data(game_obj, network_id)
   for setter: PinSetter in PinSetter.Registry.values():
     _send_pinsetter_state_data(setter, network_id)
   for machine: BallMachine in BallMachine.Registry.values():
     _send_ballmachine_state_data(machine, network_id)

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
      DataTypes.ClaimOwnershipData      : _recieve_claim_ownership_data      (data)
      DataTypes.GameObjectClearedData   : _recieve_gameobject_cleared_data   (data)
      DataTypes.PinSetterStateData      : _recieve_pinsetter_state_data      (data)
      DataTypes.BallMachineStateData    : _recieve_ballmachine_state_data    (data)
      DataTypes.IdentityData            : _recieve_identity_data             (data)

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
   GameObject.release_all_owned_by(peer_id)
   _refresh_peer_list()
func _recieve_player_transform_data    (data: PackedByteArray) -> void:
   var peer_id: int = data.decode_u32(0)
   var dummy: Dummy = Dummies.get(peer_id)
   if dummy:
      var trans_data: PackedByteArray = data.slice(OneTruePingus.NETWORK_ID_SIZE)
      dummy.recieve_transform_data(trans_data)


func _recieve_gameobject_transform_data(data: PackedByteArray) -> void:
   if data.size() < GameObject.REGISTRY_ID_SIZE: return
   var game_obj = GameObject.Registry.get(data.decode_u32(0))
   if is_instance_valid(game_obj): game_obj.on_state_data(data.slice(GameObject.REGISTRY_ID_SIZE))
func _recieve_claim_ownership_data     (data: PackedByteArray) -> void:
   if data.size() < GameObject.REGISTRY_ID_SIZE + GameObject.OWNERSHIP_DATA_SIZE: return
   var game_obj = GameObject.Registry.get(data.decode_u32(0))
   if is_instance_valid(game_obj) and not game_obj.Cleared:
      game_obj.accept_claim(data.decode_u32(GameObject.REGISTRY_ID_SIZE), data.decode_u32(GameObject.REGISTRY_ID_SIZE + 4))
func _recieve_gameobject_cleared_data  (data: PackedByteArray) -> void:
   if data.size() < GameObject.REGISTRY_ID_SIZE + GameObject.COUNTER_SIZE: return
   var game_obj = GameObject.Registry.get(data.decode_u32(0))
   if is_instance_valid(game_obj): game_obj.remote_clear(data.decode_u32(GameObject.REGISTRY_ID_SIZE))
func _recieve_pinsetter_state_data     (data: PackedByteArray) -> void:
   if data.size() < 8: return
   var setter = PinSetter.Registry.get(data.decode_u32(0))
   if is_instance_valid(setter): setter.apply_remote_state(data.decode_u32(4), data.slice(8))
func _recieve_ballmachine_state_data   (data: PackedByteArray) -> void:
   if data.size() < 4: return
   var machine = BallMachine.Registry.get(data.decode_u32(0))
   if is_instance_valid(machine): machine.apply_remote_state(data.slice(4))
func _recieve_identity_data            (data: PackedByteArray) -> void:
   if data.size() < OneTruePingus.NETWORK_ID_SIZE: return
   var peer_id: int = data.decode_u32(0)
   var new_name: String = data.slice(OneTruePingus.NETWORK_ID_SIZE).get_string_from_utf8().left(24)
   if PeerNames.get(peer_id) == new_name: return
   PeerNames[peer_id] = new_name
   var dummy: Dummy = Dummies.get(peer_id)
   if dummy: dummy.set_name_tag(new_name)
   _refresh_peer_list()
