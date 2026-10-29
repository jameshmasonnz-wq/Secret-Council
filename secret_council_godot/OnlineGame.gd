extends Control
## Server-authoritative online Secret Council game. Public snapshots never contain roles.
const LIBERAL_WIN := 5
const FASCIST_WIN := 6
const MAX_PLAYERS := 10
const POLICY_LIBERAL := "Liberal"
const POLICY_FASCIST := "Fascist"

var server_players: Array[Dictionary] = [] # server only: seat, peer_id, name, role, alive, connected, token
var players_public: Array[Dictionary] = []
var phase := "nomination"
var president_seat := 0
var chancellor_seat := -1
var nominated_seat := -1
var last_president := -1
var last_chancellor := -1
var special_return_president := -1
var special_election := false
var votes: Dictionary = {}
var liberal_policies := 0
var fascist_policies := 0
var election_tracker := 0
var deck: Array[String] = []
var discard: Array[String] = []
var president_hand: Array[String] = []
var chancellor_hand: Array[String] = []
var veto_requested := false
var game_over := false
var winner := ""
var public_log: Array[String] = []
var private_message := ""
var pending_power := ""
var investigation_target := -1
var special_president_target := -1
var president_drawn_for := -1
var last_policy := ""

var title_label: Label
var status_label: Label
var track_label: Label
var roster_label: RichTextLabel
var log_label: RichTextLabel
var private_label: RichTextLabel
var actions: VBoxContainer
var vote_box: HBoxContainer
var selected_option := -1
var busy := false

func _ready() -> void:
	_build_ui()
	if multiplayer.multiplayer_peer == null:
		status_label.text = "No network session. Return to lobby and connect first."
		return
	if multiplayer.is_server():
		if not multiplayer.peer_disconnected.is_connected(_on_peer_disconnected): multiplayer.peer_disconnected.connect(_on_peer_disconnected)
		_start_authoritative_game()
	else:
		_request_state.rpc_id(1)
	_render()

func _build_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new(); bg.color = Color("#0b1020"); bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); bg.mouse_filter = Control.MOUSE_FILTER_IGNORE; add_child(bg)
	var margin := MarginContainer.new(); margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for key in ["margin_left", "margin_right"]: margin.add_theme_constant_override(key, 26)
	for key in ["margin_top", "margin_bottom"]: margin.add_theme_constant_override(key, 20)
	add_child(margin)
	var root := VBoxContainer.new(); root.add_theme_constant_override("separation", 12); margin.add_child(root)
	title_label = Label.new(); title_label.text = "SECRET COUNCIL  /  LIVE SESSION"; title_label.add_theme_font_size_override("font_size", 26); title_label.add_theme_color_override("font_color", Color("#f8fafc")); root.add_child(title_label)
	status_label = Label.new(); status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; status_label.add_theme_color_override("font_color", Color("#bfdbfe")); root.add_child(status_label)
	track_label = Label.new(); track_label.add_theme_font_size_override("font_size", 17); track_label.add_theme_color_override("font_color", Color("#e2e8f0")); root.add_child(track_label)
	var columns: BoxContainer = VBoxContainer.new() if OS.has_feature("web") else HBoxContainer.new(); columns.size_flags_vertical = Control.SIZE_EXPAND_FILL; columns.add_theme_constant_override("separation", 16); root.add_child(columns)
	var left := _panel("#111b2e"); left.size_flags_horizontal = Control.SIZE_EXPAND_FILL; left.size_flags_vertical = Control.SIZE_EXPAND_FILL; columns.add_child(left)
	var heading := Label.new(); heading.text = "COUNCIL TABLE"; heading.add_theme_font_size_override("font_size", 16); left.add_child(heading)
	roster_label = RichTextLabel.new(); roster_label.bbcode_enabled = true; roster_label.size_flags_vertical = Control.SIZE_EXPAND_FILL; roster_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL; left.add_child(roster_label)
	var right := _panel("#111b2e"); right.custom_minimum_size.x = 0 if OS.has_feature("web") else 540; right.size_flags_vertical = Control.SIZE_EXPAND_FILL; columns.add_child(right)
	var log_heading := Label.new(); log_heading.text = "PUBLIC LOG"; log_heading.add_theme_font_size_override("font_size", 16); right.add_child(log_heading)
	log_label = RichTextLabel.new(); log_label.bbcode_enabled = true; log_label.size_flags_vertical = Control.SIZE_EXPAND_FILL; right.add_child(log_label)
	private_label = RichTextLabel.new(); private_label.bbcode_enabled = true; private_label.fit_content = true; private_label.custom_minimum_size.y = 58; private_label.add_theme_color_override("default_color", Color("#f8fafc")); right.add_child(private_label)
	actions = VBoxContainer.new(); actions.add_theme_constant_override("separation", 7); right.add_child(actions)
	var leave := _button("Return to lobby (disconnects)", "#3f1d2a", func(): get_tree().change_scene_to_file("res://OnlineLobby.tscn")); right.add_child(leave)

