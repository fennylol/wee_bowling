extends Node
class_name MultiplayerManager

@onready var _ConnectionMenu: ConnectMenu = $ConnectMenu

signal ready_button_pressed()
signal identity_changed()

signal peer_disconnected(network_id: int)
signal connection_established(network_id: int)
signal transform_data(network_id: int, data: PackedByteArray)
signal damage_data(network_id: int, package: DamagePackage)
signal health_update_data(network_id: int, health : Array[float])
signal knockout_data(network_id: int, KO_player_id : int)
signal victory_point_data(data : PackedByteArray)
signal spawned_prism_data(prismdata : PackedByteArray)
@warning_ignore("unused_signal")
signal updated_prism_data(prismdata : PackedByteArray)
signal removed_prism_data(id : int)
signal identity_data(network_id: int, new_name: String, primary_color: Color, secondary_color: Color)
signal effect_equipped_data(network_id: int, spell_id: int, is_active: bool)
signal effect_erased_data(network_id: int, spell_id: int, is_active: bool)
signal spell_state_data(network_id: int, spell_id: int, is_active: bool, spell_state: int)
signal spawn_familiar_data(network_id: int, spell_id: int, is_active: bool, familiar_idx: int, creation_data: PackedByteArray)

var _OTP     : OneTruePingus = OneTruePingus.new()
var _Hosting : bool          = false

var DEBUG_PRINT_CONTROL_MESSAGES: bool = true

func _ready() -> void:
   SettingsManager.personal_settings.NICKNAME = str(_OTP.NetworkID)
   _ConnectionMenu.set_id_label(SettingsManager.personal_settings.NICKNAME)

   _OTP.recieved_data.connect(_recieve_data)
   _OTP.connection_established.connect(_on_connection_established)
   
   _ConnectionMenu.identity_changed.connect(_on_identity_changed)
   _ConnectionMenu.connect_button_pressed.connect(_on_connect_button_pressed)
   _ConnectionMenu.ready_button_pressed.connect(_on_ready_button_pressed)
   _ConnectionMenu.network_type_changed.connect(_on_network_type_changed)
   _ConnectionMenu.hosting_type_changed.connect(_on_hosting_type_changed)
   _ConnectionMenu.quit_button_pressed.connect(_on_disconnect_button_pressed)
   
   _OTP.set_name("MultiplayerCoupler")
   add_child(_OTP)
func _notification(what: int) -> void:
   if what == NOTIFICATION_WM_CLOSE_REQUEST:
     _send_disconnection_data()
func get_local_player_id() -> int: return _OTP.NetworkID
# =============== #
# signal handling #
# =============== #
func _on_connect_button_pressed(target_address: String) -> void:
   var parts := target_address.rsplit(":", true, 1)
   if parts.size() < 2: return
   _OTP.add_peer(parts[0], parts[1].to_int())
   _refresh_peer_list()
func _on_disconnect_button_pressed() -> void:
   _send_disconnection_data()
   for peer:OneTruePingus.PingusPeer in _OTP.Peers:
     peer_disconnected.emit(peer.NetworkID)
     _OTP.Peers.erase(peer)
   _refresh_peer_list()
func _on_connection_established(network_id: int, peer_address: String, peer_port: int) -> void:
   connection_established.emit(network_id)
   _send_connection_data(network_id, peer_address, peer_port)
   for peer in _OTP.Peers:
     if peer.NetworkID == network_id: continue
     if peer.State != OneTruePingus.PingusStates.CONNECTED: continue
     _send_connection_data(peer.NetworkID, peer.Addr, peer.Port)
   _send_identity_data()
   _refresh_peer_list()
func _on_ready_button_pressed() -> void:
   ready_button_pressed.emit()
   _ConnectionMenu.visible = false
func _on_identity_changed() -> void:
   identity_changed.emit()
   _send_identity_data()
func _on_network_type_changed(global: bool) -> void:
   _ConnectionMenu.set_ip_label(_OTP.get_addr_port(global))
   if not global: 
     _OTP._discover_address()
     _OTP.ExternAddr = "PEE.POO.CUM.POO"
func _on_hosting_type_changed(client: bool) -> void:
   _Hosting = not client
func _refresh_peer_list() -> void:
   for peer:OneTruePingus.PingusPeer in _OTP.Peers:
     if peer.KeepAliveNum*OneTruePingus._KEEP_ALIVE_TIME >= OneTruePingus._TIMEOUT_TIME:
       peer_disconnected.emit(peer.NetworkID)
       _OTP.Peers.erase(peer)
   _ConnectionMenu.update_peers(_OTP.Peers)
