extends Node
class_name WeeBowling
## lobby flow:[br]
## 1. host and joiner swap IP:Port strings and both press connect. the
## [PingusPuncher] punches through NAT.[br]
## 2. as soon as a punch completes, the [PingusPuncher] is freed and ENet is
## bound to the same local port: the host as a server, joiners as clients of
## the host.[br]
## 3. once the host is on ENet, it answers later joiners from ENet's socket with
## packets shaped like [PingusPuncher] INFORMs (see [method _punch_from_enet]),
## so their handshake completes the same way.

# ========= #
# constants #
# ========= #
## players the host's ENet server accepts, host included
const MAX_PLAYERS        : int    = 8
## times a joiner restarts its ENet connection attempt before giving up
const CLIENT_MAX_ATTEMPTS: int    = 10
const CLIENT_RETRY_TIME  : float  = 0.5
## a joiner keeps its puncher alive this long after connecting, so it can answer
## the host's INFORMs if the host's side of the handshake hasn't finished yet
const JOIN_HANDOFF_DELAY : float  = 1.0
## how long the host sends NAT-opening packets toward a joiner, and how often
const PUNCH_TIME         : float  = 20.0
const PUNCH_INTERVAL     : float  = 0.2
const LAN_PLACEHOLDER    : String = "PEE.POO.CUM.POO"
# ========= #
# variables #
# ========= #
@onready var _ConnectionMenu: ConnectMenu = $ConnectMenu
var _PP            : PingusPuncher = null
var _NetworkID     : int           = 0
var _Hosting       : bool          = false
var _Global        : bool          = true
var _MyName        : String        = ""
## true once ENet has taken over the socket and the [PingusPuncher] is gone
var _InSession     : bool          = false
## true while a joiner waits out [constant JOIN_HANDOFF_DELAY]
var _HandingOff    : bool          = false
var _HostAddr      : String        = ""
var _HostPort      : int           = -1
var _LocalPort     : int           = 0
var _ClientAttempts: int           = 0
## display names of everyone in the ENet session, keyed by multiplayer peer ID
var _Names         : Dictionary[int, String] = {}

var DEBUG_PRINT_CONTROL_MESSAGES: bool = true

func _ready() -> void:
   _start_puncher()
   _MyName = str(_NetworkID)
   _ConnectionMenu.set_id_label(str(_NetworkID))
   _ConnectionMenu.set_name_placeholder(_MyName)

   _ConnectionMenu.identity_changed.connect(_on_identity_changed)
   _ConnectionMenu.connect_button_pressed.connect(_on_connect_button_pressed)
   _ConnectionMenu.network_type_changed.connect(_on_network_type_changed)
   _ConnectionMenu.hosting_type_changed.connect(_on_hosting_type_changed)
   _ConnectionMenu.quit_button_pressed.connect(_on_disconnect_button_pressed)

   multiplayer.peer_connected.connect(_on_session_peer_connected)
   multiplayer.peer_disconnected.connect(_on_session_peer_disconnected)
   multiplayer.connected_to_server.connect(_on_connected_to_server)
   multiplayer.connection_failed.connect(_on_connection_failed)
   multiplayer.server_disconnected.connect(func(): _return_to_lobby.call_deferred())

   _refresh_ip_label()
   _refresh_peer_list()

# =============== #
# signal handling #
# =============== #
func _on_pp_control_emitted(msg: String) -> void:
   _refresh_ip_label()
   _refresh_peer_list()
   if DEBUG_PRINT_CONTROL_MESSAGES:
      print("PingusPuncher: ", msg)
func _on_connect_button_pressed(target_address: String) -> void:
   var parts := target_address.rsplit(":", true, 1)
   if parts.size() < 2: return
   var addr: String = parts[0]
   var port: int    = parts[1].to_int()
   if _InSession:
      # the PingusPuncher is gone, so a late joiner is punched from ENet's socket
      if _Hosting: _punch_from_enet(addr, port)
      return
   _PP.add_peer(addr, port)
   _refresh_peer_list()