func _panel(color_hex: String) -> PanelContainer:
	var p := PanelContainer.new(); var s := StyleBoxFlat.new(); s.bg_color = Color(color_hex); s.border_color = Color("#293b59"); s.set_border_width_all(1); s.set_corner_radius_all(10); s.content_margin_left = 14; s.content_margin_right = 14; s.content_margin_top = 12; s.content_margin_bottom = 12; p.add_theme_stylebox_override("panel", s); return p

func _button(label: String, color_hex: String, callback: Callable) -> Button:
	var b := Button.new(); b.text = label; b.custom_minimum_size.y = 38; b.size_flags_horizontal = Control.SIZE_EXPAND_FILL; var s := StyleBoxFlat.new(); s.bg_color = Color(color_hex); s.set_corner_radius_all(7); b.add_theme_stylebox_override("normal", s); var h := s.duplicate() as StyleBoxFlat; h.bg_color = s.bg_color.lightened(0.12); b.add_theme_stylebox_override("hover", h); b.add_theme_color_override("font_color", Color("#f8fafc")); b.pressed.connect(callback); return b

func _start_authoritative_game() -> void:
	server_players.clear()
	var ids := GameSession.public_players.duplicate(true)
	ids.sort_custom(func(a, b): return int(a.get("id", 0)) < int(b.get("id", 0)))
	for item in ids:
		var seat := server_players.size()
		var role := str(GameSession.server_roles[seat]) if seat < GameSession.server_roles.size() else "Liberal"
		server_players.append({"seat": seat, "peer_id": int(item.get("id", -1)), "name": str(item.get("name", "Player")), "role": role, "alive": true, "connected": true, "token": ""})
	# The lobby created the role list on the server. Secrets are never included in public snapshots.
	_make_deck()
	_add_log("The council convenes. Elect a President and Chancellor.")
	_publish_state()
	
func _assign_server_roles_if_missing() -> void:
	var missing := false
	for p in server_players:
		if str(p.role).is_empty(): missing = true
	if not missing: return
	var n := server_players.size(); var fascists := 1
	if n >= 7: fascists = 2
	if n >= 9: fascists = 3
	var roles: Array[String] = []
	for i in range(n - fascists - 1): roles.append("Liberal")
	for i in range(fascists): roles.append("Fascist")
	roles.append("Hitler"); roles.shuffle()
	for i in range(n):
		server_players[i].role = roles[i]
		var info := _team_info(i)
		if int(server_players[i].peer_id) == 1:
			GameSession.private_role = roles[i]; GameSession.private_team_info = info
		else:
			_receive_private_role.rpc_id(int(server_players[i].peer_id), roles[i], info)

func _team_info(seat: int) -> String:
	var role := str(server_players[seat].role); var n := server_players.size(); var known: Array[String] = []
	if role == "Liberal": return "You do not know the other players' roles."
	if role == "Hitler":
		if n <= 6:
			for p in server_players:
				if p.role == "Fascist": return "Your Fascist teammate is %s." % p.name
		return "You do not know the Fascist team at this player count."
	for i in range(n):
		if i != seat and server_players[i].role in ["Fascist", "Hitler"] and (n <= 6 or server_players[i].role == "Fascist"):
			known.append("%s (%s)" % [server_players[i].name, server_players[i].role])
	return "Known team: " + ", ".join(known) if not known.is_empty() else "No teammate information."

