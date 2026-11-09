extends HBoxContainer
class_name ConnectMenu

@onready var GLOBAL_BUTTON  : Button   = $VBoxContainer/HBoxContainer/YourInfo/WAN_vs_LAN_box/global_button
@onready var LOCAL_BUTTON   : Button   = $VBoxContainer/HBoxContainer/YourInfo/WAN_vs_LAN_box/local_button
@onready var JOIN_BUTTON    : Button   = $VBoxContainer/HBoxContainer/YourInfo/Host_vs_Client_box/client_button
@onready var HOST_BUTTON    : Button   = $VBoxContainer/HBoxContainer/YourInfo/Host_vs_Client_box/host_button
@onready var ID_LABEL       : Label    = $VBoxContainer/HBoxContainer/YourInfo/id_info/ID_label
@onready var COPY_ID_BUTTON : Button   = $VBoxContainer/HBoxContainer/YourInfo/id_info/copy_ID_button
@onready var IP_LABEL       : Label    = $VBoxContainer/HBoxContainer/YourInfo/IP_info/IP_label
@onready var COPY_IP_BUTTON : Button   = $VBoxContainer/HBoxContainer/YourInfo/IP_info/copy_IP_button
@onready var NAME_TAG_BOX   : LineEdit = $VBoxContainer/HBoxContainer/YourInfo/name_box/name_box
@onready var SET_NAME_BUTTON: Button   = $VBoxContainer/HBoxContainer/YourInfo/name_box/set_name_button

@onready var QUIT_BUTTON    : Button   = $VBoxContainer/HBoxContainer/TheirInfo/quit_button
@onready var PEER_LIST      : TextEdit = $VBoxContainer/HBoxContainer/TheirInfo/peer_list
@onready var TARGET_IP_BOX  : LineEdit = $VBoxContainer/HBoxContainer/TheirInfo/target_ip_box/target_IP_box
@onready var CONNECT_BUTTON : Button   = $VBoxContainer/HBoxContainer/TheirInfo/target_ip_box/connect_button
@onready var STATUS_LABEL   : Label    = $VBoxContainer/status_label


signal network_type_changed(global: bool)
signal hosting_type_changed(client: bool)
signal connect_button_pressed(Address: String)
signal quit_button_pressed()
signal identity_changed(new_name: String)

var _IsGlobal: bool = true
var _IsClient: bool = true

func _ready() -> void:
   GLOBAL_BUTTON.pressed.connect(_on_network_type_changed.bind(true))
   LOCAL_BUTTON.pressed.connect(_on_network_type_changed.bind(false))
   JOIN_BUTTON.pressed.connect(_on_hosting_type_changed.bind(true))
   HOST_BUTTON.pressed.connect(_on_hosting_type_changed.bind(false))
   
   CONNECT_BUTTON.pressed.connect(_on_connect_button_pressed)
   SET_NAME_BUTTON.pressed.connect(_on_set_name_button_pressed)
   QUIT_BUTTON.pressed.connect(quit_button_pressed.emit)
   
   COPY_ID_BUTTON.pressed.connect(func(): DisplayServer.clipboard_set(ID_LABEL.text.strip_edges()))
   COPY_IP_BUTTON.pressed.connect(func(): DisplayServer.clipboard_set(IP_LABEL.text.strip_edges()))
   


# =============== #
# button handlers #
# =============== #
func _on_connect_button_pressed() -> void:
   var input_text = TARGET_IP_BOX.text.strip_edges()
   if _is_valid_ip_port(input_text):
      TARGET_IP_BOX.text = ""
      connect_button_pressed.emit(input_text)
func _on_set_name_button_pressed() -> void:
   var new_name: String = NAME_TAG_BOX.text.strip_edges()
   if new_name != "":
      NAME_TAG_BOX.placeholder_text = new_name
      NAME_TAG_BOX.text = ""
      identity_changed.emit(new_name)
func _on_network_type_changed(global: bool) -> void:
   _IsGlobal = global
   network_type_changed.emit(global)
   GLOBAL_BUTTON.disabled = global
   LOCAL_BUTTON.disabled = not global
func _on_hosting_type_changed(client: bool) -> void:
   _IsClient = client
   hosting_type_changed.emit(client)
   JOIN_BUTTON.disabled = client
   HOST_BUTTON.disabled = not client
   QUIT_BUTTON.text = ("quit" if client else "close") + " lobby"

# ============= #
# label setters #
# ============= #
func set_id_label(input_text: String) -> void:
   ID_LABEL.text = input_text
func set_ip_label(input_text: String) -> void:
   #if _is_valid_ip_addr(input_text):
   IP_LABEL.text = input_text
func set_name_placeholder(current_name: String) -> void:
   NAME_TAG_BOX.placeholder_text = current_name
## [param status] is shown under the peer list. [param locked] freezes the
## global/local and host/join toggles while a session is live.
func set_session_state(status: String, locked: bool, can_quit: bool, can_connect: bool) -> void:
   STATUS_LABEL.text       = status
   QUIT_BUTTON.disabled    = not can_quit
   CONNECT_BUTTON.disabled = not can_connect
   GLOBAL_BUTTON.disabled  = locked or _IsGlobal
   LOCAL_BUTTON.disabled   = locked or not _IsGlobal
   JOIN_BUTTON.disabled    = locked or _IsClient
   HOST_BUTTON.disabled    = locked or not _IsClient
# ============= #
# other utility #
# ============= #
func update_peers(peers: Array[PingusPuncher.PingusPeer]) -> void:
   var lines: PackedStringArray = []
   for peer in peers:
      var state_str: String = peer.Addr + ":" + str(peer.Port)
      match peer.State:
         PingusPuncher.PingusStates.NOT_STARTED: state_str += " not started"
         PingusPuncher.PingusStates.INFORMING  : state_str += " informing..."
         PingusPuncher.PingusStates.CONNECTED  : state_str += " connected"
         _                                     : state_str += " unknown"
      lines.append(state_str)
   _set_peer_list_text("\n".join(lines))
## list everyone in the ENet session by display name
func update_session_peers(names: Dictionary[int, String], my_id: int) -> void:
   var ids := names.keys()
   ids.sort()
   var lines: PackedStringArray = []
   for id in ids:
      var line: String = names[id]
      if id == 1    : line += " (host)"
      if id == my_id: line += " (you)"
      lines.append(line)
   _set_peer_list_text("\n".join(lines))
## only touch the TextEdit when the text changes, since this runs every frame
## while the puncher is informing
func _set_peer_list_text(new_text: String) -> void:
   if PEER_LIST.text != new_text: PEER_LIST.text = new_text
      
func _is_valid_ip_addr(input_text: String) -> bool:
   var regex = RegEx.new()
   regex.compile("^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$")
   var result = regex.search(input_text)
   return true if result else false

func _is_valid_ip_port(input_text: String) -> bool:
   var parts := input_text.rsplit(":", true, 1)
   if parts.size() != 2: return false
   if not _is_valid_ip_addr(parts[0]): return false
   if not parts[1].is_valid_int(): return false
   var port := int(parts[1])
   return port >= 1 and port <= 65535
