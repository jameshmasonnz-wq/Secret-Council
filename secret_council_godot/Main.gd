extends Control
## Secret Council: original hidden-role policy game prototype for Godot 4.x.
## Seven-player ruleset with term limits, Fascist presidential powers, and veto.

const PLAYER_COUNT := 7
const LIBERAL_WIN := 5
const FASCIST_WIN := 6

var players: Array[Dictionary] = []
var liberal_policies := 0
var fascist_policies := 0
var election_tracker := 0
var president_index := 0
var chancellor_index := -1
var previous_president := -1
var previous_chancellor := -1
var nominated_chancellor := -1
var phase := "start"
var deck: Array[String] = []
var discard_pile: Array[String] = []
var hand: Array[String] = []
var legislative_cards: Array[String] = []
var log_lines: Array[String] = []
var game_over := false

# Special election selects the next President, then normal rotation resumes
# from the President who called the special election.
var special_next_president := -1
var special_return_index := -1
var special_president_active := false
var pending_power := ""
var pending_power_president := -1
var veto_pending_cards: Array[String] = []

var title_label: Label
var status_label: Label
var players_label: RichTextLabel
var log_label: RichTextLabel
var action_box: VBoxContainer
var liberal_track_label: Label
var fascist_track_label: Label

func _ready() -> void:
	randomize()
	_build_ui()
	_show_start()

func _build_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color("#111827")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var outer := VBoxContainer.new()
	outer.name = "MainLayout"
	outer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	outer.add_theme_constant_override("separation", 12)
	outer.add_theme_constant_override("margin_left", 26)
	outer.add_theme_constant_override("margin_right", 26)
	outer.add_theme_constant_override("margin_top", 20)
	outer.add_theme_constant_override("margin_bottom", 20)
	add_child(outer)

	title_label = Label.new()
	title_label.text = "SECRET COUNCIL"
	title_label.add_theme_font_size_override("font_size", 30)
	title_label.add_theme_color_override("font_color", Color("#f3f4f6"))
	outer.add_child(title_label)

	status_label = Label.new()
	status_label.text = "A hidden-role policy game"
	status_label.add_theme_font_size_override("font_size", 16)
	status_label.add_theme_color_override("font_color", Color("#cbd5e1"))
	outer.add_child(status_label)

	var tracks := HBoxContainer.new()
	tracks.add_theme_constant_override("separation", 14)
	outer.add_child(tracks)
	var liberal_panel := _panel("#1d4ed8")
	liberal_track_label = Label.new()
	liberal_track_label.text = "LIBERAL POLICIES  0 / 5"
	liberal_track_label.add_theme_font_size_override("font_size", 17)
	liberal_track_label.add_theme_color_override("font_color", Color.WHITE)
	liberal_panel.add_child(liberal_track_label)
	tracks.add_child(liberal_panel)

	var fascist_panel := _panel("#991b1b")
	fascist_track_label = Label.new()
	fascist_track_label.text = "FASCIST POLICIES  0 / 6"
	fascist_track_label.add_theme_font_size_override("font_size", 17)
	fascist_track_label.add_theme_color_override("font_color", Color.WHITE)
	fascist_panel.add_child(fascist_track_label)
	tracks.add_child(fascist_panel)

	var columns := HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 14)
	outer.add_child(columns)

	var left := _panel("#1f2937")
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_child(left)
	var ptitle := Label.new()
	ptitle.text = "TABLE"
	ptitle.add_theme_font_size_override("font_size", 18)
	left.add_child(ptitle)
	players_label = RichTextLabel.new()
	players_label.bbcode_enabled = true
	players_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	players_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_child(players_label)

	var right := _panel("#1f2937")
	right.custom_minimum_size.x = 500
	right.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_child(right)
	var ltitle := Label.new()
	ltitle.text = "GAME LOG"
	ltitle.add_theme_font_size_override("font_size", 18)
	right.add_child(ltitle)
	log_label = RichTextLabel.new()
	log_label.bbcode_enabled = true
	log_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_child(log_label)

	action_box = VBoxContainer.new()
	action_box.add_theme_constant_override("separation", 7)
	outer.add_child(action_box)