func _make_deck() -> void:
	deck.clear(); discard.clear()
	for i in range(6): deck.append(POLICY_LIBERAL)
	for i in range(11): deck.append(POLICY_FASCIST)
	deck.shuffle()

func _my_seat() -> int:
	if multiplayer.is_server():
		for p in server_players:
			if int(p.peer_id) == multiplayer.get_unique_id(): return int(p.seat)
	return GameSession.my_seat

func _server_seat_for_peer(peer_id: int) -> int:
	for p in server_players:
		if int(p.peer_id) == peer_id: return int(p.seat)
	return -1

func _living_seats() -> Array[int]:
	var result: Array[int] = []
	for p in server_players:
		if bool(p.alive): result.append(int(p.seat))
	return result

func _eligible_chancellors() -> Array[int]:
	var out: Array[int] = []
	for p in server_players:
		var s := int(p.seat)
		if not bool(p.alive) or s == president_seat or s == last_chancellor: continue
		if _living_seats().size() > 5 and s == last_president: continue
		out.append(s)
	return out

func _is_president() -> bool: return _my_seat() == president_seat
func _is_chancellor() -> bool: return _my_seat() == chancellor_seat

func _next_president_after(seat: int) -> int:
	var living := _living_seats()
	if living.is_empty(): return 0
	for step in range(1, server_players.size() + 1):
		var candidate := (seat + step) % server_players.size()
		if candidate in living: return candidate
	return living[0]

func _publish_state() -> void:
	if not multiplayer.is_server(): return
	players_public.clear()
	for p in server_players:
		players_public.append({"seat": int(p.seat), "name": str(p.name), "alive": bool(p.alive), "connected": bool(p.connected)})
	var snapshot := {"players": players_public, "phase": phase, "president": president_seat, "chancellor": chancellor_seat, "nominated": nominated_seat, "last_president": last_president, "last_chancellor": last_chancellor, "liberal": liberal_policies, "fascist": fascist_policies, "tracker": election_tracker, "votes": _public_votes(), "log": public_log, "game_over": game_over, "winner": winner, "power": pending_power, "veto": veto_requested}
	_receive_public_state(snapshot)
	_receive_public_state.rpc(snapshot)
	_send_private_prompts()

func _public_votes() -> Array:
	var living := _living_seats()
	if votes.size() < living.size(): return [] # simultaneous voting: keep every vote hidden until all living players have voted
	var out: Array = []
	for p in server_players:
		var s := int(p.seat)
		if votes.has(s): out.append({"seat": s, "vote": str(votes[s])})
	return out

func _send_private_prompts() -> void:
	# Build a separate prompt for every seat; secret hands/results go only to their owner.
	for p in server_players:
		var seat := int(p.seat)
		var prompt := ""
		var choices: Array = []
		var data: Dictionary = {}
		if phase == "nomination" and seat == president_seat:
			prompt = "Nominate a Chancellor"; choices = _eligible_chancellors()
		elif phase == "voting" and bool(p.alive) and not votes.has(seat):
			prompt = "Cast your vote"; choices = ["Ja", "Nein"]
		elif phase == "president_discard" and seat == president_seat:
			prompt = "Choose one policy to discard"; choices = president_hand.duplicate(); data = {"cards": president_hand.duplicate()}
		elif phase == "chancellor_enact" and seat == chancellor_seat:
			prompt = "Choose a policy to enact"; choices = chancellor_hand.duplicate(); data = {"cards": chancellor_hand.duplicate(), "veto_available": fascist_policies >= 5}
		elif phase == "veto_response" and seat == president_seat:
			prompt = "Chancellor requested a veto. Accept it?"; choices = ["Accept veto", "Reject veto"]
		elif phase == "power_target" and seat == president_seat:
			prompt = "Choose a living player to %s" % pending_power; choices = _living_seats(); choices.erase(president_seat)
		elif phase == "investigation_result" and seat == president_seat:
			prompt = "Investigation complete"; data = {"message": private_message}
		elif phase == "special_election_target" and seat == president_seat:
			prompt = "Choose the next President"; choices = _living_seats(); choices.erase(president_seat)
		_send_private_prompt_to(seat, prompt, choices, data)

