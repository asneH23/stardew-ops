# ApiClient.gd
# Pollar GET /state från Stardew-Ops backend var POLL_INTERVAL sekunder.
# Skickar signalen "state_updated" med ett Dictionary när ny data finns.
#
# Godot-koncept som används här:
#   Node     = basklass för alla objekt i scenen
#   signal   = Godots event-system (som Python callbacks / EventEmitter)
#   HTTPRequest = inbyggd nod för HTTP-anrop (asynkront, blockar inte spelet)
#   Timer    = inbyggd nod för upprepade tidshändelser
#   @export  = gör variabeln synlig i Godot-editorn (inspector)

extends Node

## Signal som skickas när backend returnerar ny state.
## GameManager.gd lyssnar på denna.
signal state_updated(state: Dictionary)
signal connection_error(message: String)

## Ändra detta till din Railway-URL när du deployt backenden.
@export var backend_url: String = "http://localhost:8000"

## Hur ofta (sekunder) vi pollar /state
@export var poll_interval: float = 10.0

var _http_request: HTTPRequest
var _timer: Timer
var _is_requesting: bool = false


func _ready() -> void:
	# Skapa HTTPRequest-noden programmatiskt
	_http_request = HTTPRequest.new()
	add_child(_http_request)
	_http_request.request_completed.connect(_on_request_completed)

	# Skapa en Timer för polling
	_timer = Timer.new()
	_timer.wait_time = poll_interval
	_timer.autostart = true
	_timer.timeout.connect(_poll_state)
	add_child(_timer)

	# Polla direkt vid start (vänta inte på första timer-tick)
	_poll_state()


func _poll_state() -> void:
	if _is_requesting:
		return  # Skippa om förra requesten fortfarande pågår

	_is_requesting = true
	var url = backend_url + "/state"
	var error = _http_request.request(url)

	if error != OK:
		_is_requesting = false
		emit_signal("connection_error", "Kunde inte nå backend: " + str(error))
		print("[ApiClient] HTTP-fel: ", error)


func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_is_requesting = false

	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		var msg = "Backend svarade med kod: " + str(response_code)
		emit_signal("connection_error", msg)
		print("[ApiClient] Fel: ", msg)
		return

	# Parsa JSON-svaret
	var json = JSON.new()
	var parse_result = json.parse(body.get_string_from_utf8())

	if parse_result != OK:
		emit_signal("connection_error", "Kunde inte parsa JSON från backend")
		return

	var state: Dictionary = json.get_data()
	emit_signal("state_updated", state)
	print("[ApiClient] State uppdaterad: XP=", state.get("total_xp", 0))