func open_connection_menu(show_menu: bool) -> void:
   _ConnectionMenu.visible = show_menu

# ============ #
# data routing #
# ============ #
#IMPLEMMENMT CHILD NODE DATA
enum DataTypes { 
   # do not use 0xC0 #
   
   # gameplay data #
   TransformData = 0x20, DamageData = 0xDA, HealthUpdateData = 0x88, KnockoutData = 0xE0, VictoryPointsData = 0x01,
   # prism data #
   SpawnedPrismData = 0x04, UpdatedPrismData = 0x06, RemovedPrismData = 0x08,
   # connection state #
   ConnectionData = 0xCD, DisconnectionData = 0xDD, IdentityData = 0x15, 
   # inventory #
   EffectEquip = 0xEC, EffectErase = 0x0C, SpellState = 0x55,
   # familiars #
   SpawnFamiliar = 0x5F
}
#var MinSizes: Dictionary = {
   #DataTypes.TransformData    : Player.TRANSFORM_DATA_SIZE,
   #DataTypes.ConnectionData   : OneTruePingus.NETWORK_ID_SIZE + OneTruePingus.PORT_SIZE,
   #DataTypes.DisconnectionData: OneTruePingus.NETWORK_ID_SIZE,
   #DataTypes.NameTagData      : 0
#}

func _recieve_data(_sender_id: int, data_type: int, data: PackedByteArray) -> void:
   #if data_type != OneTruePingus.DataTypes.CONTROL and data.size() < MinSizes[data_type]: 
     #if DEBUG_PRINT_CONTROL_MESSAGES:
       #print("ERROR: undersized data of type %s from %d" % [DataTypes.find_key(data_type), sender_id])
     #return
   match data_type:
      DataTypes.TransformData    : _recieve_transform_data     (data)
      DataTypes.DamageData       : _recieve_damage_data        (data)
      DataTypes.HealthUpdateData : _recieve_health_update_data (data)
      DataTypes.KnockoutData     : _recieve_knockout_data      (data)
      DataTypes.VictoryPointsData: _recieve_victory_point_data (data)
      DataTypes.SpawnedPrismData : _recieve_spawned_prism_data (data)
      DataTypes.UpdatedPrismData : _recieve_updated_prism_data (data)
      DataTypes.RemovedPrismData : _recieve_removed_prism_data (data)
      DataTypes.ConnectionData   : _recieve_connection_data    (data)
      DataTypes.DisconnectionData: _recieve_disconnection_data (data)
      DataTypes.IdentityData     : _recieve_identity_data      (data)
      DataTypes.EffectEquip      : _recieve_effect_equip_data  (data)
      DataTypes.EffectErase      : _recieve_effect_erase_data  (data)
      DataTypes.SpellState       : _recieve_spell_state_data   (data)
      DataTypes.SpawnFamiliar    : _recieve_spawn_familiar_data(data)
      OneTruePingus.DataTypes.CONTROL:
         if DEBUG_PRINT_CONTROL_MESSAGES: print(data.get_string_from_utf8())
         if _OTP.ExternAddr != "" and _ConnectionMenu.GLOBAL_BUTTON.disabled:
            _ConnectionMenu.set_ip_label(_OTP.get_addr_port(true))
         _refresh_peer_list()

func _recieve_transform_data     (data: PackedByteArray) -> void:
   var peer_id: int = data.decode_u32(0)
   var trans_data: PackedByteArray = data.slice(OneTruePingus.NETWORK_ID_SIZE)
   transform_data.emit(peer_id, trans_data)
func _recieve_damage_data        (data: PackedByteArray) -> void:
   var peer_id: int = data.decode_u32(0)
   var package_data: PackedByteArray = data.slice(OneTruePingus.NETWORK_ID_SIZE)
   var package : DamagePackage = DamagePackage.from_PackedByteArray(package_data)
   damage_data.emit(peer_id, package)
func _recieve_health_update_data (data: PackedByteArray) -> void: 
   var player_id = data.decode_u32(0)
   var health : Array[float] = [0,0,0,0]
   health[0] = data.decode_float(OneTruePingus.NETWORK_ID_SIZE)
   health[1] = data.decode_float(OneTruePingus.NETWORK_ID_SIZE + 4)
   health[2] = data.decode_float(OneTruePingus.NETWORK_ID_SIZE + 8)
   health[3] = data.decode_float(OneTruePingus.NETWORK_ID_SIZE + 12)
   health_update_data.emit(player_id, health)