func _on_disconnect_button_pressed() -> void:
   if _InSession:
      _return_to_lobby()
      return
   _HandingOff = false
   _PP.Peers.clear()
   _refresh_peer_list()
func _on_connection_established(_network_id: int, peer_address: String, peer_port: int) -> void:
   _refresh_peer_list()
   if _InSession or _HandingOff: return
   if _Hosting: _start_server()
   else       : _start_client(peer_address, peer_port)
func _on_identity_changed(new_name: String) -> void:
   _MyName = new_name
   if _InSession and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
      _Names[multiplayer.get_unique_id()] = _MyName
      _rpc_identity.rpc(_MyName)
   _refresh_peer_list()
func _on_network_type_changed(global: bool) -> void:
   _Global = global
   if _PP:
      if not global: _use_lan_address()
      elif _PP.ExternAddr == LAN_PLACEHOLDER and not _PP._FetchingAddress: _PP._discover_address()
   _refresh_ip_label()
func _on_hosting_type_changed(client: bool) -> void:
   _Hosting = not client
   _refresh_peer_list()

# ================ #
# puncher handling #
# ================ #
func _start_puncher() -> void:
   _PP = PingusPuncher.new("", _NetworkID)
   _NetworkID = _PP.NetworkID
   _PP.control_emitted.connect(_on_pp_control_emitted)
   _PP.connection_established.connect(_on_connection_established)
   _PP.set_name("PingusPuncher")
   add_child(_PP)
   if not _Global: _use_lan_address()
## LAN play shouldn't have to wait on STUN before the puncher starts listening
func _use_lan_address() -> void:
   if _PP.ExternAddr == "":
      _PP.ExternAddr = LAN_PLACEHOLDER
      _PP.ExternPort = _PP.LocalPort
## close the puncher's socket now (not at the end of the frame) so ENet can bind its port
func _release_puncher() -> void:
   _LocalPort = _PP.LocalPort
   _PP.set_process(false)
   _PP._Udp.close()
   _PP.queue_free()
   _PP = null

# ============== #
# ENet handoff   #
# ============== #
func _start_server() -> void:
   var punched: Array[PingusPuncher.PingusPeer] = _PP.Peers.duplicate()
   _release_puncher()
   var peer := ENetMultiplayerPeer.new()
   var err  := peer.create_server(_LocalPort, MAX_PLAYERS - 1)
   if err != OK:
      printerr("WeeBowling: failed to host on port ", _LocalPort, " (", error_string(err), ")")
      _return_to_lobby()
      return
   multiplayer.multiplayer_peer = peer
   _InSession = true
   _Names[1] = _MyName
   # finishes the handshake for anyone still informing, and keeps the holes open
   for p in punched: _punch_from_enet(p.Addr, p.Port)
   _refresh_peer_list()
func _start_client(host_addr: String, host_port: int) -> void:
   _HostAddr   = host_addr
   _HostPort   = host_port
   _HandingOff = true
   _refresh_peer_list()
   await get_tree().create_timer(JOIN_HANDOFF_DELAY).timeout
   if not _HandingOff: return # quit was pressed while waiting
   _HandingOff = false
   _release_puncher()
   _InSession = true
   _ClientAttempts = 0
   _connect_client()
func _connect_client() -> void:
   _ClientAttempts += 1
   var peer := ENetMultiplayerPeer.new()
   var err  := peer.create_client(_HostAddr, _HostPort, 0, 0, 0, _LocalPort)
   if err != OK:
      printerr("WeeBowling: failed to bind port ", _LocalPort, " (", error_string(err), ")")
      _on_connection_failed()
      return
   multiplayer.multiplayer_peer = peer
   _refresh_peer_list()
