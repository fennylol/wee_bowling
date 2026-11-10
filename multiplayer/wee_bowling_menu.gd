extends Control
class_name WeeBowlingMenu

enum MenuStates {NETWORK_SELECTION, CONNECTION, CLOSED}
var MenuState: MenuStates = MenuStates.NETWORK_SELECTION:
   set(new_state):
      MenuState = new_state
      NetworkBox.visible     = true  if new_state == MenuStates.NETWORK_SELECTION else false
      ConnectionMenu.visible = true  if new_state == MenuStates.CONNECTION        else false
      _update_back_button()

@onready var BackButton  : Button        = $SubMenus/BackBox/back_button
@onready var QuitButton  : Button        = $SubMenus/BackBox/quit_button

@onready var NetworkBox   : VBoxContainer = $SubMenus/NetworkingBox
@onready var GlobalButton : Button        = $SubMenus/NetworkingBox/WAN_vs_LAN_box/global_button
@onready var LocalButton  : Button        = $SubMenus/NetworkingBox/WAN_vs_LAN_box/local_button

@onready var ConnectionMenu: VBoxContainer = $SubMenus/ConnectionMenu

@onready var ResumeButton : Button        = $SubMenus/ConnectionMenu/ready_box/ResumeButton
@onready var TargetIPBox  : LineEdit      = $SubMenus/ConnectionMenu/target_ip_box/target_IP_box
@onready var ConnectButton: Button        = $SubMenus/ConnectionMenu/target_ip_box/connect_button
@onready var IPLabel      : Label         = $SubMenus/ConnectionMenu/IP_info/IP_label
@onready var CopyIPButton    : Button    = $SubMenus/ConnectionMenu/IP_info/copy_buttons/copy_IP_button
@onready var CopyCodeButton  : Button    = $SubMenus/ConnectionMenu/IP_info/copy_buttons/copy_code_button
@onready var CopyKoreanButton: Button    = $SubMenus/ConnectionMenu/IP_info/copy_buttons/copy_korean_button
@onready var PeerStatusBox: TextEdit      = $SubMenus/ConnectionMenu/PeerStatusBox


var Peers: Dictionary = {}

signal network_type_selected(global: bool)
signal connect_button_pressed(Address: String)
signal quit_button_pressed()
signal resume_button_pressed()


func _ready() -> void:
   BackButton.pressed.connect(_on_back_button_pressed)
   QuitButton.pressed.connect(_on_quit_button_pressed)

   GlobalButton.pressed.connect(_on_network_type_changed.bind(true))
   LocalButton.pressed.connect(_on_network_type_changed.bind(false))

   ConnectButton.pressed.connect(_on_connect_button_pressed)
   CopyIPButton.pressed.connect    (_copy_address.bind(func(addr: String): return addr))
   CopyCodeButton.pressed.connect  (_copy_address.bind(encode))
   CopyKoreanButton.pressed.connect(_copy_address.bind(encode_korean))

   ResumeButton.pressed.connect(resume_button_pressed.emit.bind(true))
   
## =============== #
## button handlers #
## =============== #
func _on_back_button_pressed() -> void:
   MenuState = MenuStates.NETWORK_SELECTION

## drops every connection (handled by whoever listens to [signal quit_button_pressed])
## and returns to the global/local selection
func _on_quit_button_pressed() -> void:
   quit_button_pressed.emit()
   MenuState = MenuStates.NETWORK_SELECTION

func _on_network_type_changed(global: bool) -> void:
   MenuState = MenuStates.CONNECTION
   network_type_selected.emit(global)

## accepts a raw IP:port, an invite code, or a Korean invite code. the decoders
## return "" for input that isn't theirs, so the first valid address wins.
func _on_connect_button_pressed() -> void:
   var input_text := TargetIPBox.text.strip_edges()
   for address: String in [input_text, decode(input_text), decode_korean(input_text)]:
      if _is_valid_ip_addr(address) or _is_valid_ip_port(address):
         TargetIPBox.text = ""
         update_peer(address, OneTruePingus.PingusStates.INFORMING)
         connect_button_pressed.emit(address)
         return

