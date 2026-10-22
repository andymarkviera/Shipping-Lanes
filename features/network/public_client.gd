extends Node3D
const Session = preload("res://features/network/public_peer_session.gd")
const Presentation = preload("res://features/network/public_client_presentation.gd")
signal ticket_required(nonce: String)
var session: Node
var presentation: Node3D

func _ready() -> void:
	session = Session.new()
	session.name = "Session"
	add_child(session)
	session.challenged.connect(func(nonce: String): ticket_required.emit(nonce))
	presentation = Presentation.new()
	presentation.configure(session)
	add_child(presentation)

func connect_server(settings: Dictionary) -> Error:
	return session.start_client(settings)

func submit_ticket(ticket: String) -> void:
	session.submit_ticket(ticket)

func _exit_tree() -> void:
	session.close_client()