func _send_private_prompt_to(seat: int, prompt: String, choices: Array, data: Dictionary) -> void:
	var p := _player_by_seat(seat)
	if p.is_empty(): return
	var peer_id := int(p.peer_id)
	var payload := {"prompt": prompt, "choices": choices, "data": data, "seat": seat}
	if peer_id == 1: _receive_private_prompt(payload)
	elif peer_id > 0: _receive_private_prompt.rpc_id(peer_id, payload)

func _player_by_seat(seat: int) -> Dictionary:
	for p in server_players:
		if int(p.seat) == seat: return p
	return {}

@rpc("authority", "call_remote", "reliable")
func _receive_private_role(role: String, team_info: String) -> void:
	GameSession.private_role = role; GameSession.private_team_info = team_info
	private_label.text = "[b]YOUR SECRET ROLE: %s[/b]\n%s" % [role.to_upper(), team_info]

@rpc("any_peer", "call_remote", "reliable")
func _request_state() -> void:
	if multiplayer.is_server():
		var sender := multiplayer.get_remote_sender_id()
		if _server_seat_for_peer(sender) >= 0: _publish_state()

@rpc("authority", "call_remote", "reliable")
func _receive_public_state(snapshot: Dictionary) -> void:
	players_public = snapshot.get("players", [])
	phase = str(snapshot.get("phase", phase)); president_seat = int(snapshot.get("president", president_seat)); chancellor_seat = int(snapshot.get("chancellor", chancellor_seat)); nominated_seat = int(snapshot.get("nominated", nominated_seat)); last_president = int(snapshot.get("last_president", last_president)); last_chancellor = int(snapshot.get("last_chancellor", last_chancellor)); liberal_policies = int(snapshot.get("liberal", 0)); fascist_policies = int(snapshot.get("fascist", 0)); election_tracker = int(snapshot.get("tracker", 0)); votes = {}
	for item in snapshot.get("votes", []): votes[int(item.seat)] = str(item.vote)
	public_log = snapshot.get("log", []); game_over = bool(snapshot.get("game_over", false)); winner = str(snapshot.get("winner", "")); pending_power = str(snapshot.get("power", "")); veto_requested = bool(snapshot.get("veto", false))
	_render()

@rpc("authority", "call_remote", "reliable")
func _receive_private_prompt(payload: Dictionary) -> void:
	private_label.text = "[b]YOUR SECRET ROLE: %s[/b]\n%s" % [GameSession.private_role.to_upper(), GameSession.private_team_info]
	if not str(payload.get("prompt", "")).is_empty(): private_label.text += "\n\n[color=#93c5fd]%s[/color]" % str(payload.prompt)
	var data: Dictionary = payload.get("data", {})
	if data.has("message"): private_label.text += "\n[color=#fcd34d]%s[/color]" % str(data.message)
	if data.has("cards"):
		private_label.text += "\nYour private hand: " + ", ".join(data.cards)
	_render_actions(str(payload.get("prompt", "")), payload.get("choices", []), data)

func _render() -> void:
	if not is_node_ready(): return
	track_label.text = "LIBERAL %d / 5     FASCIST %d / 6     Election tracker %d / 3" % [liberal_policies, fascist_policies, election_tracker]
	var out := ""
	for p in players_public:
		var s := int(p.seat); var mark := "  [color=#fcd34d]PRESIDENT[/color]" if s == president_seat else ""
		if s == chancellor_seat and phase not in ["nomination", "voting"]: mark += "  [color=#86efac]CHANCELLOR[/color]"
		var alive := "" if bool(p.alive) else "  [color=#f87171]ELIMINATED[/color]"
		var conn := "" if bool(p.connected) else "  [color=#94a3b8]DISCONNECTED[/color]"
		out += "%s. %s%s%s%s\n" % [s + 1, str(p.name), mark, alive, conn]
	roster_label.text = out
	log_label.text = "\n".join(public_log)
	if game_over: status_label.text = "%s VICTORY — %s" % [winner.to_upper(), "Game over"]
	else: status_label.text = "Phase: %s   |   %s" % [phase.replace("_", " ").to_upper(), _phase_summary()]

