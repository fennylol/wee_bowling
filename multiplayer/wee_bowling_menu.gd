extends Control
class_name WeeBowlingMenu

enum MenuStates {NETWORK_SELECTION, HOST_SELECTION, HOST, CLIENT, CLOSED}
var MenuState: MenuStates = MenuStates.NETWORK_SELECTION:
   set(new_state):
      MenuState = new_state
      NetworkBox.visible = true  if new_state == MenuStates.NETWORK_SELECTION else false
      HostingBox.visible = true  if new_state == MenuStates.HOST_SELECTION    else false
      #HostMenu.visible   = true  if new_state == MenuStates.HOST              else false 
      HostMenu.visible   = true  if new_state == MenuStates.HOST or new_state == MenuStates.CLIENT            else false 
      #ClientMenu.visible = true  if new_state == MenuStates.CLIENT            else false
      BackButton.visible = false if new_state == MenuStates.NETWORK_SELECTION else true

@onready var BackButton  : Button        = $SubMenus/BackBox/back_button

@onready var NetworkBox   : VBoxContainer = $SubMenus/NetworkingBox
@onready var GlobalButton : Button        = $SubMenus/NetworkingBox/WAN_vs_LAN_box/global_button
@onready var LocalButton  : Button        = $SubMenus/NetworkingBox/WAN_vs_LAN_box/local_button

@onready var HostingBox   : VBoxContainer = $SubMenus/HostingBox
@onready var JoinButton   : Button        = $SubMenus/HostingBox/Host_vs_Client_box/client_button
@onready var HostButton   : Button        = $SubMenus/HostingBox/Host_vs_Client_box/host_button

@onready var HostMenu     : VBoxContainer = $SubMenus/HostMenu
@onready var ClientMenu   : VBoxContainer = $SubMenus/ClientMenu

@onready var ResumeButton : Button        = $SubMenus/HostMenu/ready_box/ResumeButton
@onready var TargetIPBox  : LineEdit      = $SubMenus/HostMenu/target_ip_box/target_IP_box
@onready var ConnectButton: Button        = $SubMenus/HostMenu/target_ip_box/connect_button
@onready var IPLabel      : Label         = $SubMenus/HostMenu/IP_info/IP_label
@onready var CopyIPButton : Button        = $SubMenus/HostMenu/IP_info/copy_IP_button
@onready var PeerStatusBox: TextEdit      = $SubMenus/HostMenu/PeerStatusBox


var Peers: Dictionary = {}

signal network_type_selected(global: bool)
signal hosting_type_selected(client: bool)
signal connect_button_pressed(Address: String)
signal resume_button_pressed()


func _ready() -> void:
   BackButton.pressed.connect(_on_back_button_pressed)
   
   GlobalButton.pressed.connect(_on_network_type_changed.bind(true))
   LocalButton.pressed.connect(_on_network_type_changed.bind(false))
   JoinButton.pressed.connect(_on_hosting_type_changed.bind(true))
   HostButton.pressed.connect(_on_hosting_type_changed.bind(false))

   ConnectButton.pressed.connect(_on_connect_button_pressed)
   CopyIPButton.pressed.connect(func(): DisplayServer.clipboard_set(IPLabel.text.strip_edges()))

   ResumeButton.pressed.connect(resume_button_pressed.emit.bind(true))
   
## =============== #
## button handlers #
## =============== #
func _on_back_button_pressed() -> void:
   MenuState = MenuStates.HOST_SELECTION if MenuState == MenuStates.HOST   else \
               MenuStates.HOST_SELECTION if MenuState == MenuStates.CLIENT else \
               MenuStates.NETWORK_SELECTION

func _on_network_type_changed(global: bool) -> void:
   MenuState = MenuStates.HOST_SELECTION
   network_type_selected.emit(global)
   
func _on_hosting_type_changed(client: bool) -> void:
   MenuState = MenuStates.CLIENT if client else MenuStates.HOST
   #MenuState = MenuStates.HOST if client else MenuStates.HOST
   hosting_type_selected.emit(client)

func _on_connect_button_pressed() -> void:
   var input_text = TargetIPBox.text.strip_edges()
   if _is_valid_ip_addr(input_text) or _is_valid_ip_port(input_text):
      TargetIPBox.text = ""
      update_peer(input_text, OneTruePingus.PingusStates.INFORMING)
      connect_button_pressed.emit(input_text)

#
## ============= #
## label setters #
## ============= #
func set_ip_label(input_text: String) -> void:
   IPLabel.text = input_text

func update_peer(peer_ip: String, status: OneTruePingus.PingusStates) -> void:
   if status == -1: Peers.erase(peer_ip)
   else: Peers.set(peer_ip, status)
   ConnectButton.disabled = Peers.size() > 0 and MenuState == MenuStates.CLIENT
   
   PeerStatusBox.text = ""
   for i in Peers.keys().size():
      PeerStatusBox.text += str(Peers.keys()[i]) + " " + str(OneTruePingus.PingusStates.find_key(Peers[Peers.keys()[i]])) + "\n"

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









const CHARS := "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ"

@warning_ignore("integer_division")
static func encode(addr: String) -> String:
   var parts := addr.split(":")
   var n := 0
   for o in parts[0].split("."):
      n = n * 256 + o.to_int()
   n = n * 65536 + parts[1].to_int()
   var code := ""
   while n > 0:
      code = CHARS[n % 36] + code
      n /= 36
   return code if code else "0"

static func decode(code: String) -> String:
   var n := 0
   for c in code.strip_edges().to_upper():
      n = n * 36 + CHARS.find(c)
   var ip := n >> 16
   return "%d.%d.%d.%d:%d" % [(ip >> 24) & 255, (ip >> 16) & 255, (ip >> 8) & 255, ip & 255, n & 65535]
