extends Control
## Online multiplayer lobby and private-role assignment for Secret Council.
## Host-authoritative networking. WebSocket transport supports exported browser/mobile clients; ENet is desktop-only.

const DEFAULT_PORT := 24590
const MAX_CLIENTS := 9 # plus host = 10 players
const MIN_PLAYERS := 5
const MAX_PLAYERS := 10

var peer: MultiplayerPeer
var is_host := false
var local_peer_id := 1
var local_name := "Player"
var lobby_players: Dictionary = {} # peer_id -> display name; public only
var private_role := ""
var private_team_info := ""
var game_started := false

var status_label: Label
var roster_label: RichTextLabel
var name_input: LineEdit
var address_input: LineEdit
var port_input: SpinBox
var transport_option: OptionButton
var lobby_panel: VBoxContainer
var role_panel: PanelContainer
var role_title: Label
var role_detail: RichTextLabel
var action_buttons: HBoxContainer

func _ready() -> void:
	_build_ui()
	_update_roster()

func _build_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.color = Color("#0b1020")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 36)
	margin.add_theme_constant_override("margin_right", 36)
	margin.add_theme_constant_override("margin_top", 28)
	margin.add_theme_constant_override("margin_bottom", 28)
	add_child(margin)

	var root_box := VBoxContainer.new()
	root_box.add_theme_constant_override("separation", 16)
	margin.add_child(root_box)

	var header := Label.new()
	header.text = "SECRET COUNCIL  /  ONLINE"
	header.add_theme_font_size_override("font_size", 28)
	header.add_theme_color_override("font_color", Color("#f8fafc"))
	root_box.add_child(header)

	var subtitle := Label.new()
	subtitle.text = "A hidden-role policy game • Private roles • Host-authoritative lobby"
	subtitle.add_theme_color_override("font_color", Color("#94a3b8"))
	root_box.add_child(subtitle)

	status_label = Label.new()
	status_label.text = "Host a room or join a friend's room to begin."
	status_label.custom_minimum_size.y = 38
	status_label.add_theme_color_override("font_color", Color("#bfdbfe"))
	root_box.add_child(status_label)

	var columns: BoxContainer = VBoxContainer.new() if OS.has_feature("web") else HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 18)
	root_box.add_child(columns)

	var setup_panel := _make_panel("#111b2e", "#293b59")
	setup_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	setup_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_child(setup_panel)
	var setup := VBoxContainer.new()
	setup.add_theme_constant_override("separation", 10)
	setup_panel.add_child(setup)

	_add_heading(setup, "CONNECTION")
	_add_caption(setup, "Display name")
	name_input = LineEdit.new()
	name_input.placeholder_text = "Enter a name"
	name_input.text = "Player"
	name_input.custom_minimum_size.y = 40
	setup.add_child(name_input)

	_add_caption(setup, "Server URL / address (for joining)")
	address_input = LineEdit.new()
	address_input.text = "" if OS.has_feature("web") else "ws://127.0.0.1:24590"
	address_input.custom_minimum_size.y = 40
	address_input.placeholder_text = "wss://your-public-tunnel.example" if OS.has_feature("web") else "ws://127.0.0.1:24590"
	setup.add_child(address_input)

	_add_caption(setup, "Network transport")
	transport_option = OptionButton.new()
	transport_option.add_item("WebSocket (website + mobile)", 0)
	transport_option.add_item("ENet (desktop only)", 1)
	transport_option.select(0)
	if OS.has_feature("web"):
		transport_option.set_item_disabled(1, true)
	transport_option.custom_minimum_size.y = 40
	setup.add_child(transport_option)

	_add_caption(setup, "Port (host listens here)")
	port_input = SpinBox.new()
	port_input.min_value = 1024
	port_input.max_value = 65535
	port_input.value = DEFAULT_PORT
	port_input.step = 1
	port_input.custom_minimum_size.y = 40
	setup.add_child(port_input)

	var host_button := _make_button("Host room", "#1d4ed8")
	host_button.pressed.connect(_host_room)
	setup.add_child(host_button)
	var join_button := _make_button("Join room", "#1b2a43")
	join_button.pressed.connect(_join_room)
	setup.add_child(join_button)
	var leave_button := _make_button("Disconnect", "#3f1d2a")
	leave_button.pressed.connect(_disconnect_room)
	setup.add_child(leave_button)

	_add_heading(setup, "NETWORK NOTES")
	_add_caption(setup, "For browser/mobile play, choose WebSocket. The host runs this project as a desktop app; players use the exported Web build. For internet play, expose this WebSocket port through a secure WSS tunnel/reverse proxy. Never expose an untrusted game server: this prototype has no account system.")

	var room_panel := _make_panel("#111b2e", "#293b59")
	room_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	room_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_child(room_panel)
	var room := VBoxContainer.new()
	room.add_theme_constant_override("separation", 10)
	room_panel.add_child(room)
	_add_heading(room, "COUNCIL ROSTER")
	roster_label = RichTextLabel.new()
	roster_label.bbcode_enabled = true
	roster_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	roster_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	roster_label.add_theme_font_size_override("normal_font_size", 17)
	roster_label.add_theme_color_override("default_color", Color("#e2e8f0"))
	room.add_child(roster_label)

	var start_button := _make_button("Start game (host only · 5–10 players)", "#14532d")
	start_button.pressed.connect(_host_start_game)
	room.add_child(start_button)

	role_panel = _make_panel("#172554", "#60a5fa")
	role_panel.visible = false
	root_box.add_child(role_panel)
	var role_box := VBoxContainer.new()
	role_box.add_theme_constant_override("separation", 8)
	role_panel.add_child(role_box)
	role_title = Label.new()
	role_title.text = "YOUR SECRET ROLE"
	role_title.add_theme_font_size_override("font_size", 19)
	role_title.add_theme_color_override("font_color", Color("#bfdbfe"))
	role_box.add_child(role_title)
	role_detail = RichTextLabel.new()
	role_detail.bbcode_enabled = true
	role_detail.fit_content = true
	role_detail.custom_minimum_size.y = 80
	role_detail.add_theme_color_override("default_color", Color("#f8fafc"))
	role_box.add_child(role_detail)