func _phase_summary() -> String:
	if players_public.is_empty(): return "Waiting for authoritative state…"
	var pres := _name_for_seat(president_seat)
	match phase:
		"nomination": return "%s is President and must nominate a Chancellor." % pres
		"voting": return "All living players vote simultaneously. Votes remain hidden until everyone has voted."
		"president_discard": return "%s is privately choosing which policy to discard." % pres
		"chancellor_enact": return "%s is privately choosing a policy to enact." % _name_for_seat(chancellor_seat)
		"power_target": return "Presidential power: %s." % pending_power
		"veto_response": return "The President must respond to a veto request."
		"special_election_target": return "The President selects a one-time successor."
		"investigation_result": return "An investigation result was privately delivered."
	return "Game state synchronized."

func _name_for_seat(seat: int) -> String:
	for p in players_public:
		if int(p.seat) == seat: return str(p.name)
	return "Unknown"

func _render_actions(prompt: String, choices: Array, data: Dictionary) -> void:
	for child in actions.get_children(): child.queue_free()
	if game_over: return
	if prompt.is_empty(): return
	var heading := Label.new(); heading.text = prompt; heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; actions.add_child(heading)
	if prompt == "Investigation complete":
		actions.add_child(_button("Continue", "#1d4ed8", func(): _send_action("clear_private", {})))
		return
	for i in range(choices.size()):
		var choice = choices[i]
		var label := ""
		if typeof(choice) == TYPE_INT: label = _name_for_seat(int(choice))
		else: label = str(choice)
		var idx := i
		var button := _button(label, "#1d4ed8", func(): _submit_choice(prompt, idx, choices, data))
		actions.add_child(button)
	if prompt == "Choose a policy to enact" and bool(data.get("veto_available", false)):
		actions.add_child(_button("Request veto", "#7f1d1d", func(): _send_action("veto_request", {})))

func _submit_choice(prompt: String, index: int, choices: Array, data: Dictionary) -> void:
	var choice = choices[index]
	match prompt:
		"Nominate a Chancellor": _send_action("nominate", {"target": int(choice)})
		"Cast your vote": _send_action("vote", {"vote": str(choice)})
		"Choose one policy to discard": _send_action("president_discard", {"index": index})
		"Choose a policy to enact": _send_action("chancellor_enact", {"index": index})
		"Chancellor requested a veto. Accept it?": _send_action("veto_response", {"accept": index == 0})
		"Choose a living player to %s" % pending_power: _send_action("power_target", {"target": int(choice)})
		"Choose the next President": _send_action("special_election", {"target": int(choice)})
		"Investigation complete": _send_action("clear_private", {})

func _send_action(action: String, data: Dictionary) -> void:
	if multiplayer.is_server(): _handle_action(multiplayer.get_unique_id(), action, data)
	else: _submit_action.rpc_id(1, action, data)

@rpc("any_peer", "call_remote", "reliable")
func _submit_action(action: String, data: Dictionary) -> void:
	if not multiplayer.is_server() or game_over: return
	_handle_action(multiplayer.get_remote_sender_id(), action, data)