func _recieve_knockout_data      (data: PackedByteArray) -> void:
   var killer_id    : int = data.decode_u32(0)
   var KO_player_id : int = data.decode_u32(OneTruePingus.NETWORK_ID_SIZE)
   knockout_data.emit(killer_id, KO_player_id)
func _recieve_victory_point_data (data: PackedByteArray) -> void:
   victory_point_data.emit(data)
func _recieve_spawned_prism_data (data: PackedByteArray) -> void: 
   spawned_prism_data.emit(data)
func _recieve_updated_prism_data (_data: PackedByteArray) -> void: pass
func _recieve_removed_prism_data (data: PackedByteArray) -> void: 
   var prism_id : int = data.decode_u8(0)
   removed_prism_data.emit(prism_id)
func _recieve_connection_data    (data: PackedByteArray) -> void:
   var peer_id = data.decode_u32(0)
   var peer_port = data.decode_u16(OneTruePingus.NETWORK_ID_SIZE)
   var peer_address = data.slice(OneTruePingus.NETWORK_ID_SIZE + OneTruePingus.PORT_SIZE).get_string_from_utf8()
   
   if (peer_id == _OTP.NetworkID) \
   or (peer_address == _OTP.ExternAddr and peer_port == _OTP.ExternPort) \
   or (peer_address == _OTP.LocalAddr and peer_port == _OTP.LocalPort):
     return 
   
   _OTP.add_peer(peer_address, peer_port, peer_id)
func _recieve_disconnection_data (data: PackedByteArray) -> void:
   var peer_id: int = data.decode_u32(0)
   for peer:OneTruePingus.PingusPeer in _OTP.Peers:
     if peer.NetworkID == peer_id: 
       _OTP.Peers.erase(peer)
       peer_disconnected.emit(peer.NetworkID)
   _refresh_peer_list()
func _recieve_identity_data      (data: PackedByteArray) -> void:
   var peer_id: int = data.decode_u32(0)
   var prim_hue: float = data.decode_float(OneTruePingus.NETWORK_ID_SIZE)
   var prim_lit: float = data.decode_float(OneTruePingus.NETWORK_ID_SIZE + PersonalSettings.HUE_SIZE)
   var secd_hue: float = data.decode_float(OneTruePingus.NETWORK_ID_SIZE + PersonalSettings.HUE_SIZE + PersonalSettings.LIGHTNESS_SIZE)
   var secd_lit: float = data.decode_float(OneTruePingus.NETWORK_ID_SIZE + PersonalSettings.HUE_SIZE + PersonalSettings.LIGHTNESS_SIZE + PersonalSettings.HUE_SIZE)
   var primary_color := Color.from_ok_hsl(prim_hue, 1.0, prim_lit)
   var secondary_color := Color.from_ok_hsl(secd_hue, 0.9, secd_lit)
   var new_name: String = data.slice(OneTruePingus.NETWORK_ID_SIZE + PersonalSettings.HUE_SIZE + PersonalSettings.LIGHTNESS_SIZE + PersonalSettings.HUE_SIZE + PersonalSettings.LIGHTNESS_SIZE).get_string_from_utf8()
   identity_data.emit(peer_id, new_name, primary_color, secondary_color)
   _refresh_peer_list()
func _recieve_effect_equip_data  (data: PackedByteArray) -> void:
   var peer_id: int    = data.decode_u32(0)
   var spell_id: int   = data.decode_u16(OneTruePingus.NETWORK_ID_SIZE)
   var is_active: bool = data.decode_u8 (OneTruePingus.NETWORK_ID_SIZE + SpellData.SPELL_ID_SIZE)
   effect_equipped_data.emit(peer_id, spell_id, is_active)
func _recieve_effect_erase_data  (data: PackedByteArray) -> void:
   var peer_id: int    = data.decode_u32(0)
   var spell_id: int   = data.decode_u16(OneTruePingus.NETWORK_ID_SIZE)
   var is_active: bool = data.decode_u8 (OneTruePingus.NETWORK_ID_SIZE + SpellData.SPELL_ID_SIZE)
   effect_erased_data.emit(peer_id, spell_id, is_active)
func _recieve_spell_state_data   (data: PackedByteArray) -> void:
   var network_id : int = data.decode_u32(0) 
   var spell_id   : int = data.decode_u16(OneTruePingus.NETWORK_ID_SIZE)
   var is_active  : int = data.decode_u8 (OneTruePingus.NETWORK_ID_SIZE + SpellData.SPELL_ID_SIZE)
   var spell_state: int = data.decode_u8 (OneTruePingus.NETWORK_ID_SIZE + SpellData.SPELL_ID_SIZE + SpellData.IS_ACTIVE_SIZE)
   spell_state_data.emit(network_id, spell_id, is_active, spell_state)