func _make_panel(bg_hex: String, border_hex: String) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(bg_hex)
	style.border_color = Color(border_hex)
	style.set_border_width_all(1)
	style.set_corner_radius_all(12)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	panel.add_theme_stylebox_override("panel", style)
	return panel

func _add_heading(parent: VBoxContainer, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", Color("#e2e8f0"))
	parent.add_child(label)

func _add_caption(parent: VBoxContainer, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color("#94a3b8"))
	parent.add_child(label)

func _make_button(text: String, color_hex: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 42
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(color_hex)
	normal.set_corner_radius_all(8)
	normal.content_margin_left = 10
	normal.content_margin_right = 10
	normal.content_margin_top = 8
	normal.content_margin_bottom = 8
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = normal.bg_color.lightened(0.12)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_color_override("font_color", Color("#f8fafc"))
	return button

func _host_room() -> void:
	if multiplayer.multiplayer_peer != null:
		_disconnect_room()
	var chosen_name := _clean_name(name_input.text)
	var port := int(port_input.value)
	var err: int = OK
	if transport_option.selected == 0:
		var ws_peer := WebSocketMultiplayerPeer.new()
		err = ws_peer.create_server(port, "*")
		if err == OK:
			peer = ws_peer
	else:
		var enet_peer := ENetMultiplayerPeer.new()
		err = enet_peer.create_server(port, MAX_CLIENTS)
		if err == OK:
			peer = enet_peer
	if err != OK:
		status_label.text = "Could not host on port %d (error %d)." % [port, err]
		return
	multiplayer.multiplayer_peer = peer
	is_host = true
	local_peer_id = 1
	local_name = chosen_name
	lobby_players.clear()
	lobby_players[1] = local_name
	_connect_signals()
	status_label.text = ("Hosting WebSocket on port %d. Desktop clients can use ws://HOST:%d; browser clients on HTTPS need a public wss:// URL via a secure tunnel." % [port, port]) if transport_option.selected == 0 else ("Hosting ENet on UDP port %d (desktop clients only)." % port)
	_update_roster()

func _join_room() -> void:
	if multiplayer.multiplayer_peer != null:
		_disconnect_room()
	local_name = _clean_name(name_input.text)
	var address := address_input.text.strip_edges()
	if address.is_empty():
		address = ("127.0.0.1:%d" % int(port_input.value)) if transport_option.selected == 0 else "127.0.0.1"
	var err: int = OK
	if transport_option.selected == 0:
		address = _normalize_websocket_url(address)
		var ws_peer := WebSocketMultiplayerPeer.new()
		err = ws_peer.create_client(address)
		if err == OK:
			peer = ws_peer
	else:
		var enet_peer := ENetMultiplayerPeer.new()
		err = enet_peer.create_client(address, int(port_input.value))
		if err == OK:
			peer = enet_peer
	if err != OK:
		status_label.text = "Could not start connection (error %d)." % err
		return
	multiplayer.multiplayer_peer = peer
	is_host = false
	_connect_signals()
	status_label.text = "Connecting to %s…" % (address if transport_option.selected == 0 else "%s:%d" % [address, int(port_input.value)])


func _normalize_websocket_url(raw: String) -> String:
	var url := raw.strip_edges()
	if url.begins_with("https://"):
		return "wss://" + url.trim_prefix("https://")
	if url.begins_with("http://"):
		return "ws://" + url.trim_prefix("http://")
	if url.begins_with("wss://") or url.begins_with("ws://"):
		return url
	# HTTPS-hosted browser builds must use WSS; desktop builds may use local ws://.
	return ("wss://" if OS.has_feature("web") else "ws://") + url

func _connect_signals() -> void:
	var connected := Callable(self, "_on_peer_connected")
	var disconnected := Callable(self, "_on_peer_disconnected")
	var failed := Callable(self, "_on_connection_failed")
	var server_disconnected := Callable(self, "_on_server_disconnected")
	if not multiplayer.peer_connected.is_connected(connected):
		multiplayer.peer_connected.connect(connected)
	if not multiplayer.peer_disconnected.is_connected(disconnected):
		multiplayer.peer_disconnected.connect(disconnected)
	if not multiplayer.connected_to_server.is_connected(_on_connected_to_server):
		multiplayer.connected_to_server.connect(_on_connected_to_server)
	if not multiplayer.connection_failed.is_connected(failed):
		multiplayer.connection_failed.connect(failed)
	if not multiplayer.server_disconnected.is_connected(server_disconnected):
		multiplayer.server_disconnected.connect(server_disconnected)

func _on_connected_to_server() -> void:
	local_peer_id = multiplayer.get_unique_id()
	_request_join.rpc_id(1, local_name)
	status_label.text = "Connected. Waiting for the host to start the game."

func _on_peer_connected(id: int) -> void:
	if not is_host:
		return
	# The new client sends its name through _request_join after connecting.
	status_label.text = "Player connected (peer %d)." % id

func _on_peer_disconnected(id: int) -> void:
	if is_host:
		lobby_players.erase(id)
		_broadcast_lobby()
		status_label.text = "Peer %d disconnected." % id
	else:
		status_label.text = "A player disconnected."
	_update_roster()

func _on_connection_failed() -> void:
	status_label.text = "Connection failed. Check the URL, transport, server, firewall, and WSS tunnel if using HTTPS."
	multiplayer.multiplayer_peer = null
	peer = null

func _on_server_disconnected() -> void:
	status_label.text = "Disconnected from host."
	multiplayer.multiplayer_peer = null
	peer = null
	lobby_players.clear()
	_update_roster()

func _disconnect_room() -> void:
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	peer = null
	is_host = false
	game_started = false
	private_role = ""
	private_team_info = ""
	lobby_players.clear()
	role_panel.visible = false
	status_label.text = "Disconnected."
	_update_roster()

func _clean_name(raw: String) -> String:
	var cleaned := raw.strip_edges().replace("[", "").replace("]", "")
	if cleaned.is_empty():
		cleaned = "Player"
	return cleaned.substr(0, 18)

@rpc("any_peer", "call_remote", "reliable")
func _request_join(player_name: String) -> void:
	if not multiplayer.is_server() or game_started:
		return
	var sender := multiplayer.get_remote_sender_id()
	if lobby_players.size() >= MAX_PLAYERS:
		_kick_full_room.rpc_id(sender)
		return
	lobby_players[sender] = _clean_name(player_name)
	_broadcast_lobby()

@rpc("authority", "call_remote", "reliable")
func _kick_full_room() -> void:
	status_label.text = "This room is full."
	_disconnect_room()

func _broadcast_lobby() -> void:
	var public_roster: Array[Dictionary] = []
	var ids := lobby_players.keys()
	ids.sort()
	for id in ids:
		public_roster.append({"id": int(id), "name": str(lobby_players[id])})
	_receive_lobby(public_roster)
	_receive_lobby.rpc(public_roster)

@rpc("authority", "call_remote", "reliable")
func _receive_lobby(public_roster: Array) -> void:
	lobby_players.clear()
	for item in public_roster:
		lobby_players[int(item["id"])] = str(item["name"])
	_update_roster()

func _update_roster() -> void:
	if roster_label == null:
		return
	var out := "[color=#94a3b8]%d / %d players[/color]\n\n" % [lobby_players.size(), MAX_PLAYERS]
	var ids := lobby_players.keys()
	ids.sort()
	for id in ids:
		var marker := "  [color=#86efac]HOST[/color]" if int(id) == 1 else ""
		var you := "  [color=#93c5fd](YOU)[/color]" if int(id) == multiplayer.get_unique_id() and multiplayer.multiplayer_peer != null else ""
		out += "[color=#e2e8f0]●  %s[/color]%s%s\n" % [str(lobby_players[id]), marker, you]
	if lobby_players.is_empty():
		out += "\n[color=#64748b]No room joined yet.[/color]"
	roster_label.text = out

func _host_start_game() -> void:
	if not is_host or not multiplayer.is_server():
		status_label.text = "Only the host can start the game."
		return
	if lobby_players.size() < MIN_PLAYERS:
		status_label.text = "Need at least %d connected players to start (currently %d)." % [MIN_PLAYERS, lobby_players.size()]
		return
	game_started = true
	var ids := lobby_players.keys()
	ids.sort()
	var roles := _make_roles(ids.size())
	roles.shuffle()
	GameSession.server_roles = roles.duplicate()
	GameSession.public_players.clear()
	var public_players: Array[Dictionary] = []
	for i in range(ids.size()):
		var player_data := {"id": int(ids[i]), "name": str(lobby_players[ids[i]])}
		public_players.append(player_data)
		var role: String = roles[i]
		var team_info := _team_info_for(role, roles, ids, i)
		if int(ids[i]) == 1:
			_receive_private_role(role, team_info)
		else:
			_receive_private_role.rpc_id(int(ids[i]), role, team_info)
	GameSession.public_players = public_players.duplicate(true)
	GameSession.my_seat = 0
	_receive_game_started(public_players)
	_receive_game_started.rpc(public_players)

func _make_roles(count: int) -> Array[String]:
	var fascist_count := 1
	if count >= 7:
		fascist_count = 2
	if count >= 9:
		fascist_count = 3
	var result: Array[String] = []
	for i in range(count - fascist_count - 1):
		result.append("Liberal")
	for i in range(fascist_count):
		result.append("Fascist")
	result.append("Hitler")
	return result

func _team_info_for(role: String, roles: Array[String], ids: Array, own_index: int) -> String:
	if role == "Liberal":
		return "You do not know the other players' roles."
	if role == "Hitler":
		if roles.size() <= 6:
			for i in range(roles.size()):
				if roles[i] == "Fascist":
					return "Your Fascist teammate is %s." % str(lobby_players[int(ids[i])])
		return "In this player count, you do not know the Fascist team."
	var teammates: Array[String] = []
	for i in range(roles.size()):
		if i != own_index and roles[i] in ["Fascist", "Hitler"]:
			if roles.size() <= 6 or roles[i] == "Fascist":
				teammates.append("%s (%s)" % [str(lobby_players[int(ids[i])]), roles[i]])
	return "Known team: " + ", ".join(teammates) if not teammates.is_empty() else "You have no teammate information."

@rpc("authority", "call_remote", "reliable")
func _receive_private_role(role: String, team_info: String) -> void:
	# This RPC is sent only to the matching peer. Never broadcast secret roles.
	private_role = role
	private_team_info = team_info
	role_panel.visible = true
	role_title.text = "YOUR SECRET ROLE: " + role.to_upper()
	var role_color := "#93c5fd" if role == "Liberal" else "#fda4af"
	role_detail.text = "[color=%s][b]%s[/b][/color]\n\n%s\n\n[color=#94a3b8]Keep this information private. It is not shared with the lobby.[/color]" % [role_color, role, team_info]
	var tween := create_tween()
	role_panel.modulate.a = 0.0
	tween.tween_property(role_panel, "modulate:a", 1.0, 0.35)
	status_label.text = "Game started. Your role was delivered privately."

@rpc("authority", "call_remote", "reliable")
func _receive_game_started(public_players: Array) -> void:
	game_started = true
	GameSession.public_players = public_players.duplicate(true)
	GameSession.my_seat = -1
	for i in range(public_players.size()):
		if int(public_players[i].get("id", -1)) == multiplayer.get_unique_id(): GameSession.my_seat = i
	status_label.text = "Game in session — opening the council table…"
	var names: Array[String] = []
	for item in public_players: names.append(str(item.get("name", "Player")))
	roster_label.text = "[color=#94a3b8]GAME IN SESSION · %d PLAYERS[/color]\n\n%s\n\n[color=#86efac]Role assignment was sent privately to each player.[/color]" % [public_players.size(), ", ".join(names)]
	_enter_online_game.call_deferred()

func _enter_online_game() -> void:
	await get_tree().create_timer(0.3).timeout
	if is_inside_tree(): get_tree().change_scene_to_file("res://OnlineGame.tscn")