func _handle_action(sender: int, action: String, data: Dictionary) -> void:
	var seat := _server_seat_for_peer(sender)
	if seat < 0: return
	var player := _player_by_seat(seat)
	if player.is_empty() or not bool(player.alive) or not bool(player.connected): return
	match action:
		"nominate":
			if phase != "nomination" or seat != president_seat: return
			var target := int(data.get("target", -1)); if target not in _eligible_chancellors(): return
			nominated_seat = target; votes.clear(); phase = "voting"
			for disconnected_player in server_players:
				if bool(disconnected_player.alive) and not bool(disconnected_player.connected): votes[int(disconnected_player.seat)] = "Nein"
			_add_log("%s nominated %s for Chancellor." % [_name_for_seat(seat), _name_for_seat(target)])
			var living_now := _living_seats(); var auto_cast := 0
			for living_seat in living_now:
				if votes.has(living_seat): auto_cast += 1
			if auto_cast == living_now.size(): _resolve_election()
			else: _publish_state()
		"vote":
			if phase != "voting" or votes.has(seat): return
			var vote := str(data.get("vote", "")); if vote not in ["Ja", "Nein"]: return
			votes[seat] = vote
			var living := _living_seats(); var cast := 0
			for s in living:
				if votes.has(s): cast += 1
			if cast == living.size(): _resolve_election()
			else: _publish_state()
		"president_discard":
			if phase != "president_discard" or seat != president_seat: return
			var idx := int(data.get("index", -1)); if idx < 0 or idx >= president_hand.size(): return
			var discarded := president_hand[idx]; discard.append(discarded); president_hand.remove_at(idx); chancellor_hand = president_hand.duplicate(); president_hand.clear(); phase = "chancellor_enact"; _add_log("The President passed two policies to the Chancellor."); _publish_state()
		"chancellor_enact":
			if phase != "chancellor_enact" or seat != chancellor_seat: return
			var idx := int(data.get("index", -1)); if idx < 0 or idx >= chancellor_hand.size(): return
			var policy := chancellor_hand[idx]
			for j in range(chancellor_hand.size()):
				if j != idx: discard.append(chancellor_hand[j])
			chancellor_hand.clear(); president_hand.clear()
			_enact_policy(policy)
		"veto_request":
			if phase != "chancellor_enact" or seat != chancellor_seat or fascist_policies < 5: return
			phase = "veto_response"; veto_requested = true; _add_log("The Chancellor requested a veto."); _publish_state()
		"veto_response":
			if phase != "veto_response" or seat != president_seat: return
			var accept := bool(data.get("accept", false)); veto_requested = false; chancellor_hand.clear()
			if accept:
				discard.append_array(chancellor_hand); election_tracker += 1; _add_log("The President accepted the veto. No policy was enacted."); _after_failed_veto()
			else:
				_add_log("The President rejected the veto; the Chancellor must enact a policy."); phase = "chancellor_enact"
			_publish_state()
		"power_target":
			if phase != "power_target" or seat != president_seat: return
			_resolve_power(int(data.get("target", -1)))
		"special_election":
			if phase != "special_election_target" or seat != president_seat: return
			var target := int(data.get("target", -1)); if target not in _living_seats() or target == president_seat: return
			special_return_president = president_seat; president_seat = target; special_election = true; phase = "nomination"; _add_log("A special election selected %s as the next President." % _name_for_seat(target)); _publish_state()
		"clear_private":
			if phase == "investigation_result" and seat == president_seat:
				private_message = ""; pending_power = ""; _advance_after_legislative()

func _resolve_election() -> void:
	var ja := 0; var nein := 0
	for vote in votes.values():
		if vote == "Ja": ja += 1
		else: nein += 1
	var passed := ja > nein
	_add_log("Election result: %d Ja / %d Nein — %s." % [ja, nein, "elected" if passed else "rejected"])
	if not passed:
		election_tracker += 1; nominated_seat = -1
		if election_tracker >= 3:
			var top := _draw_policy(); _add_log("Three elections failed. Top policy enacted automatically: %s." % top); election_tracker = 0; _enact_policy(top, false); return
		phase = "nomination"; president_seat = _next_president_after(president_seat); _publish_state(); return
	last_president = president_seat; chancellor_seat = nominated_seat; last_chancellor = chancellor_seat; election_tracker = 0
	if fascist_policies >= 3 and str(_player_by_seat(chancellor_seat).role) == "Hitler": _finish_game("Fascist", "Hitler was elected Chancellor after three Fascist policies."); return
	phase = "president_discard"; president_hand.clear(); chancellor_hand.clear()
	if deck.size() < 3:
		deck.append_array(discard); discard.clear(); deck.shuffle()
	for i in range(3): president_hand.append(_draw_policy())
	_publish_state()