func _recieve_spawn_familiar_data(data: PackedByteArray) -> void:
   var network_id  : int = data.decode_u32(0) 
   var spell_id    : int = data.decode_u16(OneTruePingus.NETWORK_ID_SIZE)
   var is_active   : int = data.decode_u8 (OneTruePingus.NETWORK_ID_SIZE + SpellData.SPELL_ID_SIZE)
   var familiar_idx: int = data.decode_u8 (OneTruePingus.NETWORK_ID_SIZE + SpellData.SPELL_ID_SIZE + SpellData.IS_ACTIVE_SIZE)
   var creation_data    := data.slice     (OneTruePingus.NETWORK_ID_SIZE + SpellData.SPELL_ID_SIZE + SpellData.IS_ACTIVE_SIZE + SpellData.FAMILIAR_IDX_SIZE)
   spawn_familiar_data.emit(network_id, spell_id, is_active, familiar_idx, creation_data)

func send_player_transform_data(data: PackedByteArray, owner_id: int = _OTP.NetworkID) -> void:
   var data_with_id: PackedByteArray = []
   data_with_id.resize(OneTruePingus.NETWORK_ID_SIZE)
   data_with_id.encode_u32(0, owner_id)
   data_with_id.append_array(data)
   _OTP.send_data(DataTypes.TransformData, data_with_id)
func send_damage_data          (package : DamagePackage, owner_id: int = _OTP.NetworkID) -> void:
   # TODO: when client/server changed made fix who add the ID
   var data: PackedByteArray = []
   data.resize(OneTruePingus.NETWORK_ID_SIZE)
   data.encode_u32(0,owner_id)
   data.append_array(package.to_PackedByteArray())
   _OTP.send_data(DataTypes.DamageData, data)
func send_health_update_data   (health : Array[float], owner_id : int = _OTP.NetworkID) -> void:
   var data : PackedByteArray
   data.resize(OneTruePingus.NETWORK_ID_SIZE + 16)
   data.encode_u32(0, owner_id)
   data.encode_float(OneTruePingus.NETWORK_ID_SIZE     , health[0])
   data.encode_float(OneTruePingus.NETWORK_ID_SIZE + 4 , health[1])
   data.encode_float(OneTruePingus.NETWORK_ID_SIZE + 8 , health[2])
   data.encode_float(OneTruePingus.NETWORK_ID_SIZE + 12, health[3])
   _OTP.send_data(DataTypes.HealthUpdateData, data)
func send_knockout_data        (killer_player_id : int, KO_player_id: int = _OTP.NetworkID) -> void:
   var data: PackedByteArray = []
   data.resize(OneTruePingus.NETWORK_ID_SIZE + OneTruePingus.NETWORK_ID_SIZE)
   data.encode_u32(0, killer_player_id)
   data.encode_u32(OneTruePingus.NETWORK_ID_SIZE , KO_player_id)
   _OTP.send_data(DataTypes.KnockoutData, data)
func send_victory_point_data   (data : PackedByteArray) -> void:
   _OTP.send_data(DataTypes.VictoryPointsData, data)
func send_spawned_prism_data   (prism_data : PackedByteArray) -> void: 
   _OTP.send_data(DataTypes.SpawnedPrismData, prism_data)
func send_updated_prism_data   (_prism_data : PackedByteArray) -> void: pass
func send_removed_prism_data   (id : int) -> void: 
   var data : PackedByteArray
   data.resize(Prism.PRISM_ID_SIZE)
   data.encode_u8(0, id)
   _OTP.send_data(DataTypes.RemovedPrismData, data)
func _send_connection_data     (network_id: int, peer_address: String, peer_port: int) -> void:
   var data: PackedByteArray = []
   data.resize(OneTruePingus.NETWORK_ID_SIZE + OneTruePingus.PORT_SIZE)
   data.encode_u32(0, network_id)
   data.encode_u16(OneTruePingus.NETWORK_ID_SIZE, peer_port)
   data.append_array(peer_address.to_utf8_buffer())
   _OTP.send_data(DataTypes.ConnectionData, data)
func _send_disconnection_data  (disconnecting_id: int = _OTP.NetworkID) -> void:
   var data: PackedByteArray = []
   data.resize(OneTruePingus.NETWORK_ID_SIZE)
   data.encode_u32(0, disconnecting_id)
   _OTP.send_data(DataTypes.DisconnectionData, data)
