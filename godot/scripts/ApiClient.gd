extends Node

@export var backend_url: String = "http://127.0.0.1:8000"
@export var poll_interval: float = 10.0

var http_request: HTTPRequest
var reroll_request: HTTPRequest
var timer: Timer

signal state_updated(state_dict)
signal connection_error(message)

func _ready() -> void:
	http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.request_completed.connect(_on_request_completed)
	
	reroll_request = HTTPRequest.new()
	add_child(reroll_request)
	reroll_request.request_completed.connect(_on_reroll_completed)

	timer = Timer.new()
	timer.wait_time = poll_interval
	timer.autostart = true
	timer.timeout.connect(_poll_state)
	add_child(timer)

	_poll_state()

func _poll_state() -> void:
	var url = backend_url + "/state"
	var err = http_request.request(url)
	if err != OK:
		emit_signal("connection_error", "Kunde inte ansluta till API:et")

func reroll_quests() -> void:
	var url = backend_url + "/quests/reroll"
	# POST request with empty body
	reroll_request.request(url, [], HTTPClient.METHOD_POST, "")

func _on_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	if result == HTTPRequest.RESULT_SUCCESS and response_code == 200:
		var json = JSON.new()
		var err = json.parse(body.get_string_from_utf8())
		if err == OK:
			emit_signal("state_updated", json.data)
		else:
			emit_signal("connection_error", "Felaktig JSON från servern")
	else:
		emit_signal("connection_error", "HTTP Fel: %d" % response_code)

func _on_reroll_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	if result == HTTPRequest.RESULT_SUCCESS and response_code == 200:
		# Uppdatera staten direkt när reroll är klar för snabb feedback
		_poll_state()