func _panel(color_hex: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = Color(color_hex)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", style)
	return panel

func _clear_actions() -> void:
	for child in action_box.get_children():
		child.queue_free()

func _button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 40
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(callback)
	action_box.add_child(button)
	return button

func _show_start() -> void:
	_clear_actions()
	status_label.text = "A local seven-player hidden-role policy game."
	players_label.text = "[color=#cbd5e1]Start a new game to receive a secret role and begin the first election.[/color]"
	log_label.text = "[color=#94a3b8]Your role, game events, and powers will appear here.[/color]"
	_button("Start new game", _start_game)
	_button("How to play", _show_help)
	_render_tracks()

func _show_help() -> void:
	_clear_actions()
	status_label.text = "How to play"
	players_label.text = "[b]Teams[/b]\nLiberals enact 5 Liberal policies. Fascists enact 6 Fascist policies. After 3 Fascist policies, electing Hitler as Chancellor wins the game for Fascists.\n\n[b]Election[/b]\nThe President nominates a Chancellor. Everyone votes Ja or Nein. Failed governments advance the election tracker; at 3, the top policy is enacted by chaos.\n\n[b]Legislative session[/b]\nThe President draws 3 policies and discards 1. The Chancellor chooses 1 of the remaining 2 to enact. After 5 Fascist policies, the Chancellor may propose a veto; the President decides whether to accept it.\n\n[b]Seven-player Fascist powers[/b]\n3 policies: investigate a player's party; 4: special election; 5 and 6: execute a player. Execution of Hitler wins for Liberals."
	log_label.text = "Term limits prevent the previous President and Chancellor from being nominated Chancellor while 6 or more players remain. At 5 remaining, only the previous Chancellor is term-limited."
	_button("Back", _show_start)

func _start_game() -> void:
	players.clear()
	liberal_policies = 0
	fascist_policies = 0
	election_tracker = 0
	president_index = 0
	chancellor_index = -1
	previous_president = -1
	previous_chancellor = -1
	nominated_chancellor = -1
	game_over = false
	phase = "nominate"
	special_next_president = -1
	special_return_index = -1
	special_president_active = false
	pending_power = ""
	pending_power_president = -1
	veto_pending_cards.clear()
	discard_pile.clear()
	hand.clear()
	legislative_cards.clear()
	log_lines.clear()

	var roles: Array[String] = ["Liberal", "Liberal", "Liberal", "Liberal", "Fascist", "Fascist", "Hitler"]
	roles.shuffle()
	for i in range(PLAYER_COUNT):
		players.append({
			"name": "You" if i == 0 else "Player %d" % (i + 1),
			"role": roles[i],
			"alive": true
		})
	_reset_deck()
	_add_log("A new council has assembled. Your secret role is [b]%s[/b]." % players[0]["role"])
	if players[0]["role"] == "Fascist":
		var allies: Array[String] = []
		for i in range(PLAYER_COUNT):
			if i != 0 and players[i]["role"] in ["Fascist", "Hitler"]:
				allies.append("%s (%s)" % [players[i]["name"], players[i]["role"]])
		_add_log("Known Fascist team: " + ", ".join(allies))
	elif players[0]["role"] == "Hitler":
		_add_log("As Hitler in a seven-player game, you do not know the Fascist team.")
	else:
		_add_log("You are Liberal. You do not know the other players' roles.")
	_render()
	_show_nomination()

func _reset_deck() -> void:
	deck.clear()
	for i in range(6):
		deck.append("Liberal")
	for i in range(11):
		deck.append("Fascist")
	deck.shuffle()

func _draw_policy() -> String:
	if deck.is_empty():
		deck.append_array(discard_pile)
		discard_pile.clear()
		deck.shuffle()
	if deck.is_empty():
		return "Liberal"
	return deck.pop_back()

func _living_indices() -> Array[int]:
	var result: Array[int] = []
	for i in range(players.size()):
		if players[i]["alive"]:
			result.append(i)
	return result

func _living_count() -> int:
	return _living_indices().size()

func _next_living_after(index: int) -> int:
	var cursor := index
	for attempt in range(players.size()):
		cursor = (cursor + 1) % players.size()
		if players[cursor]["alive"]:
			return cursor
	return index

func _eligible_chancellors() -> Array[int]:
	var eligible: Array[int] = []
	var living := _living_indices()
	for i in living:
		if i == president_index:
			continue
		if living.size() >= 6:
			if i == previous_president or i == previous_chancellor:
				continue
		elif living.size() == 5:
			if i == previous_chancellor:
				continue
		eligible.append(i)
	return eligible

func _show_nomination() -> void:
	if game_over:
		return
	phase = "nominate"
	_clear_actions()
	var eligible := _eligible_chancellors()
	if eligible.is_empty():
		_add_log("No eligible Chancellor candidate. Election fails.")
		_resolve_failed_election()
		return

	status_label.text = "Election — President: %s" % players[president_index]["name"]
	if president_index == 0:
		players_label.text = _table_text() + "\n\n[b]Choose an eligible Chancellor candidate.[/b]"
		for candidate in eligible:
			_button("Nominate " + players[candidate]["name"], _nominate.bind(candidate))
	else:
		var candidate := _ai_nomination(eligible)
		nominated_chancellor = candidate
		_add_log("%s nominates %s for Chancellor." % [players[president_index]["name"], players[candidate]["name"]])
		_show_vote()
	_render()

func _ai_nomination(eligible: Array[int]) -> int:
	# The AI is intentionally lightweight: Fascists prefer a teammate when possible.
	if players[president_index]["role"] in ["Fascist", "Hitler"]:
		for i in eligible:
			if players[president_index]["role"] == "Fascist" and players[i]["role"] in ["Fascist", "Hitler"]:
				return i
	var candidate := eligible[randi_range(0, eligible.size() - 1)]
	return candidate

func _nominate(candidate: int) -> void:
	nominated_chancellor = candidate
	_add_log("You nominate %s for Chancellor." % players[candidate]["name"])
	_show_vote()

func _show_vote() -> void:
	phase = "vote"
	_clear_actions()
	status_label.text = "%s for President · %s for Chancellor" % [players[president_index]["name"], players[nominated_chancellor]["name"]]
	players_label.text = _table_text() + "\n\n[b]Vote on this government.[/b]"
	if president_index == 0:
		_button("Ja — approve", _cast_vote.bind(true))
		_button("Nein — reject", _cast_vote.bind(false))
	else:
		var yes_votes := 1 # AI President votes Ja
		for i in _living_indices():
			if i == president_index:
				continue
			if i == nominated_chancellor:
				yes_votes += 1 # AI Chancellor votes Ja
				continue
			if _ai_vote(i):
				yes_votes += 1
		var total := _living_count()
		_add_log("The table votes. Government %s (%d–%d)." % ["approved" if yes_votes > total / 2 else "rejected", yes_votes, total - yes_votes])
		_resolve_vote(yes_votes > total / 2)
	_render()

func _cast_vote(approve: bool) -> void:
	var yes_votes := 1 if approve else 0
	for i in _living_indices():
		if i == 0:
			continue
		if _ai_vote(i):
			yes_votes += 1
	var total := _living_count()
	var passed := yes_votes > total / 2
	_add_log("You vote %s. Government %s (%d–%d)." % ["Ja" if approve else "Nein", "approved" if passed else "rejected", yes_votes, total - yes_votes])
	_resolve_vote(passed)

func _ai_vote(index: int) -> bool:
	var role: String = players[index]["role"]
	if role in ["Fascist", "Hitler"]:
		return randf() > 0.20
	return randf() > 0.48

func _resolve_vote(passed: bool) -> void:
	if passed:
		election_tracker = 0
		chancellor_index = nominated_chancellor
		if fascist_policies >= 3 and players[chancellor_index]["role"] == "Hitler":
			_finish_game("Fascists win — Hitler was elected Chancellor.")
			return
		previous_president = president_index
		previous_chancellor = chancellor_index
		_legislative_phase()
	else:
		_resolve_failed_election()

func _resolve_failed_election() -> void:
	election_tracker += 1
	_add_log("Election tracker: %d / 3." % election_tracker)
	if election_tracker >= 3:
		election_tracker = 0
		var chaos_policy := _draw_policy()
		_add_log("[color=#fbbf24]Chaos! A policy is enacted automatically: %s.[/color]" % chaos_policy)
		_enact_policy(chaos_policy, false, false)
		if game_over:
			return
	_advance_president()

func _legislative_phase() -> void:
	phase = "legislative"
	hand.clear()
	for i in range(3):
		hand.append(_draw_policy())
	_add_log("The President draws three policy cards.")
	if president_index == 0:
		_clear_actions()
		status_label.text = "Legislative session — discard one policy"
		players_label.text = _table_text() + "\n\nYour hand: " + ", ".join(hand)
		for i in range(hand.size()):
			_button("Discard " + hand[i] + " policy", _president_discard.bind(i))
	else:
		var discard_index := _ai_president_discard(hand, players[president_index]["role"])
		var passed_cards: Array[String] = []
		for i in range(hand.size()):
			if i == discard_index:
				discard_pile.append(hand[i])
			else:
				passed_cards.append(hand[i])
		_add_log("%s discards one card and passes two to the Chancellor." % players[president_index]["name"])
		_chancellor_resolve(passed_cards)
	_render()

func _ai_president_discard(cards: Array[String], role: String) -> int:
	if role in ["Fascist", "Hitler"]:
		for i in range(cards.size()):
			if cards[i] == "Liberal":
				return i
	else:
		for i in range(cards.size()):
			if cards[i] == "Fascist":
				return i
	return randi_range(0, cards.size() - 1)

func _president_discard(index: int) -> void:
	var discarded := hand[index]
	discard_pile.append(discarded)
	hand.remove_at(index)
	_add_log("You discard a %s policy." % discarded)
	_chancellor_resolve(hand.duplicate())
	hand.clear()

func _chancellor_resolve(cards: Array[String]) -> void:
	legislative_cards = cards.duplicate()
	if chancellor_index == 0:
		phase = "chancellor_choice"
		_clear_actions()
		status_label.text = "Chancellor — choose a policy to enact"
		players_label.text = _table_text() + "\n\nCards passed to you: " + ", ".join(cards)
		for i in range(cards.size()):
			_button("Enact " + cards[i] + " policy", _player_enact.bind(i))
		if fascist_policies >= 5:
			_button("Propose veto (discard both)", _propose_veto)
		return
	var enacted := _ai_chancellor_choice(cards, players[chancellor_index]["role"])
	_add_log("%s enacts a %s policy." % [players[chancellor_index]["name"], enacted])
	var removed := false
	for card in cards:
		if card == enacted and not removed:
			removed = true
		else:
			discard_pile.append(card)
	_enact_policy(enacted, true)

func _ai_chancellor_choice(cards: Array[String], role: String) -> String:
	if role in ["Fascist", "Hitler"] and cards.has("Fascist"):
		return "Fascist"
	if cards.has("Liberal"):
		return "Liberal"
	return cards[0]

func _player_enact(index: int) -> void:
	if index < 0 or index >= legislative_cards.size():
		return
	var enacted := legislative_cards[index]
	for i in range(legislative_cards.size()):
		if i != index:
			discard_pile.append(legislative_cards[i])
	_add_log("You enact a %s policy." % enacted)
	legislative_cards.clear()
	_enact_policy(enacted, true)

func _propose_veto() -> void:
	if fascist_policies < 5:
		return
	veto_pending_cards = legislative_cards.duplicate()
	_clear_actions()
	if president_index == 0:
		phase = "veto_response"
		status_label.text = "Veto requested — President decision"
		players_label.text = _table_text() + "\n\nThe Chancellor requests a veto. Accept it?"
		_button("Accept veto", _president_veto_response.bind(true))
		_button("Reject veto — enact a policy", _president_veto_response.bind(false))
	else:
		var accept_veto := players[president_index]["role"] in ["Fascist", "Hitler"] and randf() > 0.25
		_add_log("The Chancellor requests a veto. President %s it." % ("accepts" if accept_veto else "rejects"))
		_resolve_veto_response(accept_veto)

func _president_veto_response(accept_veto: bool) -> void:
	_add_log("You %s the veto request." % ("accept" if accept_veto else "reject"))
	_resolve_veto_response(accept_veto)

func _resolve_veto_response(accept_veto: bool) -> void:
	if accept_veto:
		discard_pile.append_array(veto_pending_cards)
		veto_pending_cards.clear()
		_add_log("Both policy cards are discarded. The election tracker advances.")
		_resolve_failed_election()
		return
	_add_log("The veto is rejected; the Chancellor must enact a policy.")
	if chancellor_index == 0:
		_clear_actions()
		status_label.text = "Veto rejected — enact one policy"
		for i in range(legislative_cards.size()):
			_button("Enact " + legislative_cards[i] + " policy", _player_enact.bind(i))
	else:
		var enacted := _ai_chancellor_choice(legislative_cards, players[chancellor_index]["role"])
		var removed := false
		for card in legislative_cards:
			if card == enacted and not removed:
				removed = true
			else:
				discard_pile.append(card)
		legislative_cards.clear()
		_add_log("%s enacts a %s policy." % [players[chancellor_index]["name"], enacted])
		_enact_policy(enacted, true)

func _enact_policy(policy: String, trigger_power: bool, advance_after: bool = true) -> void:
	if policy == "Liberal":
		liberal_policies += 1
	else:
		fascist_policies += 1
	_render_tracks()
	_render()
	if liberal_policies >= LIBERAL_WIN:
		_finish_game("Liberals win — five Liberal policies were enacted.")
		return
	if fascist_policies >= FASCIST_WIN:
		_finish_game("Fascists win — six Fascist policies were enacted.")
		return
	if trigger_power and policy == "Fascist":
		_trigger_fascist_power()
	elif advance_after:
		_advance_president()

func _trigger_fascist_power() -> void:
	# Seven-player board: investigate at 3, special election at 4, execute at 5 and 6.
	pending_power_president = president_index
	match fascist_policies:
		3:
			pending_power = "investigate"
			if president_index == 0:
				_show_power_target("Investigate loyalty", "Choose a player to learn their party affiliation.")
			else:
				_resolve_power_target(_ai_power_target("investigate"))
		4:
			pending_power = "special_election"
			if president_index == 0:
				_show_power_target("Special election", "Choose who will be the next President.")
			else:
				_resolve_power_target(_ai_power_target("special_election"))
		5, 6:
			pending_power = "execute"
			if president_index == 0:
				_show_power_target("Execution", "Choose a player to execute.")
			else:
				_resolve_power_target(_ai_power_target("execute"))
		_:
			_advance_president()

func _ai_power_target(power: String) -> int:
	var options := _living_indices()
	if power in ["special_election", "investigate"]:
		options.erase(president_index)
	if power == "execute":
		# Fascist AI prefers to remove Liberals; Liberal AI tries to find Hitler.
		if players[president_index]["role"] in ["Fascist", "Hitler"]:
			for i in options:
				if players[i]["role"] == "Liberal":
					return i
		else:
			for i in options:
				if players[i]["role"] == "Hitler":
					return i
	return options[randi_range(0, options.size() - 1)]

func _show_power_target(power_title: String, prompt: String) -> void:
	phase = "presidential_power"
	_clear_actions()
	status_label.text = "Presidential power — " + power_title
	players_label.text = _table_text() + "\n\n" + prompt
	var options := _living_indices()
	for target in options:
		if pending_power in ["special_election", "investigate"] and target == president_index:
			continue
		if pending_power == "execute" and target == president_index:
			# The President may execute themselves in the original game; permit it.
			pass
		_button("Choose " + players[target]["name"], _resolve_power_target.bind(target))

func _resolve_power_target(target: int) -> void:
	if game_over or not players[target]["alive"]:
		return
	match pending_power:
		"investigate":
			var party := "Liberal" if players[target]["role"] == "Liberal" else "Fascist"
			_add_log("You investigate %s: their party affiliation is [b]%s[/b]." % [players[target]["name"], party] if president_index == 0 else "%s investigates %s." % [players[president_index]["name"], players[target]["name"]])
			if president_index == 0:
				_clear_actions()
				status_label.text = "Investigation result"
				players_label.text = _table_text() + "\n\n[color=#fbbf24]%s belongs to the %s party.[/color]" % [players[target]["name"], party]
				_button("Continue", _finish_power)
				return
			_finish_power()
		"special_election":
			special_next_president = target
			special_return_index = president_index
			_add_log("%s calls a special election. %s will be the next President." % [players[president_index]["name"], players[target]["name"]])
			_finish_power()
		"execute":
			players[target]["alive"] = false
			_add_log("%s is executed by %s." % [players[target]["name"], players[president_index]["name"]])
			if players[target]["role"] == "Hitler":
				_finish_game("Liberals win — Hitler was executed.")
				return
			_finish_power()

func _finish_power() -> void:
	pending_power = ""
	pending_power_president = -1
	_clear_actions()
	_advance_president()

func _advance_president() -> void:
	if game_over:
		return
	if special_next_president >= 0 and players[special_next_president]["alive"]:
		president_index = special_next_president
		special_next_president = -1
		special_president_active = true
	elif special_president_active:
		president_index = _next_living_after(special_return_index)
		special_president_active = false
		special_return_index = -1
	else:
		president_index = _next_living_after(president_index)
	_render()
	_show_nomination()

func _finish_game(message: String) -> void:
	game_over = true
	phase = "over"
	_add_log("[b]" + message + "[/b]")
	_clear_actions()
	status_label.text = message
	players_label.text = _table_text() + "\n\n[b]Game over.[/b]"
	_button("Play again", _start_game)
	_render()

func _render_tracks() -> void:
	if liberal_track_label != null:
		liberal_track_label.text = "LIBERAL POLICIES  %d / 5" % liberal_policies
	if fascist_track_label != null:
		fascist_track_label.text = "FASCIST POLICIES  %d / 6" % fascist_policies

func _render() -> void:
	_render_tracks()
	if log_label != null:
		log_label.text = "\n".join(log_lines)

func _table_text() -> String:
	var out := ""
	for i in range(players.size()):
		var marker := "  ▶ PRESIDENT" if i == president_index and players[i]["alive"] else ""
		var dead := "  [color=#9ca3af](executed)[/color]" if not players[i]["alive"] else ""
		var role_hint := ""
		if i == 0:
			role_hint = "  [color=#fbbf24](your role: %s)[/color]" % players[i]["role"]
		out += "%s%s%s%s\n" % [players[i]["name"], marker, dead, role_hint]
	out += "\n[color=#93c5fd]Liberal: %d / 5[/color]\n[color=#fca5a5]Fascist: %d / 6[/color]\nElection tracker: %d / 3" % [liberal_policies, fascist_policies, election_tracker]
	return out

func _add_log(message: String) -> void:
	log_lines.append("• " + message)
	if log_lines.size() > 80:
		log_lines.pop_front()
	if log_label != null:
		log_label.text = "\n".join(log_lines)