func _send_identity_data       (owner_id: int = _OTP.NetworkID) -> void:
   var data: PackedByteArray = []
   data.resize(OneTruePingus.NETWORK_ID_SIZE + 2*PersonalSettings.HUE_SIZE + 2*PersonalSettings.LIGHTNESS_SIZE)
   data.encode_u32(0, owner_id)
   data.encode_float(OneTruePingus.NETWORK_ID_SIZE,                                                                                           SettingsManager.personal_settings.PRIMARY_COLOR.ok_hsl_h)
   data.encode_float(OneTruePingus.NETWORK_ID_SIZE + PersonalSettings.HUE_SIZE,                                                               SettingsManager.personal_settings.PRIMARY_COLOR.ok_hsl_l)
   data.encode_float(OneTruePingus.NETWORK_ID_SIZE + PersonalSettings.HUE_SIZE + PersonalSettings.LIGHTNESS_SIZE,                             SettingsManager.personal_settings.SECONDARY_COLOR.ok_hsl_h)
   data.encode_float(OneTruePingus.NETWORK_ID_SIZE + PersonalSettings.HUE_SIZE + PersonalSettings.LIGHTNESS_SIZE + PersonalSettings.HUE_SIZE, SettingsManager.personal_settings.SECONDARY_COLOR.ok_hsl_l)
   data.append_array(SettingsManager.personal_settings.NICKNAME.to_utf8_buffer())
   _OTP.send_data(DataTypes.IdentityData, data)
func send_effect_equip_data    (spell_id: int, is_active: bool, owner_id: int = _OTP.NetworkID) -> void:
   var data: PackedByteArray = []
   data.resize(OneTruePingus.NETWORK_ID_SIZE + SpellData.SPELL_ID_SIZE + SpellData.IS_ACTIVE_SIZE)
   data.encode_u32(0, owner_id)
   data.encode_u16(OneTruePingus.NETWORK_ID_SIZE, spell_id)
   data.encode_u8 (OneTruePingus.NETWORK_ID_SIZE + SpellData.SPELL_ID_SIZE, is_active)
   _OTP.send_data(DataTypes.EffectEquip, data)
func send_effect_erase_data    (spell_id: int, is_active: bool, owner_id: int = _OTP.NetworkID) -> void:
   var data: PackedByteArray = []
   data.resize(OneTruePingus.NETWORK_ID_SIZE + SpellData.SPELL_ID_SIZE + SpellData.IS_ACTIVE_SIZE)
   data.encode_u32(0, owner_id)
   data.encode_u16(OneTruePingus.NETWORK_ID_SIZE, spell_id)
   data.encode_u8 (OneTruePingus.NETWORK_ID_SIZE + SpellData.SPELL_ID_SIZE, is_active)
   _OTP.send_data(DataTypes.EffectErase, data)
func send_spell_state_data     (spell_id: int, is_active: bool, spell_state: int, owner_id: int = _OTP.NetworkID) -> void:
   var data: PackedByteArray = []
   data.resize(OneTruePingus.NETWORK_ID_SIZE + SpellData.SPELL_ID_SIZE + SpellData.IS_ACTIVE_SIZE + SpellData.SPELL_STATE_SIZE)
   data.encode_u32(0, owner_id)
   data.encode_u16(OneTruePingus.NETWORK_ID_SIZE, spell_id)
   data.encode_u8 (OneTruePingus.NETWORK_ID_SIZE + SpellData.SPELL_ID_SIZE, is_active)
   data.encode_u8 (OneTruePingus.NETWORK_ID_SIZE + SpellData.SPELL_ID_SIZE + SpellData.IS_ACTIVE_SIZE, spell_state)
   _OTP.send_data(DataTypes.SpellState, data)
func send_spawn_familiar_data  (spell_id: int, is_active: bool, familiar_idx: int, creation_data: PackedByteArray, owner_id: int = _OTP.NetworkID) -> void:
   var data: PackedByteArray = []
   data.resize(OneTruePingus.NETWORK_ID_SIZE + SpellData.SPELL_ID_SIZE + SpellData.IS_ACTIVE_SIZE + SpellData.FAMILIAR_IDX_SIZE)
   data.encode_u32(0, owner_id)
   data.encode_u16(OneTruePingus.NETWORK_ID_SIZE, spell_id)
   data.encode_u8 (OneTruePingus.NETWORK_ID_SIZE + SpellData.SPELL_ID_SIZE, is_active)
   data.encode_u8 (OneTruePingus.NETWORK_ID_SIZE + SpellData.SPELL_ID_SIZE + SpellData.IS_ACTIVE_SIZE, familiar_idx)
   data.append_array(creation_data)
   _OTP.send_data(DataTypes.SpawnFamiliar, data)
