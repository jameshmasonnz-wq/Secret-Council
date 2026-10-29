extends Node
## Session data shared while changing from lobby to online game.
var private_role := ""
var private_team_info := ""
var public_players: Array = []
var server_roles: Array = []
var reconnect_token := ""
var my_seat := -1
var session_id := ""

func _ready() -> void:
	_load_token()

func _load_token() -> void:
	var cfg := ConfigFile.new()
	if cfg.load("user://secret_council.cfg") == OK:
		reconnect_token = str(cfg.get_value("network", "reconnect_token", ""))
	if reconnect_token.is_empty():
		reconnect_token = _make_token()
		cfg.set_value("network", "reconnect_token", reconnect_token)
		cfg.save("user://secret_council.cfg")

func _make_token() -> String:
	var chars := "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
	var out := ""
	for i in range(32):
		out += chars[randi() % chars.length()]
	return out

func clear_game() -> void:
	private_role = ""
	private_team_info = ""
	public_players.clear()
	server_roles.clear()
	my_seat = -1
	session_id = ""