func _draw_policy() -> String:
	if deck.is_empty():
		if discard.is_empty(): _make_deck()
		else:
			deck = discard.duplicate(); discard.clear(); deck.shuffle()
	return deck.pop_back()

func _enact_policy(policy: String, trigger_power: bool = true) -> void:
	last_policy = policy
	if policy == POLICY_LIBERAL: liberal_policies += 1
	else: fascist_policies += 1
	_add_log("A %s policy was enacted." % policy)
	if liberal_policies >= LIBERAL_WIN: _finish_game("Liberal", "Five Liberal policies were enacted."); return
	if fascist_policies >= FASCIST_WIN: _finish_game("Fascist", "Six Fascist policies were enacted."); return
	if trigger_power and policy == POLICY_FASCIST:
		var power := _power_for_track(fascist_policies, server_players.size())
		if not power.is_empty():
			pending_power = power
			if power == "investigate": phase = "power_target"
			elif power == "special election": phase = "special_election_target"
			elif power == "execute": phase = "power_target"
			_publish_state(); return
	_advance_after_legislative()

func _power_for_track(count: int, n: int) -> String:
	if n <= 6:
		if count in [2, 3]: return "investigate"
		if count == 4: return "special election"
		if count in [5, 6]: return "execute"
	elif n <= 8:
		if count == 2: return "investigate"
		if count == 3: return "special election"
		if count in [4, 5]: return "execute"
		if count == 6: return "execute"
	else:
		if count in [1, 4]: return "special election"
		if count in [2, 3, 5, 6]: return "execute"
	return ""

func _resolve_power(target: int) -> void:
	if target not in _living_seats() or target == president_seat: return
	if pending_power == "investigate":
		var role := str(_player_by_seat(target).role)
		private_message = "%s is on the %s team." % [_name_for_seat(target), "Fascist" if role in ["Fascist", "Hitler"] else "Liberal"]
		phase = "investigation_result"; _add_log("The President investigated a player. The result is private."); _publish_state(); return
	if pending_power == "execute":
		var p := _player_by_seat(target); p.alive = false
		_add_log("%s was executed." % _name_for_seat(target))
		if str(p.role) == "Hitler": _finish_game("Liberal", "Hitler was executed."); return
		if _living_seats().size() <= 1: _finish_game("Fascist", "Only one player remains alive."); return
	pending_power = ""; _advance_after_legislative()

func _after_failed_veto() -> void:
	if election_tracker >= 3:
		var top := _draw_policy(); election_tracker = 0; _add_log("Veto completed the failed-election track. Top policy enacted: %s." % top); _enact_policy(top, false); return
	phase = "nomination"; nominated_seat = -1; president_seat = _next_president_after(president_seat)

func _advance_after_legislative() -> void:
	pending_power = ""; nominated_seat = -1; chancellor_seat = -1; votes.clear()
	if special_election:
		president_seat = _next_president_after(special_return_president); special_election = false
	else: president_seat = _next_president_after(president_seat)
	phase = "nomination"; _publish_state()

func _finish_game(team: String, reason: String) -> void:
	game_over = true; winner = team; phase = "game_over"; _add_log("%s victory: %s" % [team, reason]); _publish_state()

func _add_log(line: String) -> void:
	public_log.append(line)
	if public_log.size() > 30: public_log.pop_front()

func _on_peer_disconnected(peer_id: int) -> void:
	if not multiplayer.is_server(): return
	var seat := _server_seat_for_peer(peer_id)
	if seat < 0: return
	var p := _player_by_seat(seat)
	p.connected = false
	_add_log("%s disconnected. Their seat is retained for this session." % str(p.name))
	# Avoid a stalled simultaneous vote: a disconnected player's vote defaults to Nein.
	if phase == "voting" and not votes.has(seat):
		votes[seat] = "Nein"
		var cast := 0
		for living_seat in _living_seats():
			if votes.has(living_seat): cast += 1
		if cast == _living_seats().size(): _resolve_election(); return
	_publish_state()

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and multiplayer.multiplayer_peer != null and multiplayer.is_server():
		pass