## copies the IP label run through [param encoder]. does nothing until the label
## holds a real IP:port (not the placeholder)
func _copy_address(encoder: Callable) -> void:
   var addr := IPLabel.text.strip_edges()
   if _is_valid_ip_port(addr): DisplayServer.clipboard_set(encoder.call(addr))
#
## ============= #
## label setters #
## ============= #
func set_ip_label(input_text: String) -> void:
   IPLabel.text = input_text

func update_peer(peer_ip: String, status: OneTruePingus.PingusStates) -> void:
   if status == -1: Peers.erase(peer_ip)
   else: Peers.set(peer_ip, status)
   _update_back_button()

   PeerStatusBox.text = ""
   for i in Peers.keys().size():
      PeerStatusBox.text += str(Peers.keys()[i]) + " " + str(OneTruePingus.PingusStates.find_key(Peers[Peers.keys()[i]])) + "\n"

## rebuild the peer list from [member OneTruePingus.Peers]. ported from tournamancy's ConnectMenu.update_peers
func update_peers(peers: Array[OneTruePingus.PingusPeer]) -> void:
   Peers.clear()
   var lines: PackedStringArray = []
   for peer in peers:
      Peers.set(peer.Addr + ":" + str(peer.Port), peer.State)
      var state_str: String = peer.Addr + ":" + str(peer.Port)
      match peer.State:
         OneTruePingus.PingusStates.NOT_STARTED: state_str += " not started"
         OneTruePingus.PingusStates.INFORMING  : state_str += " informing..."
         OneTruePingus.PingusStates.CONNECTED  : state_str += " connected"
         _                                     : state_str += " unknown"
      if peer.NetworkID != 0: state_str = str(peer.NetworkID) + "\n" + state_str
      lines.append(state_str)
   PeerStatusBox.text = "\n".join(lines)
   _update_back_button()

## back and quit share a spot: back while there are no connections, quit once there are
func _update_back_button() -> void:
   BackButton.visible = MenuState != MenuStates.NETWORK_SELECTION and Peers.is_empty()
   QuitButton.visible = MenuState != MenuStates.NETWORK_SELECTION and not Peers.is_empty()

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

## returns "" if [param code] has characters outside [constant CHARS] or is too big to be an IP:port
static func decode(code: String) -> String:
   var n := 0
   for c in code.strip_edges().to_upper():
      var digit := CHARS.find(c)
      if digit == -1: return ""
      n = n * 36 + digit
      if n >= 1 << 48: return ""
   var ip := n >> 16
   return "%d.%d.%d.%d:%d" % [(ip >> 24) & 255, (ip >> 16) & 255, (ip >> 8) & 255, ip & 255, n & 65535]

## first of the 4096 Hangul syllables used. each syllable holds 12 bits, so 4 hold a full IP:port
const KOREAN_START := 0xAC00

@warning_ignore("integer_division")
static func encode_korean(addr: String) -> String:
   var parts := addr.split(":")
   var n := 0
   for o in parts[0].split("."):
      n = n * 256 + o.to_int()
   n = n * 65536 + parts[1].to_int()
   var code := ""
   for i in 4:
      code = char(KOREAN_START + n % 4096) + code
      n /= 4096
   return code

## returns "" unless [param code] is exactly 4 syllables from U+AC00 to U+BBFF
static func decode_korean(code: String) -> String:
   code = code.strip_edges()
   if code.length() != 4: return ""
   var n := 0
   for c in code:
      var digit := c.unicode_at(0) - KOREAN_START
      if digit < 0 or digit >= 4096: return ""
      n = n * 4096 + digit
   var ip := n >> 16
   return "%d.%d.%d.%d:%d" % [(ip >> 24) & 255, (ip >> 16) & 255, (ip >> 8) & 255, ip & 255, n & 65535]