## ENet gives up after its own timeout. the host may simply not have pressed
## switched to ENet yet, so start over on the same port a few times.
func _on_connection_failed() -> void:
   await get_tree().create_timer(CLIENT_RETRY_TIME).timeout
   if not _InSession or _Hosting: return
   multiplayer.multiplayer_peer.close()
   if _ClientAttempts >= CLIENT_MAX_ATTEMPTS:
      printerr("WeeBowling: could not reach host at ", _HostAddr, ":", _HostPort)
      _return_to_lobby()
      return
   _connect_client()
## send INFORM packets from ENet's bound socket. they open the host's NAT
## toward the joiner, and the joiner's [PingusPuncher] accepts them as the
## host's half of the handshake, which triggers its handoff.[br]
## ENet drops the joiner's own INFORMs that land here: their first two bytes
## read as ENet peer ID 30, past this server's peer count. keep
## [constant MAX_PLAYERS] at 31 or below.
func _punch_from_enet(addr: String, port: int) -> void:
   var enet := multiplayer.multiplayer_peer as ENetMultiplayerPeer
   var pkt  := PackedByteArray()
   pkt.resize(PingusPuncher.HEADER_SIZE + PingusPuncher.PORT_SIZE)
   pkt.encode_u16(0, PingusPuncher.PingusTypes.INFORM)
   pkt.encode_u32(PingusPuncher.PINGUS_TYPE_SIZE, _NetworkID)
   pkt.encode_u32(PingusPuncher.PINGUS_TYPE_SIZE + PingusPuncher.NETWORK_ID_SIZE, 0)
   pkt.encode_u16(PingusPuncher.HEADER_SIZE, port)
   var elapsed := 0.0
   while elapsed < PUNCH_TIME:
      if enet == null or multiplayer.multiplayer_peer != enet: return
      enet.host.socket_send(addr, port, pkt)
      await get_tree().create_timer(PUNCH_INTERVAL).timeout
      elapsed += PUNCH_INTERVAL
func _return_to_lobby() -> void:
   _InSession  = false
   _HandingOff = false
   multiplayer.multiplayer_peer.close()
   multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
   _Names.clear()
   if _PP == null: _start_puncher()
   _refresh_ip_label()
   _refresh_peer_list()

# ================ #
# session handling #
# ================ #
func _on_session_peer_connected(id: int) -> void:
   _rpc_identity.rpc_id(id, _MyName)
   _refresh_peer_list()
func _on_session_peer_disconnected(id: int) -> void:
   _Names.erase(id)
   _refresh_peer_list()
func _on_connected_to_server() -> void:
   _ClientAttempts = 0
   _Names[multiplayer.get_unique_id()] = _MyName
   _refresh_peer_list()
@rpc("any_peer", "reliable")
func _rpc_identity(new_name: String) -> void:
   _Names[multiplayer.get_remote_sender_id()] = new_name.left(25)
   _refresh_peer_list()

# ========== #
# menu state #
# ========== #
func _refresh_ip_label() -> void:
   if _PP == null: return
   if _Global and (_PP.ExternAddr == "" or _PP.ExternAddr == LAN_PLACEHOLDER):
      _ConnectionMenu.set_ip_label("fetching...")
   else:
      _ConnectionMenu.set_ip_label(_PP.get_addr_port(_Global))
func _refresh_peer_list() -> void:
   var have_peers := _PP != null and not _PP.Peers.is_empty()
   if _InSession: _ConnectionMenu.update_session_peers(_Names, multiplayer.get_unique_id())
   else         : _ConnectionMenu.update_peers(_PP.Peers)
   var status: String = "punching..." if have_peers else "not connected"
   if _HandingOff: status = "joining host..."
   elif _InSession:
      if _Hosting: status = "hosting"
      elif multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED: status = "connected"
      else: status = "joining host... (" + str(_ClientAttempts) + "/" + str(CLIENT_MAX_ATTEMPTS) + ")"
   _ConnectionMenu.set_session_state(
      status,
      _InSession or _HandingOff,                     # lock the mode toggles
      _InSession or _HandingOff or have_peers,       # quit
      (not _InSession and not _HandingOff) or _Hosting # connect
   )
